import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_assist/chat/chat_store.dart';
import 'package:zerotrust_assist/chat/conversation.dart';

void main() {
  final start = DateTime.utc(2026, 11, 26, 10);

  test('the first message names the conversation', () {
    final conversation = Conversation.start('c1', start).withMessage(
      ChatMessage(
        role: ChatRole.user,
        text: 'מה השעה בטוקיו?\nתודה',
        at: start,
      ),
    );
    expect(conversation.title, 'מה השעה בטוקיו?');
    expect(conversation.messages, hasLength(1));
    expect(conversation.updatedAt, start);
  });

  test('a long first message is cut to a short title', () {
    final title = Conversation.titleFrom('word ' * 40);
    expect(title.runes.length, lessThanOrEqualTo(Conversation.titleLength + 1));
    expect(title, endsWith('…'));
  });

  test('later messages and answers leave the title alone', () {
    var conversation = Conversation.start(
      'c1',
      start,
    ).withMessage(ChatMessage(role: ChatRole.user, text: 'First', at: start));
    conversation = conversation
        .withMessage(
          ChatMessage(role: ChatRole.assistant, text: 'Answer', at: start),
        )
        .withMessage(ChatMessage(role: ChatRole.user, text: 'Next', at: start));
    expect(conversation.title, 'First');
    expect(conversation.messages.map((m) => m.text), [
      'First',
      'Answer',
      'Next',
    ]);
  });

  test('a renamed conversation keeps its name', () {
    final conversation = Conversation.start('c1', start)
        .withMessage(ChatMessage(role: ChatRole.user, text: 'First', at: start))
        .renamed('  Trip plan ')
        .withMessage(ChatMessage(role: ChatRole.user, text: 'More', at: start));
    expect(conversation.title, 'Trip plan');
  });

  test('a conversation survives being stored', () {
    final conversation = Conversation.start('c1', start)
        .withMessage(ChatMessage(role: ChatRole.user, text: 'שלום', at: start))
        .withMessage(
          ChatMessage(
            role: ChatRole.assistant,
            text: 'Half an ans',
            at: start.add(const Duration(seconds: 9)),
            stopped: true,
          ),
        );
    final synced = start.add(const Duration(minutes: 1));
    final back = Conversation.fromJson('c1', conversation.toJson(), synced);
    expect(back.id, 'c1');
    expect(back.title, 'שלום');
    expect(back.createdAt, start);
    expect(back.updatedAt, synced);
    expect(back.messages[0].role, ChatRole.user);
    expect(back.messages[0].text, 'שלום');
    expect(back.messages[0].stopped, false);
    expect(back.messages[1].role, ChatRole.assistant);
    expect(back.messages[1].stopped, true);
    expect(back.messages[1].at, start.add(const Duration(seconds: 9)));
  });

  test('an item with missing or odd fields still opens', () {
    final back = Conversation.fromJson('c1', {
      'messages': [
        {'r': 'u'},
        'not a message',
        {'r': 'a', 't': 'ok', 'at': 'not a date'},
      ],
    }, start);
    expect(back.title, '');
    expect(back.createdAt, start);
    expect(back.messages.map((m) => m.text), ['', 'ok']);
  });

  test('the collection stores chats under their own kind', () {
    final conversation = Conversation.start('c1', start);
    final json = conversationsCollection.encode(conversation);
    expect(json['kind'], 'chat');
    expect(conversationsCollection.owns(json), true);
    expect(conversationsCollection.owns({'kind': 'account'}), false);
  });

  test('conversations sort by their last change, newest first', () {
    final older = Conversation.start('a', start);
    final newer = Conversation.start('b', start.add(const Duration(hours: 1)));
    expect(([older, newer]..sort(compareConversations)).map((c) => c.id), [
      'b',
      'a',
    ]);
  });
}
