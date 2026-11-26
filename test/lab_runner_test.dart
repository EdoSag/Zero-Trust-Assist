import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_assist/engine/assist_engine.dart';
import 'package:zerotrust_assist/lab/device_info.dart';
import 'package:zerotrust_assist/lab/lab_result.dart';
import 'package:zerotrust_assist/lab/lab_runner.dart';
import 'package:zerotrust_assist/lab/model_catalog.dart';
import 'package:zerotrust_assist/lab/prompts.dart';

import 'fake_engine.dart';

DeviceSnapshot _device({int memory = 1000, int thermal = 0, int battery = 80}) {
  return DeviceSnapshot(
    manufacturer: 'Google',
    model: 'Pixel 10 Pro',
    soc: 'Google Tensor G5',
    sdk: 36,
    totalRamBytes: 16000000000,
    availableRamBytes: 9000000000,
    lowMemory: false,
    appMemoryBytes: memory,
    freeStorageBytes: 100000000000,
    thermalStatus: thermal,
    batteryPercent: battery,
    charging: false,
  );
}

LabRunner _runner(
  FakeEngine engine, {
  Future<DeviceSnapshot?> Function()? readDevice,
  bool Function()? inForeground,
}) {
  return LabRunner(
    createEngine: () => engine,
    readDevice: readDevice ?? () async => _device(),
    appVersion: '0.1.0',
    engineVersion: 'fake 1.0',
    inForeground: inForeground,
  );
}

Future<LabRun> _run(
  LabRunner runner, {
  List<LabPrompt>? prompts,
  AssistDevice device = AssistDevice.cpu,
  int threads = 0,
  void Function(LabProgress progress)? onProgress,
  void Function(String text)? onText,
}) {
  return runner.run(
    model: labModels.first,
    modelPath: '/models/test.litertlm',
    device: device,
    prompts: prompts ?? labQuickPrompts,
    threads: threads,
    onProgress: onProgress,
    onText: onText,
  );
}

void main() {
  group('LabRunner', () {
    test('answers every request and unloads the model', () async {
      final engine = FakeEngine();
      final progress = <LabProgress>[];
      final texts = <String>[];
      final run = await _run(
        _runner(engine),
        onProgress: progress.add,
        onText: texts.add,
      );

      expect(run.loadError, isNull);
      expect(run.cancelled, isFalse);
      expect(run.backendName, 'Fake');
      expect(run.results.map((r) => r.promptId), [
        for (final prompt in labQuickPrompts) prompt.id,
      ]);
      expect(run.results.every((r) => r.answer == 'Hello there'), isTrue);
      expect(run.warmUpMs, isNotNull);
      expect(engine.disposed, isTrue);
      // The warm-up plus one request each.
      expect(engine.requests.length, labQuickPrompts.length + 1);
      expect(progress.first.prompt, isNull);
      expect(progress.last.done, labQuickPrompts.length - 1);
      expect(texts, contains('Hello there'));
    });

    test('every request carries the shared instructions', () async {
      final engine = FakeEngine();
      await _run(_runner(engine), prompts: [labPrompts.first]);
      final request = engine.requests.last;
      expect(request.first.role, AssistRole.system);
      expect(request.first.text, labSystemPrompt);
      expect(request.last.text, labPrompts.first.text);
    });

    test('asks for the processor or the graphics chip as told', () async {
      final engine = FakeEngine();
      final run = await _run(
        _runner(engine),
        prompts: [labPrompts.first],
        device: AssistDevice.gpu,
      );
      expect(engine.loadedDevice, AssistDevice.gpu);
      expect(engine.loadedThreads, 0);
      expect(run.requestedDevice, 'gpu');
    });

    test('passes the thread count to the engine and records it', () async {
      final engine = FakeEngine();
      final run = await _run(
        _runner(engine),
        prompts: [labPrompts.first],
        threads: 6,
      );
      expect(engine.loadedThreads, 6);
      expect(run.threads, 6);
    });

    test('a model that does not load gives a run with the reason', () async {
      final engine = FakeEngine(loadError: StateError('no GPU'));
      final run = await _run(_runner(engine));
      expect(run.loadError, contains('no GPU'));
      expect(run.results, isEmpty);
      expect(engine.disposed, isTrue);
      expect(run.summaryText(), contains('did not load'));
    });

    test('a failed request is recorded and the run goes on', () async {
      var calls = 0;
      final engine = FakeEngine(
        answer: (messages) {
          calls++;
          // Call 1 is the warm-up, call 2 the first request.
          if (calls == 2) throw StateError('out of context');
          return const ['ok'];
        },
      );
      final run = await _run(_runner(engine));
      expect(run.results.length, labQuickPrompts.length);
      expect(run.results.first.error, contains('out of context'));
      expect(run.failedCount, 1);
      expect(run.results[1].error, isNull);
    });

    test('stops after three failed requests in a row', () async {
      var calls = 0;
      final engine = FakeEngine(
        answer: (messages) {
          calls++;
          if (calls > 1) throw StateError('broken');
          return const ['ok'];
        },
      );
      final run = await _run(_runner(engine));
      expect(run.results.length, LabRunner.maxFailuresInARow);
      expect(engine.disposed, isTrue);
    });

    test('Stop keeps the finished answers and drops the cut one', () async {
      late LabRunner runner;
      var pieces = 0;
      final engine = FakeEngine(
        answer: (messages) => const ['one', ' two', ' three'],
        onPiece: (engine) {
          pieces++;
          // The warm-up and the first request are three pieces each; stop in
          // the middle of the second request.
          if (pieces == 8) runner.cancel();
        },
      );
      runner = _runner(engine);
      final run = await _run(runner);
      expect(run.cancelled, isTrue);
      expect(run.results.length, 1);
      expect(run.results.single.answer, 'one two three');
      expect(engine.disposed, isTrue);
    });

    test('checks quick add answers', () async {
      final quickAdd = labPrompts.firstWhere((p) => p.id == 'qa-he-1');
      final engine = FakeEngine(
        answer: (messages) => const [
          '{"type":"event","title":"רופא שיניים",',
          '"date":"2026-11-25","time":"09:00",',
          '"reminder_minutes_before":60}',
        ],
      );
      final run = await _run(_runner(engine), prompts: [quickAdd]);
      expect(run.results.single.checkPassed, isTrue);
      expect(run.quickAddPassed, 1);
      expect(run.quickAddTotal, 1);
    });

    test('records memory gained by loading, and the peaks', () async {
      final readings = [
        _device(memory: 200, thermal: 0, battery: 80),
        _device(memory: 1900, thermal: 1),
        _device(memory: 2400, thermal: 2),
        _device(memory: 2000, thermal: 1, battery: 78),
      ];
      var index = 0;
      final run = await _run(
        _runner(
          FakeEngine(),
          readDevice: () async {
            final reading = readings[index.clamp(0, readings.length - 1)];
            index++;
            return reading;
          },
        ),
        prompts: [labPrompts.first],
      );
      expect(run.loadMemoryBytes, 1700);
      expect(run.peakAppMemoryBytes, 2400);
      expect(run.peakThermalStatus, 2);
      expect(run.deviceAtEnd!.batteryPercent, 78);
    });

    test('works when the phone state cannot be read', () async {
      final run = await _run(
        _runner(FakeEngine(), readDevice: () async => null),
        prompts: [labPrompts.first],
      );
      expect(run.deviceAtStart, isNull);
      expect(run.peakAppMemoryBytes, isNull);
      expect(run.results.single.error, isNull);
      expect(run.summaryText(), contains('Memory: n/a'));
    });

    test('uses the runtime counters for speed when there are any', () async {
      final engine = FakeEngine(
        perf: const AssistPerf(
          promptTokens: 600,
          promptMs: 2000,
          answerTokens: 100,
          answerMs: 4000,
        ),
      );
      final run = await _run(_runner(engine), prompts: [labPrompts.first]);
      final result = run.results.single;
      expect(result.speedSource, SpeedSource.runtimeCounters);
      expect(result.readTokensPerSecond, 300);
      expect(result.writeTokensPerSecond, 25);
      expect(result.promptTokens, 600);
      expect(result.answerTokens, 100);
    });

    test('marks the answers written while the app was off screen', () async {
      // The app leaves the screen in the middle of the second answer and
      // comes back before the third.
      var onScreen = true;
      late final FakeEngine engine;
      engine = FakeEngine(
        onPiece: (_) {
          // Requests: warm-up, then one per prompt.
          if (engine.requests.length == 3) onScreen = false;
        },
      );
      final runner = _runner(engine, inForeground: () => onScreen);
      final run = await _run(
        runner,
        prompts: labQuickPrompts.take(3).toList(),
        onProgress: (progress) {
          if (progress.done == 2) onScreen = true;
        },
      );
      expect(run.results.map((result) => result.appInBackground), [
        false,
        true,
        false,
      ]);
      expect(run.backgroundCount, 1);
      expect(run.results[1].toJson()['app_in_background'], true);
      expect(run.results[0].toJson().containsKey('app_in_background'), false);
    });

    test('an app that is always on screen marks nothing', () async {
      final run = await _run(
        _runner(FakeEngine()),
        prompts: labQuickPrompts.take(2).toList(),
      );
      expect(run.backgroundCount, 0);
    });
  });

  group('measureSpeed', () {
    test('falls back to the usage attached to the answer', () {
      final speed = measureSpeed(
        usage: const AssistUsage(
          promptTokens: 500,
          cachedPromptTokens: 100,
          completionTokens: 41,
          timeToFirstToken: Duration(seconds: 2),
          duration: Duration(seconds: 4),
        ),
        firstTextMs: 2100,
        totalMs: 4100,
      );
      expect(speed.source, SpeedSource.usage);
      // 400 new tokens read in 2 s; 40 tokens written in the 2 s after the
      // first one.
      expect(speed.read, 200);
      expect(speed.write, 20);
    });

    test('falls back to the stopwatch and counted tokens', () {
      final speed = measureSpeed(
        firstTextMs: 1000,
        totalMs: 3000,
        countedPromptTokens: 250,
        countedAnswerTokens: 31,
      );
      expect(speed.source, SpeedSource.stopwatch);
      expect(speed.read, 250);
      expect(speed.write, 15);
    });

    test('gives no speed for too few tokens', () {
      final speed = measureSpeed(
        perf: const AssistPerf(
          promptTokens: 10,
          promptMs: 20,
          answerTokens: 3,
          answerMs: 100,
        ),
        totalMs: 120,
      );
      expect(speed.read, isNull);
      expect(speed.write, isNull);
      expect(speed.answerTokens, 3);
    });

    test('ignores empty runtime counters', () {
      final speed = measureSpeed(
        perf: const AssistPerf(
          promptTokens: 0,
          promptMs: 0,
          answerTokens: 0,
          answerMs: 0,
        ),
        firstTextMs: 500,
        totalMs: 2500,
        countedPromptTokens: 100,
        countedAnswerTokens: 21,
      );
      expect(speed.source, SpeedSource.stopwatch);
      expect(speed.write, 10);
    });

    test('gives nothing when no text came back', () {
      final speed = measureSpeed(totalMs: 100);
      expect(speed.source, isNull);
      expect(speed.write, isNull);
    });
  });
}
