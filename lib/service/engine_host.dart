import 'dart:async';
import 'dart:collection';

import '../chat/assistant.dart';
import '../chat/prompt.dart';
import 'assist_protocol.dart';

/// Sends one message back to the app that asked: `chunk`, `done` or
/// `failed`, each with the request's id.
typedef HostEmit = void Function(String method, Map<String, Object?> arguments);

/// Why a request could not be answered. The asking app turns the code into
/// words for its user.
abstract final class AssistFailure {
  /// The request is not one this version understands.
  static const unsupported = 'unsupported';

  /// No model is on the phone: the user has to open ZT Assist and get one.
  static const noModel = 'no_model';

  /// The model file is there but did not load (too little free memory).
  static const loadFailed = 'load_failed';

  /// The model stopped with an error in the middle of the answer.
  static const failed = 'failed';
}

/// Answers the requests of other Zero-Trust apps, one at a time, with the
/// model the user picked.
///
/// It knows nothing of Android: the service hands it requests and it hands
/// back pieces of answers through [emit], so it runs in a test as it does
/// on the phone.
class EngineHost {
  EngineHost({
    required this.assistant,
    required this.modelPath,
    required this.emit,
  });

  final Assistant assistant;

  /// The file of the model to answer with, or null when none is on the
  /// phone. Asked for every request: the user may have switched models.
  final Future<String?> Function() modelPath;
  final HostEmit emit;

  final Queue<AssistRequest> _waiting = Queue();
  AssistRequest? _current;
  bool _stopCurrent = false;
  bool _running = false;
  bool _closed = false;

  /// What an app is told before it asks for anything.
  Future<Map<String, Object?>> status() async {
    String? path;
    try {
      path = await modelPath();
    } on Object {
      path = null;
    }
    return {
      'protocol': assistProtocol,
      'ready': path != null,
      'busy': _current != null,
    };
  }

  /// Takes a request. Its answer arrives through [emit].
  void ask(Map<Object?, Object?> arguments) {
    final request = AssistRequest.fromMap(arguments);
    if (request == null) {
      final id = arguments['id'];
      _fail(id is String ? id : '', AssistFailure.unsupported);
      return;
    }
    if (_closed) {
      _done(request.id, stopped: true);
      return;
    }
    _waiting.add(request);
    unawaited(_run());
  }

  /// Stops the request [id], whether it is being answered or still waiting
  /// its turn. What was written so far stays with the asking app.
  void cancel(String id) {
    if (_current?.id == id) {
      _stopCurrent = true;
      assistant.cancel();
      return;
    }
    final before = _waiting.length;
    _waiting.removeWhere((request) => request.id == id);
    if (_waiting.length != before) _done(id, stopped: true);
  }

  /// Stops everything and gives the model's memory back.
  Future<void> shutdown() async {
    _closed = true;
    if (_current != null) {
      _stopCurrent = true;
      assistant.cancel();
    }
    while (_waiting.isNotEmpty) {
      _done(_waiting.removeFirst().id, stopped: true);
    }
    await assistant.unload();
  }

  Future<void> _run() async {
    if (_running) return;
    _running = true;
    try {
      while (_waiting.isNotEmpty && !_closed) {
        final request = _waiting.removeFirst();
        _current = request;
        _stopCurrent = false;
        try {
          await _answer(request);
        } finally {
          _current = null;
        }
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _answer(AssistRequest request) async {
    String? path;
    try {
      path = await modelPath();
    } on Object {
      path = null;
    }
    if (path == null) {
      _fail(request.id, AssistFailure.noModel);
      return;
    }

    bool loaded;
    try {
      loaded = await assistant.ensureLoaded(path, contextSize: contextTokens);
    } on Object catch (error) {
      _fail(request.id, AssistFailure.loadFailed, '$error');
      return;
    }
    // Stopped, or shut down, while the model was loading.
    if (!loaded || _stopCurrent) {
      _done(request.id, stopped: true);
      return;
    }

    final prompt = buildTaskPrompt(request);
    final watch = Stopwatch()..start();
    var pieces = 0;
    int? tokens;
    int? firstPiece;
    try {
      final answer = assistant.answer(
        prompt.messages,
        maxTokens: prompt.maxTokens,
        temperature: 0,
      );
      await for (final piece in answer) {
        tokens = piece.usage?.completionTokens ?? tokens;
        if (piece.text.isEmpty) continue;
        pieces++;
        firstPiece ??= watch.elapsedMilliseconds;
        emit('chunk', {'id': request.id, 'text': piece.text});
      }
    } on Object catch (error) {
      _fail(request.id, AssistFailure.failed, '$error');
      return;
    }
    _done(
      request.id,
      stopped: _stopCurrent,
      truncated: prompt.truncated,
      // The runtime's own count where it gives one; else one per piece,
      // which is what a piece is.
      tokens: tokens ?? pieces,
      milliseconds: watch.elapsedMilliseconds,
      // Reading the text comes before the first piece; the rest is writing.
      // With both, the asking app can tell the writing speed.
      firstMilliseconds: firstPiece ?? watch.elapsedMilliseconds,
    );
  }

  void _done(
    String id, {
    required bool stopped,
    bool truncated = false,
    int tokens = 0,
    int milliseconds = 0,
    int firstMilliseconds = 0,
  }) => emit('done', {
    'id': id,
    'stopped': stopped,
    'truncated': truncated,
    'tokens': tokens,
    'milliseconds': milliseconds,
    'firstMilliseconds': firstMilliseconds,
  });

  void _fail(String id, String code, [String? detail]) =>
      emit('failed', {'id': id, 'code': code, 'detail': detail});
}
