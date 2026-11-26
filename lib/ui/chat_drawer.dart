import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../chat/chat_controller.dart';
import '../chat/chat_store.dart';
import '../chat/conversation.dart';
import '../l10n/l10n.dart';
import 'settings_page.dart';

/// "14:05" for today, "24 Nov" for this year, "24 Nov 2025" before that.
String conversationDate(DateTime at, DateTime now, String locale) {
  final local = at.toLocal();
  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    return DateFormat.Hm(locale).format(local);
  }
  return local.year == now.year
      ? DateFormat.MMMd(locale).format(local)
      : DateFormat.yMMMd(locale).format(local);
}

/// Asks for a new name for [conversation] and saves it.
Future<void> renameConversation(
  BuildContext context,
  WidgetRef ref,
  Conversation conversation,
) async {
  final l = context.l10n;
  final controller = TextEditingController(text: conversation.title);
  final title = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.chatRename),
      content: TextField(
        key: const Key('rename-field'),
        controller: controller,
        autofocus: true,
        maxLength: 80,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        TextButton(
          key: const Key('rename-save'),
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: Text(l.save),
        ),
      ],
    ),
  );
  if (title == null || title.trim().isEmpty) return;
  await ref.read(chatControllerProvider.notifier).rename(conversation, title);
}

/// Asks before deleting [conversation] from every device.
Future<void> deleteConversation(
  BuildContext context,
  WidgetRef ref,
  Conversation conversation,
) async {
  final l = context.l10n;
  final sure = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.chatDeleteTitle),
      content: Text(l.chatDeleteBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.cancel),
        ),
        TextButton(
          key: const Key('delete-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l.delete),
        ),
      ],
    ),
  );
  if (sure != true) return;
  await ref.read(chatControllerProvider.notifier).delete(conversation);
}

/// The side panel: a new chat, the earlier chats, settings.
class ChatDrawer extends ConsumerWidget {
  const ChatDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final conversations = ref.watch(conversationsProvider);
    final open = ref.watch(chatControllerProvider).conversation?.id;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final now = DateTime.now();
    final list = conversations.value ?? const <Conversation>[];
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
              child: Text(l.appName, style: theme.textTheme.titleLarge),
            ),
            ListTile(
              key: const Key('drawer-new-chat'),
              leading: const Icon(Icons.add_comment_outlined),
              title: Text(l.chatNew),
              onTap: () {
                ref.read(chatControllerProvider.notifier).newChat();
                Navigator.of(context).pop();
              },
            ),
            const Divider(height: 1),
            Expanded(
              child: conversations.isLoading && list.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        l.chatListEmpty,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final conversation = list[index];
                        return ListTile(
                          key: Key('chat-${conversation.id}'),
                          selected: conversation.id == open,
                          title: Text(
                            conversation.title.isEmpty
                                ? l.chatUntitled
                                : conversation.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            conversationDate(
                              conversation.updatedAt,
                              now,
                              locale,
                            ),
                          ),
                          trailing: PopupMenuButton<String>(
                            key: Key('chat-menu-${conversation.id}'),
                            onSelected: (action) => action == 'rename'
                                ? renameConversation(context, ref, conversation)
                                : deleteConversation(
                                    context,
                                    ref,
                                    conversation,
                                  ),
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'rename',
                                child: Text(l.chatRename),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(l.delete),
                              ),
                            ],
                          ),
                          onTap: () {
                            ref
                                .read(chatControllerProvider.notifier)
                                .open(conversation);
                            Navigator.of(context).pop();
                          },
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            ListTile(
              key: const Key('drawer-settings'),
              leading: const Icon(Icons.settings_outlined),
              title: Text(l.settings),
              onTap: () {
                final navigator = Navigator.of(context);
                navigator.pop();
                navigator.push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AssistSettingsPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
