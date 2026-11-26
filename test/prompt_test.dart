import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_assist/chat/conversation.dart';
import 'package:zerotrust_assist/chat/prompt.dart';
import 'package:zerotrust_assist/engine/assist_engine.dart';

Conversation _conversation(List<(ChatRole, String)> messages) {
  final at = DateTime.utc(2026, 11, 26);
  var conversation = Conversation.start('c', at);
  for (final (role, text) in messages) {
    conversation = conversation.withMessage(
      ChatMessage(role: role, text: text, at: at),
    );
  }
  return conversation;
}

void main() {
  final now = DateTime(2026, 11, 26, 12);

  test('the instructions come first and carry the date', () {
    final prompt = buildPrompt(_conversation([(ChatRole.user, 'Hi')]), now);
    expect(prompt.first.role, AssistRole.system);
    expect(prompt.first.text, contains('Thursday, 2026-11-26'));
    expect(prompt.first.text, contains('language the user writes in'));
    expect(prompt.last.role, AssistRole.user);
    expect(prompt.last.text, 'Hi');
  });

  test('earlier messages are sent along, in order', () {
    final prompt = buildPrompt(
      _conversation([
        (ChatRole.user, 'One'),
        (ChatRole.assistant, 'Two'),
        (ChatRole.user, 'Three'),
      ]),
      now,
    );
    expect(prompt.skip(1).map((m) => (m.role, m.text)), [
      (AssistRole.user, 'One'),
      (AssistRole.assistant, 'Two'),
      (AssistRole.user, 'Three'),
    ]);
  });

  test('a long conversation keeps its newest messages', () {
    final long = 'x' * 2500;
    final prompt = buildPrompt(
      _conversation([
        (ChatRole.user, 'oldest $long'),
        (ChatRole.assistant, 'old answer $long'),
        (ChatRole.user, 'recent $long'),
        (ChatRole.assistant, 'recent answer'),
        (ChatRole.user, 'newest'),
      ]),
      now,
    );
    final sent = prompt.skip(1).toList();
    expect(sent.first.text, startsWith('recent '));
    expect(sent.first.role, AssistRole.user);
    expect(sent.last.text, 'newest');
    final letters = sent.fold<int>(0, (sum, m) => sum + m.text.length);
    expect(letters, lessThanOrEqualTo(historyLetters));
  });

  test('what is kept never starts with an answer', () {
    final long = 'x' * 3500;
    final prompt = buildPrompt(
      _conversation([
        (ChatRole.user, 'question $long'),
        (ChatRole.assistant, 'answer $long'),
        (ChatRole.user, 'follow up'),
      ]),
      now,
    );
    expect(prompt.skip(1).map((m) => m.text), ['follow up']);
  });

  test('one huge message is cut, not dropped', () {
    final huge = 'א' * (historyLetters + 500);
    final prompt = buildPrompt(_conversation([(ChatRole.user, huge)]), now);
    expect(prompt, hasLength(2));
    expect(prompt.last.text.runes.length, historyLetters);
  });

  test('the answer and the history fit the model together', () {
    // Hebrew is the costly case: about one token for every two letters.
    const instructions = 200;
    expect(
      historyLetters ~/ 2 + answerTokens + instructions,
      lessThanOrEqualTo(contextTokens + 200),
    );
  });
}
