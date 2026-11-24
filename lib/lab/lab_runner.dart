import 'dart:async';

import '../engine/assist_engine.dart';
import 'device_info.dart';
import 'lab_result.dart';
import 'model_catalog.dart';
import 'prompts.dart';
import 'quick_add_check.dart';

/// Where a run is, for the screen that watches it.
class LabProgress {
  const LabProgress.loading() : done = 0, total = 0, prompt = null;

  const LabProgress.answering(this.done, this.total, LabPrompt this.prompt);

  /// Requests finished so far.
  final int done;
  final int total;

  /// The request being answered, or null while the model loads.
  final LabPrompt? prompt;
}

/// The speeds of one answer and where they were measured.
class MeasuredSpeed {
  const MeasuredSpeed({
    this.promptTokens,
    this.answerTokens,
    this.read,
    this.write,
    this.source,
  });

  final int? promptTokens;
  final int? answerTokens;
  final double? read;
  final double? write;
  final SpeedSource? source;
}

/// Fewer tokens than this are read too quickly to give a steady speed.
const int minTokensForReadSpeed = 32;

/// Fewer tokens than this are written too quickly to give a steady speed.
const int minTokensForWriteSpeed = 8;

/// Picks the most trustworthy numbers available for one answer: the native
/// library's own counters, then the usage attached to the answer, then the
/// app's stopwatch with a token count made afterwards.
MeasuredSpeed measureSpeed({
  AssistPerf? perf,
  AssistUsage? usage,
  int? firstTextMs,
  required int totalMs,
  int? countedPromptTokens,
  int? countedAnswerTokens,
}) {
  double? rate(int tokens, double milliseconds, int minimum) {
    if (tokens < minimum || milliseconds <= 0) return null;
    return tokens * 1000 / milliseconds;
  }

  if (perf != null && perf.answerTokens > 0 && perf.answerMs > 0) {
    return MeasuredSpeed(
      promptTokens: perf.promptTokens,
      answerTokens: perf.answerTokens,
      read: rate(perf.promptTokens, perf.promptMs, minTokensForReadSpeed),
      write: rate(perf.answerTokens, perf.answerMs, minTokensForWriteSpeed),
      source: SpeedSource.runtimeCounters,
    );
  }

  final first = usage?.timeToFirstToken;
  final whole = usage?.duration;
  if (usage != null && first != null && whole != null) {
    final readTokens = usage.promptTokens - usage.cachedPromptTokens;
    return MeasuredSpeed(
      promptTokens: usage.promptTokens,
      answerTokens: usage.completionTokens,
      read: rate(
        readTokens,
        first.inMicroseconds / 1000,
        minTokensForReadSpeed,
      ),
      // The first token arrives at the end of the reading time, so the
      // writing time covers the tokens after it.
      write: rate(
        usage.completionTokens - 1,
        (whole - first).inMicroseconds / 1000,
        minTokensForWriteSpeed,
      ),
      source: SpeedSource.usage,
    );
  }

  if (firstTextMs == null) {
    return MeasuredSpeed(
      promptTokens: countedPromptTokens,
      answerTokens: countedAnswerTokens,
    );
  }
  return MeasuredSpeed(
    promptTokens: countedPromptTokens,
    answerTokens: countedAnswerTokens,
    read: countedPromptTokens == null
        ? null
        : rate(
            countedPromptTokens,
            firstTextMs.toDouble(),
            minTokensForReadSpeed,
          ),
    write: countedAnswerTokens == null
        ? null
        : rate(
            countedAnswerTokens - 1,
            (totalMs - firstTextMs).toDouble(),
            minTokensForWriteSpeed,
          ),
    source: SpeedSource.stopwatch,
  );
}

/// Loads one model and puts it through a list of requests, measuring each.
///
/// The model runs inside the engine's own threads, so the screen stays
/// responsive; this class only waits for the pieces of each answer.
class LabRunner {
  LabRunner({
    required this.createEngine,
    required this.readDevice,
    required this.appVersion,
    required this.engineVersion,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Makes a fresh engine for the run. Tests pass a fake.
  final AssistEngine Function() createEngine;

  /// Reads the phone's memory, heat and battery.
  final Future<DeviceSnapshot?> Function() readDevice;
  final String appVersion;
  final String engineVersion;
  final DateTime Function() _now;

  /// After this many failed requests in a row the run stops: the model is
  /// broken for this phone and the remaining requests would fail the same way.
  static const int maxFailuresInARow = 3;

  AssistEngine? _engine;
  bool _cancelled = false;

  /// Stops the run after the answer being written. What was measured so far
  /// is kept.
  void cancel() {
    _cancelled = true;
    _engine?.cancel();
  }

  Future<LabRun> run({
    required LabModel model,
    required String modelPath,
    required AssistDevice device,
    required List<LabPrompt> prompts,
    int contextSize = 4096,
    int threads = 0,
    void Function(LabProgress progress)? onProgress,
    void Function(String answerSoFar)? onText,
  }) async {
    _cancelled = false;
    final startedAt = _now();
    final engine = createEngine();
    _engine = engine;
    final results = <PromptResult>[];
    final deviceAtStart = await readDevice();
    var peakMemory = deviceAtStart?.appMemoryBytes ?? 0;
    var peakThermal = deviceAtStart?.thermalStatus ?? 0;
    DeviceSnapshot? deviceAfterLoad;
    String? backendName;
    String? loadError;
    int? loadMs;
    int? warmUpMs;

    void track(DeviceSnapshot? snapshot) {
      if (snapshot == null) return;
      if (snapshot.appMemoryBytes > peakMemory) {
        peakMemory = snapshot.appMemoryBytes;
      }
      if (snapshot.thermalStatus > peakThermal) {
        peakThermal = snapshot.thermalStatus;
      }
    }

    Future<DeviceSnapshot?> readTracked() async {
      final snapshot = await readDevice();
      track(snapshot);
      return snapshot;
    }

    // Memory can peak in the middle of an answer, so it is also sampled while
    // the model works, not only between requests.
    final sampler = Timer.periodic(
      const Duration(seconds: 2),
      (_) => readTracked(),
    );

    try {
      onProgress?.call(const LabProgress.loading());
      final loadWatch = Stopwatch()..start();
      try {
        await engine.load(
          modelPath,
          device: device,
          contextSize: contextSize,
          threads: threads,
        );
        loadMs = loadWatch.elapsedMilliseconds;
        backendName = await engine.backendName();
      } on Object catch (error) {
        loadError = error.toString();
      }

      if (loadError == null) {
        final warmUpWatch = Stopwatch()..start();
        try {
          await engine.generate(const [
            AssistMessage.user('Reply with the single word: ready'),
          ], maxTokens: 8).drain<void>();
          warmUpMs = warmUpWatch.elapsedMilliseconds;
        } on Object catch (error) {
          loadError = 'The first answer failed: $error';
        }
        // Read only now: some runtimes return from load at once and bring
        // the model into memory on the first answer.
        deviceAfterLoad = await readTracked();
      }

      if (loadError == null) {
        var failuresInARow = 0;
        for (var index = 0; index < prompts.length; index++) {
          if (_cancelled) break;
          final prompt = prompts[index];
          onProgress?.call(
            LabProgress.answering(index, prompts.length, prompt),
          );
          final result = await _answer(engine, prompt, onText, readTracked);
          // An answer cut short by Stop is not a measurement.
          if (_cancelled) break;
          results.add(result);
          failuresInARow = result.error == null ? 0 : failuresInARow + 1;
          if (failuresInARow >= maxFailuresInARow) break;
        }
      }
    } finally {
      sampler.cancel();
      _engine = null;
      try {
        await engine.dispose();
      } on Object {
        // The run's numbers are already collected; a failed unload must not
        // lose them.
      }
    }

    final deviceAtEnd = await readTracked();
    return LabRun(
      appVersion: appVersion,
      engineVersion: engineVersion,
      model: model,
      requestedDevice: device.name,
      backendName: backendName,
      contextSize: contextSize,
      threads: threads,
      startedAt: startedAt,
      finishedAt: _now(),
      loadMs: loadMs,
      loadError: loadError,
      warmUpMs: warmUpMs,
      deviceAtStart: deviceAtStart,
      deviceAfterLoad: deviceAfterLoad,
      deviceAtEnd: deviceAtEnd,
      peakAppMemoryBytes: peakMemory == 0 ? null : peakMemory,
      peakThermalStatus: deviceAtStart == null ? null : peakThermal,
      results: results,
      cancelled: _cancelled,
    );
  }

  Future<PromptResult> _answer(
    AssistEngine engine,
    LabPrompt prompt,
    void Function(String answerSoFar)? onText,
    Future<DeviceSnapshot?> Function() readDevice,
  ) async {
    final answer = StringBuffer();
    final watch = Stopwatch()..start();
    int? firstTextMs;
    AssistUsage? usage;
    String? error;
    try {
      final pieces = engine.generate([
        const AssistMessage.system(labSystemPrompt),
        AssistMessage.user(prompt.text),
      ], maxTokens: prompt.maxTokens);
      await for (final piece in pieces) {
        usage = piece.usage ?? usage;
        if (piece.text.isEmpty) continue;
        firstTextMs ??= watch.elapsedMilliseconds;
        answer.write(piece.text);
        onText?.call(answer.toString());
      }
    } on Object catch (failure) {
      error = failure.toString();
    }
    watch.stop();
    final totalMs = watch.elapsedMilliseconds;
    final text = answer.toString().trim();

    MeasuredSpeed speed = const MeasuredSpeed();
    if (error == null) {
      AssistPerf? perf;
      try {
        perf = await engine.lastPerformance();
      } on Object {
        perf = null;
      }
      int? countedPrompt;
      int? countedAnswer;
      final hasCounters = perf != null && perf.answerTokens > 0;
      if (!hasCounters && usage == null) {
        countedPrompt = await engine.countTokens(
          '$labSystemPrompt\n${prompt.text}',
        );
        countedAnswer = await engine.countTokens(text);
      }
      speed = measureSpeed(
        perf: perf,
        usage: usage,
        firstTextMs: firstTextMs,
        totalMs: totalMs,
        countedPromptTokens: countedPrompt,
        countedAnswerTokens: countedAnswer,
      );
    }

    final check = error == null ? checkQuickAdd(prompt, text) : null;
    final device = await readDevice();
    return PromptResult(
      promptId: prompt.id,
      category: prompt.category,
      language: prompt.language,
      answerLanguage: prompt.answerLanguage,
      answer: text,
      firstTextMs: firstTextMs,
      totalMs: totalMs,
      promptTokens: speed.promptTokens,
      answerTokens: speed.answerTokens,
      readTokensPerSecond: speed.read,
      writeTokensPerSecond: speed.write,
      speedSource: speed.source,
      thermalStatus: device?.thermalStatus,
      checkPassed: check?.passed,
      checkNote: check?.note,
      error: error,
    );
  }
}
