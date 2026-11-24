import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_assist/lab/prompts.dart';
import 'package:zerotrust_assist/lab/quick_add_check.dart';

const _timed = LabPrompt(
  id: 'timed',
  category: LabCategory.quickAdd,
  language: 'he',
  text: 'x',
  expectedDate: '2026-11-25',
  expectedTime: '09:00',
);

const _untimed = LabPrompt(
  id: 'untimed',
  category: LabCategory.quickAdd,
  language: 'he',
  text: 'x',
  expectedDate: '2026-11-27',
  expectedTime: 'none',
);

void main() {
  test('a correct answer passes', () {
    final check = checkQuickAdd(
      _timed,
      '{"type":"event","title":"רופא שיניים","date":"2026-11-25",'
      '"time":"09:00","reminder_minutes_before":60}',
    );
    expect(check!.passed, isTrue);
  });

  test('a code fence and extra words around the JSON are accepted', () {
    final check = checkQuickAdd(
      _timed,
      'Here you go:\n```json\n{"date": "2026-11-25", "time": "9:00"}\n```',
    );
    expect(check!.passed, isTrue);
  });

  test('seconds in the time are ignored', () {
    final check = checkQuickAdd(
      _timed,
      '{"date":"2026-11-25","time":"09:00:00"}',
    );
    expect(check!.passed, isTrue);
  });

  test('a time with anything after it is not the expected time', () {
    for (final time in ['09:00 PM', '09:00:30', '09:00 or so', '09:000']) {
      final check = checkQuickAdd(
        _timed,
        '{"date":"2026-11-25","time":"$time"}',
      );
      expect(check!.passed, isFalse, reason: time);
      expect(check.note, contains('time $time, expected 09:00'));
    }
  });

  test('a wrong date fails and says why', () {
    final check = checkQuickAdd(_timed, '{"date":"2026-11-24","time":"09:00"}');
    expect(check!.passed, isFalse);
    expect(check.note, contains('expected 2026-11-25'));
  });

  test('a note without a time expects null', () {
    expect(
      checkQuickAdd(_untimed, '{"date":"2026-11-27","time":null}')!.passed,
      isTrue,
    );
    expect(
      checkQuickAdd(_untimed, '{"date":"2026-11-27","time":"null"}')!.passed,
      isTrue,
    );
    expect(
      checkQuickAdd(_untimed, '{"date":"2026-11-27","time":"12:00"}')!.passed,
      isFalse,
    );
  });

  test('an answer without JSON, or with broken JSON, fails', () {
    expect(checkQuickAdd(_timed, 'Tomorrow at nine.')!.passed, isFalse);
    expect(checkQuickAdd(_timed, '{"date": 2026-11-25')!.passed, isFalse);
    expect(checkQuickAdd(_timed, '{"date": }')!.passed, isFalse);
  });

  test('requests of other kinds are not checked', () {
    const other = LabPrompt(
      id: 'other',
      category: LabCategory.summarize,
      language: 'en',
      text: 'x',
    );
    expect(checkQuickAdd(other, '{}'), isNull);
  });
}
