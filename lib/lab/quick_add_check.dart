import 'dart:convert';

import 'prompts.dart';

/// Whether a quick add answer got the date and time right.
class QuickAddCheck {
  const QuickAddCheck(this.passed, this.note);

  final bool passed;

  /// What was wrong, or what was found, in a few words.
  final String note;
}

/// Checks the answer to a quick add request: it must contain a JSON object
/// whose `date` and `time` match what the note says. Returns null for requests
/// that have no expected values.
///
/// Models often wrap JSON in a code fence or add a sentence around it, so the
/// first `{` to the last `}` is what gets parsed.
QuickAddCheck? checkQuickAdd(LabPrompt prompt, String answer) {
  final expectedDate = prompt.expectedDate;
  final expectedTime = prompt.expectedTime;
  if (expectedDate == null || expectedTime == null) return null;

  final start = answer.indexOf('{');
  final end = answer.lastIndexOf('}');
  if (start < 0 || end <= start) {
    return const QuickAddCheck(false, 'no JSON in the answer');
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(answer.substring(start, end + 1));
  } on FormatException {
    return const QuickAddCheck(false, 'the JSON does not parse');
  }
  if (decoded is! Map<String, Object?>) {
    return const QuickAddCheck(false, 'the JSON is not an object');
  }

  final date = decoded['date']?.toString().trim();
  final time = _normalizeTime(decoded['time']);
  final problems = <String>[
    if (date != expectedDate) 'date $date, expected $expectedDate',
    if (time != expectedTime) 'time $time, expected $expectedTime',
  ];
  if (problems.isNotEmpty) return QuickAddCheck(false, problems.join('; '));
  return QuickAddCheck(true, 'date $date, time $time');
}

/// `9:00` and `09:00:00` both mean `09:00`; a missing time is `none`.
/// Anything else (`09:00 PM`, `09:00:30`, `around 9`) is returned as written,
/// so it never matches an expected time by accident.
String _normalizeTime(Object? value) {
  if (value == null) return 'none';
  final text = value.toString().trim();
  if (text.isEmpty || text.toLowerCase() == 'null') return 'none';
  final match = RegExp(r'^(\d{1,2}):(\d{2})(?::00)?$').firstMatch(text);
  if (match == null) return text;
  return '${match.group(1)!.padLeft(2, '0')}:${match.group(2)}';
}
