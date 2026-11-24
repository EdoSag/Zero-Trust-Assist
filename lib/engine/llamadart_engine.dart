import 'package:llamadart/llamadart.dart';

import 'assist_engine.dart';

/// The load settings for the model file at [path].
///
/// LiteRT-LM refuses any setting that only llama.cpp understands and fails
/// the load, so the thread count for batches goes to `.gguf` files alone.
/// LiteRT-LM takes the plain thread count, and only on the processor.
ModelParams modelParamsFor(
  String path, {
  required AssistDevice device,
  required int contextSize,
  required int threads,
}) {
  final liteRtLm = path.toLowerCase().endsWith('.litertlm');
  final onProcessor = device == AssistDevice.cpu;
  return ModelParams(
    contextSize: contextSize,
    numberOfThreads: liteRtLm && !onProcessor ? 0 : threads,
    numberOfThreadsBatch: liteRtLm ? 0 : threads,
    device: onProcessor ? ComputeDevice.cpu : ComputeDevice.gpu,
  );
}

/// [AssistEngine] on the llamadart package: llama.cpp for `.gguf` files and
/// LiteRT-LM for `.litertlm` files. The package picks the runtime from the
/// file type and runs it off the UI thread.
class LlamadartEngine implements AssistEngine {
  LlamadartEngine() : _engine = LlamaEngine(LlamaBackend());

  final LlamaEngine _engine;

  @override
  Future<void> load(
    String path, {
    AssistDevice device = AssistDevice.cpu,
    int contextSize = 4096,
    int threads = 0,
  }) {
    return _engine.setModel(
      LlamaModel(ModelSource.path(path)),
      params: modelParamsFor(
        path,
        device: device,
        contextSize: contextSize,
        threads: threads,
      ),
    );
  }

  @override
  Future<String> backendName() => _engine.getBackendName();

  @override
  Stream<AssistChunk> generate(
    List<AssistMessage> messages, {
    int maxTokens = 512,
    double temperature = 0,
  }) {
    final request = <LlamaChatMessage>[
      for (final message in messages)
        LlamaChatMessage.fromText(
          role: switch (message.role) {
            AssistRole.system => LlamaChatRole.system,
            AssistRole.user => LlamaChatRole.user,
            AssistRole.assistant => LlamaChatRole.assistant,
          },
          text: message.text,
        ),
    ];
    return _engine
        .create(
          request,
          params: GenerationParams(maxTokens: maxTokens, temp: temperature),
          // Answers only. A model's private "thinking" would be counted as
          // answer tokens and slow every short job.
          enableThinking: false,
        )
        .map((chunk) {
          final usage = chunk.usage;
          return AssistChunk(
            chunk.text,
            usage: usage == null
                ? null
                : AssistUsage(
                    promptTokens: usage.promptTokens,
                    cachedPromptTokens: usage.cachedPromptTokens ?? 0,
                    completionTokens: usage.completionTokens,
                    timeToFirstToken: usage.timeToFirstToken,
                    duration: usage.duration,
                  ),
          );
        });
  }

  @override
  Future<AssistPerf?> lastPerformance() async {
    final perf = await _engine.getPerformanceContext();
    if (perf == null) return null;
    return AssistPerf(
      promptTokens: perf.promptEvalTokens,
      promptMs: perf.promptEvalMs,
      answerTokens: perf.evalTokens,
      answerMs: perf.evalMs,
    );
  }

  @override
  Future<int?> countTokens(String text) async {
    try {
      return await _engine.getTokenCount(text);
    } on LlamaException {
      return null;
    }
  }

  @override
  void cancel() => _engine.cancelGeneration();

  @override
  Future<void> dispose() => _engine.dispose();
}
