/// What other Zero-Trust apps can ask ZT Assist to do, and how a request
/// becomes what the model is sent.
///
/// The wording of each job lives here, in ZT Assist, and not in the apps
/// that ask: it can then be improved for every app with one update.
library;

import '../engine/assist_engine.dart';

/// Raised when a request or an answer changes shape. An app that speaks a
/// newer version than this one is told to update ZT Assist.
const int assistProtocol = 1;

/// The longest text a summary, a title or a question is given, in letters.
/// The same budget as a chat: it leaves room for the instructions and the
/// answer in the model's memory, in Hebrew and in English.
const int readLetters = 6000;

/// The longest text that is rewritten, proofread or translated. Shorter
/// than [readLetters] because the answer is as long as the text, and both
/// must fit in the model's memory at once.
const int transformLetters = 2400;

/// The longest answer, in tokens.
const int taskAnswerTokens = 1280;

/// The longest line quick add reads. A task or an event is typed in a
/// sentence or two; the rest of a longer text would only slow the answer.
const int quickAddLetters = 500;

/// A job another app can ask for.
enum AssistTask {
  summarize,
  rewrite,
  proofread,
  translate,
  title,

  /// The app's own instruction, in [AssistRequest.instruction].
  ask,

  /// A typed line like "dentist tomorrow at 9" read into a title, a day,
  /// a time, a length, a reminder and a place. See [quickAddInstruction].
  quickAdd;

  static AssistTask? byName(Object? name) {
    for (final task in values) {
      if (task.name == name) return task;
    }
    return null;
  }

  /// Whether the answer is about as long as the text.
  bool get transforms => switch (this) {
    rewrite || proofread || translate => true,
    summarize || title || ask || quickAdd => false,
  };
}

/// One request from another app.
class AssistRequest {
  const AssistRequest({
    required this.id,
    required this.task,
    required this.text,
    this.instruction,
    this.language,
    this.maxTokens,
  });

  /// The asking app's name for the request, unique among those in flight.
  final String id;
  final AssistTask task;

  /// The text to work on.
  final String text;

  /// [AssistTask.ask] only: what to do with the text.
  final String? instruction;

  /// [AssistTask.translate] only: the language to translate into, `he` or
  /// `en`. Left out, Hebrew text goes to English and anything else to
  /// Hebrew.
  final String? language;

  /// A shorter limit on the answer than the job's own.
  final int? maxTokens;

  /// Null when [map] is not a request this version understands.
  static AssistRequest? fromMap(Map<Object?, Object?> map) {
    final id = map['id'];
    final task = AssistTask.byName(map['task']);
    final text = map['text'];
    if (id is! String || task == null || text is! String) return null;
    if (text.trim().isEmpty) return null;
    final instruction = map['instruction'];
    final language = map['language'];
    final maxTokens = map['maxTokens'];
    if (task == AssistTask.ask &&
        (instruction is! String || instruction.trim().isEmpty)) {
      return null;
    }
    return AssistRequest(
      id: id,
      task: task,
      text: text,
      instruction: instruction is String ? instruction : null,
      language: language is String ? language : null,
      maxTokens: maxTokens is int ? maxTokens : null,
    );
  }
}

/// What the model is sent for one request.
class TaskPrompt {
  const TaskPrompt({
    required this.messages,
    required this.maxTokens,
    required this.truncated,
    this.stopAfterObject = false,
  });

  final List<AssistMessage> messages;
  final int maxTokens;

  /// The answer is one JSON object: once it has closed, the model is
  /// stopped, so it does not go on to write a second one.
  final bool stopAfterObject;

  /// Whether the text was longer than the model can take, so only its
  /// beginning was used.
  final bool truncated;
}

/// Sent as the system message with every request. The same words the phone
/// test measured the models with.
const String taskSystemPrompt =
    'You are ZT Assist, a writing and organizing assistant that runs on the '
    "user's phone. Do exactly what the user asks. Answer in the same language "
    "as the user's text unless asked to translate. Give only the result, with "
    'no introduction and no closing remark.';

/// Whether [text] is written mostly in Hebrew letters.
bool mostlyHebrew(String text) {
  var hebrew = 0;
  var latin = 0;
  for (final rune in text.runes) {
    if (rune >= 0x05D0 && rune <= 0x05EA) {
      hebrew++;
    } else if ((rune >= 0x41 && rune <= 0x5A) ||
        (rune >= 0x61 && rune <= 0x7A)) {
      latin++;
    }
  }
  return hebrew > latin;
}

/// The instruction that goes above the text, in the text's own language:
/// the models follow a Hebrew instruction over Hebrew text more reliably
/// than an English one, and answer in Hebrew.
String taskInstruction(AssistRequest request, {required bool hebrew}) {
  switch (request.task) {
    case AssistTask.summarize:
      return hebrew
          ? 'סכם את הטקסט הבא בכמה נקודות קצרות:'
          : 'Summarize the following text in a few short bullet points:';
    case AssistTask.rewrite:
      return hebrew
          ? 'נסח מחדש את הטקסט הבא כך שיהיה ברור וקריא יותר, בלי לשנות את '
                'המשמעות. החזר רק את הטקסט המנוסח מחדש:'
          : 'Rewrite the following text so it is clearer and easier to read, '
                'without changing its meaning. Return only the rewritten '
                'text:';
    case AssistTask.proofread:
      return hebrew
          ? 'תקן שגיאות כתיב, דקדוק ופיסוק בטקסט הבא, בלי לשנות את הניסוח. '
                'החזר רק את הטקסט המתוקן:'
          : 'Fix the spelling, grammar and punctuation of the following '
                'text without rewording it. Return only the corrected text:';
    case AssistTask.translate:
      final target = request.language ?? (hebrew ? 'en' : 'he');
      if (target == 'he') {
        return hebrew ? 'תרגם לעברית:' : 'Translate to Hebrew:';
      }
      return hebrew ? 'תרגם לאנגלית:' : 'Translate to English:';
    case AssistTask.title:
      return hebrew
          ? 'הצע כותרת קצרה, עד שש מילים, לטקסט הבא. החזר רק את הכותרת:'
          : 'Suggest a short title, six words at most, for the following '
                'text. Return only the title:';
    case AssistTask.ask:
      return request.instruction!.trim();
    case AssistTask.quickAdd:
      // In one language, and it needs the day: see [quickAddInstruction].
      return quickAddInstruction(DateTime.now());
  }
}

const _dayNames = [
  ('Monday', 'יום שני'),
  ('Tuesday', 'יום שלישי'),
  ('Wednesday', 'יום רביעי'),
  ('Thursday', 'יום חמישי'),
  ('Friday', 'יום שישי'),
  ('Saturday', 'שבת'),
  ('Sunday', 'יום ראשון'),
];

String _isoDay(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// What the model is told for [AssistTask.quickAdd], up to the line itself.
///
/// The keys are a contract with `ZtAssistQuickAdd` in the Core package
/// `zt_assist`, which checks the answer: title, date, time, minutes,
/// remind, place.
///
/// A small model is poor at counting days, so the coming days are listed
/// with their dates and it only has to look one up. The examples fix the
/// shape of the answer; their dates are worked out from [now], so they
/// agree with the list. One language for the instruction, as measured on
/// the phone: the model keeps the title in the line's own language.
String quickAddInstruction(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  DateTime plus(int days) =>
      DateTime(today.year, today.month, today.day + days);
  String name(DateTime day) => _dayNames[day.weekday - 1].$1;
  String hebrewName(DateTime day) => _dayNames[day.weekday - 1].$2;

  final days = StringBuffer();
  for (var i = 1; i <= 8; i++) {
    final day = plus(i);
    days.writeln(
      '${_isoDay(day)} ${name(day)}, ${hebrewName(day)}'
      '${i == 1 ? ' (tomorrow, מחר)' : ''}',
    );
  }
  // The coming Sunday, never today: "on Sunday" said on a Sunday means
  // the next one.
  final sunday = plus(
    (DateTime.sunday - today.weekday) % 7 == 0
        ? 7
        : (DateTime.sunday - today.weekday) % 7,
  );

  return 'Today is ${name(today)}, ${hebrewName(today)}, ${_isoDay(today)}. '
      'The coming days:\n'
      '$days\n'
      'Read the last note and answer with one line of JSON, with no code '
      'block and nothing after it. Use exactly these keys:\n'
      '"title": what to do or what happens. Short, in the note\'s own '
      'language and words, without the day, the time, the place and the '
      'reminder.\n'
      '"date": the day as YYYY-MM-DD, taken from the list above when it is '
      'there, or null when the note names no day.\n'
      '"time": the start time as HH:MM in 24-hour time, or null when the '
      'note names no time.\n'
      '"minutes": how long it takes, in minutes, or null.\n'
      '"remind": how many minutes before it to remind, or null.\n'
      '"place": where it is, in the note\'s own words, or null.\n\n'
      'Note: Dentist tomorrow at 9, remind me an hour before\n'
      '{"title":"Dentist","date":"${_isoDay(plus(1))}","time":"09:00",'
      '"minutes":null,"remind":60,"place":null}\n\n'
      'Note: פגישה עם דנה ביום ראשון בארבע וחצי אחר הצהריים בקפה נחמה, '
      'שעה וחצי\n'
      '{"title":"פגישה עם דנה","date":"${_isoDay(sunday)}","time":"16:30",'
      '"minutes":90,"remind":null,"place":"קפה נחמה"}\n\n'
      'Note: לקנות חלב\n'
      '{"title":"לקנות חלב","date":null,"time":null,"minutes":null,'
      '"remind":null,"place":null}\n\n'
      'Note: ';
}

/// Tells when the first JSON object of an answer has closed, as the
/// answer arrives piece by piece.
class ObjectWatch {
  int _depth = 0;
  bool _inString = false;
  bool _escaped = false;
  bool _closed = false;

  /// Whether the object has closed by the end of [piece].
  bool closedBy(String piece) => closingPartOf(piece) != null;

  /// The part of [piece] up to and with the brace that closes the object,
  /// or null while the object is still open. A piece can carry more after
  /// that brace (the start of a second object, a note), which is not part
  /// of the answer. Empty once the object closed in an earlier piece.
  String? closingPartOf(String piece) {
    if (_closed) return '';
    final units = piece.codeUnits;
    for (var at = 0; at < units.length; at++) {
      final unit = units[at];
      if (_inString) {
        if (_escaped) {
          _escaped = false;
        } else if (unit == 0x5C) {
          _escaped = true;
        } else if (unit == 0x22) {
          _inString = false;
        }
        continue;
      }
      if (unit == 0x22) {
        // Quotes before the object opens are not its strings.
        if (_depth > 0) _inString = true;
      } else if (unit == 0x7B) {
        _depth++;
      } else if (unit == 0x7D && _depth > 0) {
        _depth--;
        if (_depth == 0) {
          _closed = true;
          return piece.substring(0, at + 1);
        }
      }
    }
    return null;
  }
}

/// The instructions and [request]'s text, cut to what the model can take.
/// [now] is the phone's clock; quick add reads "tomorrow" against it.
TaskPrompt buildTaskPrompt(AssistRequest request, {DateTime? now}) {
  final limit = switch (request.task) {
    AssistTask.quickAdd => quickAddLetters,
    final task when task.transforms => transformLetters,
    _ => readLetters,
  };
  final runes = request.text.trim().runes.toList();
  final truncated = runes.length > limit;
  final text = truncated
      ? String.fromCharCodes(runes.take(limit))
      : String.fromCharCodes(runes);

  // Hebrew takes about one token for every two or three letters, so half
  // the letters and a little more is room for an answer as long as the text.
  final own = switch (request.task) {
    AssistTask.summarize => 384,
    AssistTask.title => 48,
    AssistTask.ask => 512,
    // A line of JSON with a title of a dozen Hebrew words.
    AssistTask.quickAdd => 128,
    AssistTask.rewrite || AssistTask.proofread || AssistTask.translate =>
      (text.runes.length ~/ 2 + 64).clamp(128, taskAnswerTokens),
  };
  // An app's own question may ask for a longer answer than the default,
  // up to what a chat answer gets; the other jobs only for a shorter one.
  final most = request.task == AssistTask.ask ? 1024 : own;
  final asked = request.maxTokens;
  final maxTokens = asked == null ? own : asked.clamp(16, most);

  if (request.task == AssistTask.quickAdd) {
    // One line: a second "Note:" inside the text would read as a new
    // example.
    final line = text.replaceAll(RegExp(r'\s+'), ' ');
    return TaskPrompt(
      messages: [
        const AssistMessage.system(taskSystemPrompt),
        // The line comes last, so everything before it is the same for
        // every request of the day and the model reads it once.
        AssistMessage.user(
          '${quickAddInstruction(now ?? DateTime.now())}$line',
        ),
      ],
      maxTokens: maxTokens,
      truncated: truncated,
      stopAfterObject: true,
    );
  }

  return TaskPrompt(
    messages: [
      const AssistMessage.system(taskSystemPrompt),
      AssistMessage.user(
        '${taskInstruction(request, hebrew: mostlyHebrew(text))}\n\n$text',
      ),
    ],
    maxTokens: maxTokens,
    truncated: truncated,
  );
}
