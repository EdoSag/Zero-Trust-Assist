import 'package:llamadart/llamadart.dart';

import 'assist_engine.dart';

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
  }) {
    return _engine.setModel(
      LlamaModel(ModelSource.path(path)),
      params: ModelParams(
        contextSize: contextSize,
        device: switch (device) {
          AssistDevice.cpu => ComputeDevice.cpu,
          AssistDevice.gpu => ComputeDevice.gpu,
        },
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
