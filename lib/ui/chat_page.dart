import 'dart:async';

import 'package:flutter/material.dart';

import '../engine/assist_engine.dart';
import '../engine/llamadart_engine.dart';
import '../lab/lab_result.dart';
import '../lab/lab_runner.dart';
import '../lab/model_catalog.dart';
import 'text_direction.dart';

/// Sent as the system message of every chat.
const String chatSystemPrompt =
    'You are ZT Assist, a helpful assistant that runs privately on the '
    "user's phone. Answer briefly and clearly, in the language the user "
    'writes in.';

/// A plain chat with one model, to judge its answers by hand. Nothing is
/// saved: the conversation is gone when the page closes.
class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.model,
    required this.modelPath,
    this.createEngine = LlamadartEngine.new,
  });

  final LabModel model;
  final String modelPath;

  /// Tests pass a fake engine here.
  final AssistEngine Function() createEngine;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final AssistEngine _engine = widget.createEngine();
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<AssistMessage> _messages = [];

  bool _loading = true;
  bool _answering = false;
  String? _loadError;
  String? _lastNote;
  String _liveAnswer = '';
  String _pendingAnswer = '';
  Timer? _flush;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await _engine.load(widget.modelPath);
    } on Object catch (error) {
      if (mounted) setState(() => _loadError = error.toString());
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _answering || _loading || _loadError != null) return;
    _input.clear();
    setState(() {
      _messages.add(AssistMessage.user(text));
      _answering = true;
      _liveAnswer = '';
      _pendingAnswer = '';
      _lastNote = null;
    });
    // See RunPage: the screen is refreshed on a timer, not on every piece.
    _flush = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_pendingAnswer == _liveAnswer || !mounted) return;
      setState(() => _liveAnswer = _pendingAnswer);
      _scrollToEnd();
    });

    final answer = StringBuffer();
    final watch = Stopwatch()..start();
    int? firstTextMs;
    AssistUsage? usage;
    String? error;
    try {
      final pieces = _engine.generate([
        const AssistMessage.system(chatSystemPrompt),
        ..._messages,
      ], temperature: 0.7);
      await for (final piece in pieces) {
        usage = piece.usage ?? usage;
        if (piece.text.isEmpty) continue;
        firstTextMs ??= watch.elapsedMilliseconds;
        answer.write(piece.text);
        _pendingAnswer = answer.toString();
      }
    } on Object catch (failure) {
      error = failure.toString();
    }
    watch.stop();
    _flush?.cancel();

    String? note = error;
    if (error == null) {
      AssistPerf? perf;
      try {
        perf = await _engine.lastPerformance();
      } on Object {
        perf = null;
      }
      final speed = measureSpeed(
        perf: perf,
        usage: usage,
        firstTextMs: firstTextMs,
        totalMs: watch.elapsedMilliseconds,
      );
      note =
          'Writes ${formatSpeed(speed.write)}, first text after '
          '${formatSeconds(firstTextMs)}';
    }
    if (!mounted) return;
    setState(() {
      final text = answer.toString().trim();
      if (text.isNotEmpty) _messages.add(AssistMessage.assistant(text));
      _answering = false;
      _liveAnswer = '';
      _lastNote = note;
    });
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _flush?.cancel();
    _engine.cancel();
    unawaited(_engine.dispose());
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loadError = _loadError;
    final note = _lastNote;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.model.title),
        actions: [
          IconButton(
            tooltip: 'New chat',
            onPressed: _answering
                ? null
                : () => setState(() {
                    _messages.clear();
                    _lastNote = null;
                  }),
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_loading) const LinearProgressIndicator(),
            Expanded(
              child: loadError != null
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(
                        'The model did not load.\n\n$loadError',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    )
                  : ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_messages.isEmpty && !_loading)
                          Text(
                            'Ask anything, in Hebrew or English. This chat is '
                            'not saved.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        if (_loading) const Text('Loading the model...'),
                        for (final message in _messages)
                          _Bubble(
                            text: message.text,
                            mine: message.role == AssistRole.user,
                          ),
                        if (_answering)
                          _Bubble(
                            text: _liveAnswer.isEmpty ? '...' : _liveAnswer,
                            mine: false,
                          ),
                        if (note != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(note, style: theme.textTheme.bodySmall),
                          ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 5,
                      enabled: !_loading && loadError == null,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: 'Message',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (_answering)
                    IconButton.filledTonal(
                      tooltip: 'Stop',
                      onPressed: _engine.cancel,
                      icon: const Icon(Icons.stop),
                    )
                  else
                    IconButton.filled(
                      tooltip: 'Send',
                      onPressed: _loading || loadError != null ? null : _send,
                      icon: const Icon(Icons.arrow_upward),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.mine});

  final String text;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.85,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: mine ? colors.primaryContainer : colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: AutoDirectionText(
          text,
          fill: false,
          style: TextStyle(
            color: mine ? colors.onPrimaryContainer : colors.onSurface,
          ),
        ),
      ),
    );
  }
}
