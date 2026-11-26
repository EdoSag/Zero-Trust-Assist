import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/assist_engine.dart';
import '../engine/llamadart_engine.dart';

/// The one model the app keeps in memory for chatting.
///
/// A model takes gigabytes of memory and seconds to load, so it is loaded on
/// the first message and kept until another model is picked, the phone test
/// needs the memory, or the app locks.
class Assistant {
  Assistant({required this.createEngine});

  /// Makes a fresh engine. Tests pass a fake.
  final AssistEngine Function() createEngine;

  AssistEngine? _engine;
  String? _path;

  /// Rises with every [unload], so a load that was still running when the
  /// memory was asked back knows not to keep its model.
  int _unloads = 0;

  /// The file of the loaded model, or null.
  String? get loadedPath => _path;

  /// Loads the model at [path] unless it is the one already in memory.
  ///
  /// False when [unload] was called while the model was loading (the app
  /// locked, or the phone test asked for the memory): the model is freed
  /// again, not kept behind the caller's back.
  Future<bool> ensureLoaded(String path, {int contextSize = 4096}) async {
    if (_engine != null && _path == path) return true;
    await unload();
    final unloads = _unloads;
    final engine = createEngine();
    try {
      // The processor: it works on every phone. GrapheneOS gives apps no
      // graphics chip for models.
      await engine.load(path, contextSize: contextSize);
    } on Object {
      try {
        await engine.dispose();
      } on Object {
        // The load error is the one worth reporting.
      }
      rethrow;
    }
    if (unloads != _unloads) {
      try {
        await engine.dispose();
      } on Object {
        // Nothing more to free.
      }
      return false;
    }
    _engine = engine;
    _path = path;
    return true;
  }

  /// The answer to [messages], piece by piece. [ensureLoaded] comes first.
  Stream<AssistChunk> answer(
    List<AssistMessage> messages, {
    required int maxTokens,
  }) {
    final engine = _engine;
    if (engine == null) {
      throw StateError('No model is loaded.');
    }
    // A little variety reads more naturally in a chat than the fixed answers
    // the phone test wants.
    return engine.generate(messages, maxTokens: maxTokens, temperature: 0.7);
  }

  /// Stops the answer being written.
  void cancel() => _engine?.cancel();

  /// Frees the model's memory.
  Future<void> unload() async {
    _unloads++;
    final engine = _engine;
    _engine = null;
    _path = null;
    if (engine == null) return;
    engine.cancel();
    try {
      await engine.dispose();
    } on Object {
      // Nothing more to free.
    }
  }
}

final assistantProvider = Provider<Assistant>((ref) {
  final assistant = Assistant(createEngine: LlamadartEngine.new);
  ref.onDispose(() => unawaited(assistant.unload()));
  return assistant;
});
