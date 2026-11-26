import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat/chat_controller.dart';
import '../chat/conversation.dart';
import '../l10n/l10n.dart';
import 'chat_drawer.dart';
import 'markdown_lite.dart';
import 'models_page.dart';
import 'text_direction.dart';

/// The chat: the open conversation, the box to write in, and the side panel
/// with the earlier conversations.
class ChatHomePage extends ConsumerStatefulWidget {
  const ChatHomePage({super.key});

  @override
  ConsumerState<ChatHomePage> createState() => _ChatHomePageState();
}

class _ChatHomePageState extends ConsumerState<ChatHomePage> {
  final _input = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // The send button is off while the box is empty.
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    ref.read(chatControllerProvider.notifier).send(text);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final chat = ref.watch(chatControllerProvider);
    final controller = ref.read(chatControllerProvider.notifier);
    final conversation = chat.conversation;
    return Scaffold(
      drawer: const ChatDrawer(),
      appBar: AppBar(
        title: Text(
          conversation == null || conversation.title.isEmpty
              ? l.appName
              : conversation.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            key: const Key('chat-new'),
            tooltip: l.chatNew,
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: conversation == null ? null : controller.newChat,
          ),
          if (conversation != null)
            PopupMenuButton<String>(
              key: const Key('chat-menu'),
              enabled: !chat.busy,
              onSelected: (action) => action == 'rename'
                  ? renameConversation(context, ref, conversation)
                  : deleteConversation(context, ref, conversation),
              itemBuilder: (context) => [
                PopupMenuItem(value: 'rename', child: Text(l.chatRename)),
                PopupMenuItem(value: 'delete', child: Text(l.delete)),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: chat.messages.isEmpty && !chat.busy
                  ? const _EmptyChat()
                  : _Messages(chat: chat),
            ),
            if (chat.problem != null)
              _ProblemBar(chat: chat, onDismiss: controller.clearProblem),
            _Composer(
              input: _input,
              focus: _focus,
              busy: chat.busy,
              onSend: _send,
              onStop: controller.stop,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              l.chatEmptyTitle,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l.chatEmptyHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The messages, newest at the bottom. The list is built from the bottom
/// up, so it stays on the newest line while an answer grows.
class _Messages extends StatelessWidget {
  const _Messages({required this.chat});

  final ChatState chat;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final messages = chat.messages;
    final extra = chat.busy ? 1 : 0;
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      itemCount: messages.length + extra,
      itemBuilder: (context, index) {
        if (chat.busy && index == 0) {
          if (chat.partial.isNotEmpty) {
            return _Bubble(
              key: const Key('answer-in-progress'),
              role: ChatRole.assistant,
              text: chat.partial,
            );
          }
          return _Waiting(
            label: chat.phase == ChatPhase.loadingModel
                ? l.chatLoadingModel
                : l.chatThinking,
          );
        }
        final message = messages[messages.length - 1 - (index - extra)];
        return _Bubble(
          role: message.role,
          text: message.text,
          stopped: message.stopped,
          showCopy: message.role == ChatRole.assistant,
        );
      },
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              key: const Key('chat-waiting'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    super.key,
    required this.role,
    required this.text,
    this.stopped = false,
    this.showCopy = false,
  });

  final ChatRole role;
  final String text;
  final bool stopped;
  final bool showCopy;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mine = role == ChatRole.user;
    final width = MediaQuery.sizeOf(context).width;
    return Align(
      // The user's messages sit at the end of the line, the answers at its
      // start: right and left in English, mirrored in Hebrew.
      alignment: mine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width * (mine ? 0.82 : 0.92)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: mine
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: SelectionArea(
                    child: mine
                        ? Text(
                            text,
                            textDirection: directionOf(text),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: scheme.onPrimaryContainer,
                            ),
                          )
                        : MarkdownLite(text),
                  ),
                ),
              ),
              if (stopped || showCopy)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showCopy)
                      IconButton(
                        tooltip: l.copy,
                        visualDensity: VisualDensity.compact,
                        iconSize: 18,
                        icon: const Icon(Icons.copy_outlined),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await Clipboard.setData(ClipboardData(text: text));
                          messenger.showSnackBar(
                            SnackBar(content: Text(l.copied)),
                          );
                        },
                      ),
                    if (stopped)
                      Text(
                        l.chatStopped,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProblemBar extends StatelessWidget {
  const _ProblemBar({required this.chat, required this.onDismiss});

  final ChatState chat;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final problem = chat.problem!;
    final detail = chat.problemDetail;
    return Container(
      key: const Key('chat-problem'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 4, 10),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(switch (problem) {
                  ChatProblem.modelMissing => l.problemModelMissing,
                  ChatProblem.loadFailed => l.problemLoadFailed,
                  ChatProblem.answerFailed => l.problemAnswerFailed,
                  ChatProblem.saveFailed => l.problemSaveFailed,
                }, style: TextStyle(color: scheme.onErrorContainer)),
                if (detail != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      detail,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ),
                if (problem == ChatProblem.modelMissing)
                  TextButton(
                    key: const Key('problem-models'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ModelsPage(),
                      ),
                    ),
                    child: Text(l.settingsModel),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: l.close,
            icon: Icon(Icons.close, color: scheme.onErrorContainer),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.input,
    required this.focus,
    required this.busy,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController input;
  final FocusNode focus;
  final bool busy;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final empty = input.text.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('chat-input'),
                  controller: input,
                  focusNode: focus,
                  minLines: 1,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  // Follows what is typed: Hebrew starts at the right even
                  // in an English screen.
                  textDirection: input.text.isEmpty
                      ? null
                      : directionOf(input.text),
                  decoration: InputDecoration(
                    hintText: l.chatHint,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              busy
                  ? IconButton.filledTonal(
                      key: const Key('chat-stop'),
                      tooltip: l.chatStop,
                      icon: const Icon(Icons.stop),
                      onPressed: onStop,
                    )
                  : IconButton.filled(
                      key: const Key('chat-send'),
                      tooltip: l.chatSend,
                      icon: const Icon(Icons.arrow_upward),
                      onPressed: empty ? null : onSend,
                    ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l.chatDisclaimer,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
