import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_assist/lab/prompts.dart';

void main() {
  test('the full set is two speed requests and forty short ones', () {
    final speed = labPrompts.where((p) => p.category == LabCategory.speed);
    expect(speed.map((p) => p.language), ['en', 'he']);
    expect(labPrompts.length - speed.length, 40);
  });

  test('every kind of job has five requests', () {
    for (final category in LabCategory.values) {
      if (category == LabCategory.speed) continue;
      final count = labPrompts.where((p) => p.category == category).length;
      expect(count, 5, reason: category.label);
    }
  });

  test('ids are unique and languages are known', () {
    final ids = labPrompts.map((p) => p.id).toSet();
    expect(ids.length, labPrompts.length);
    for (final prompt in labPrompts) {
      expect(['he', 'en', 'mixed'], contains(prompt.language));
      expect(prompt.text.trim(), isNotEmpty);
    }
  });

  test('Hebrew is at least half of the short requests', () {
    final short = labPrompts.where((p) => p.category != LabCategory.speed);
    final hebrew = short.where((p) => p.language != 'en').length;
    expect(hebrew, greaterThanOrEqualTo(20));
  });

  test('every quick add request says what a correct answer is', () {
    final quickAdd = labPrompts.where(
      (p) => p.category == LabCategory.quickAdd,
    );
    for (final prompt in quickAdd) {
      expect(prompt.expectedDate, matches(r'^\d{4}-\d{2}-\d{2}$'));
      expect(prompt.expectedTime, matches(r'^(\d{2}:\d{2}|none)$'));
      expect(prompt.text, contains(labToday));
    }
    final others = labPrompts.where((p) => p.category != LabCategory.quickAdd);
    expect(others.every((p) => p.expectedDate == null), isTrue);
  });

  test('the quick set has both speed requests and every kind of job', () {
    final quick = labQuickPrompts;
    expect(quick.length, lessThan(15));
    for (final category in LabCategory.values) {
      expect(
        quick.any((p) => p.category == category),
        isTrue,
        reason: category.label,
      );
    }
    expect(quick.where((p) => p.category == LabCategory.speed).length, 2);
  });
}
