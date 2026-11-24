import 'dart:async';

import 'package:zerotrust_assist/engine/assist_engine.dart';

/// An engine that answers from a script, for tests.
class FakeEngine implements AssistEngine {
  FakeEngine({
    this.loadError,
    this.answer = _defaultAnswer,
    this.perf,
    this.usage,
    this.onPiece,
  });

  static List<String> _defaultAnswer(List<AssistMessage> messages) => const [
    'Hello',
    ' there',
  ];

  /// Thrown by [load] when set.
  final Object? loadError;

  /// The pieces of the answer to a request. Throw to fail the request.
  final List<String> Function(List<AssistMessage> messages) answer;
  final AssistPerf? perf;
  final AssistUsage? usage;

  /// Called after each piece is handed out.
  final void Function(FakeEngine engine)? onPiece;

  final List<List<AssistMessage>> requests = [];
  AssistDevice? loadedDevice;
  bool disposed = false;
  bool _cancelled = false;

  @override
  Future<void> load(
    String path, {
    AssistDevice device = AssistDevice.cpu,
    int contextSize = 4096,
  }) async {
    final error = loadError;
    if (error != null) throw error;
    loadedDevice = device;
  }

  @override
  Future<String> backendName() async => 'Fake';

  @override
  Stream<AssistChunk> generate(
    List<AssistMessage> messages, {
    int maxTokens = 512,
    double temperature = 0,
  }) async* {
    requests.add(messages);
    _cancelled = false;
    final pieces = answer(messages);
    for (final piece in pieces) {
      if (_cancelled) return;
      yield AssistChunk(piece);
      onPiece?.call(this);
    }
    yield AssistChunk('', usage: usage);
  }

  @override
  Future<AssistPerf?> lastPerformance() async => perf;

  @override
  Future<int?> countTokens(String text) async =>
      text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;

  @override
  void cancel() => _cancelled = true;

  @override
  Future<void> dispose() async => disposed = true;
}
