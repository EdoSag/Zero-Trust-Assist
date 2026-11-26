import '../engine/assist_engine.dart';
import 'conversation.dart';

/// How much the model can hold at once: the instructions, the conversation
/// so far and the answer it is writing.
const int contextTokens = 4096;

/// The longest answer, in tokens.
const int answerTokens = 1024;

/// How many letters of the conversation are sent along with a new message.
///
/// The model counts tokens, not letters, and counting them exactly would
/// load the tokenizer for every message. Hebrew takes about one token for
/// every two or three letters and English one for every four, so 6,000
/// letters stay below the 2,900 tokens left after the instructions and the
/// answer, in either language.
const int historyLetters = 6000;

/// What the model is told before every conversation.
String systemPrompt(DateTime now) {
  // Written out by hand: the app's date formats exist only for the language
  // on screen, and the model is told the date in English either way.
  const days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  String two(int value) => value.toString().padLeft(2, '0');
  final today =
      '${days[now.weekday - 1]}, ${now.year}-${two(now.month)}-${two(now.day)}';
  return 'You are ZT Assist, a private assistant that runs entirely on the '
      "user's phone. Nothing the user writes leaves the phone. You cannot "
      "browse the internet or see the user's other apps. Answer in the "
      'language the user writes in. Be accurate and brief. If you are not '
      'sure, say so instead of guessing. Today is $today.';
}

/// The instructions and the end of [conversation], as much as fits.
///
/// The newest messages are kept and the oldest dropped. The last message is
/// always sent; one longer than the whole budget is cut at the end, so the
/// model still sees how it starts.
List<AssistMessage> buildPrompt(Conversation conversation, DateTime now) {
  final kept = <ChatMessage>[];
  var letters = 0;
  for (final message in conversation.messages.reversed) {
    final length = message.text.runes.length;
    if (kept.isNotEmpty && letters + length > historyLetters) break;
    kept.add(message);
    letters += length;
  }
  // A conversation must open with the user, not with half an exchange.
  while (kept.isNotEmpty && kept.last.role != ChatRole.user) {
    kept.removeLast();
  }
  return [
    AssistMessage.system(systemPrompt(now)),
    for (final message in kept.reversed)
      message.role == ChatRole.user
          ? AssistMessage.user(_cut(message.text))
          : AssistMessage.assistant(_cut(message.text)),
  ];
}

String _cut(String text) {
  final letters = text.runes;
  if (letters.length <= historyLetters) return text;
  return String.fromCharCodes(letters.take(historyLetters));
}
