import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_assist/models/assist_models.dart';

const _gb = 1000 * 1000 * 1000;

void main() {
  test('the chat offers the small and the large Gemma, small first', () {
    expect(chatModels.map((m) => m.id), [smallModelId, largeModelId]);
    expect(smallModel.bytes, lessThan(largeModel.bytes));
    expect(chatModelById(largeModelId), largeModel);
    expect(chatModelById('dictalm-3-1.7b-gguf'), isNull);
    expect(chatModelById(null), isNull);
  });

  test('suggests the large model only with 12 GB of memory or more', () {
    // What phones sold as 8, 12 and 16 GB report.
    expect(recommendedModel((7.6 * _gb).round()).id, smallModelId);
    expect(recommendedModel((11.4 * _gb).round()).id, largeModelId);
    expect(recommendedModel(15517073408).id, largeModelId); // Pixel 10 Pro
    expect(recommendedModel(0).id, smallModelId); // unknown
  });

  test('warns below 8 GB, and not when the memory is unknown', () {
    expect(belowMinimumRam((5.6 * _gb).round()), true);
    expect(belowMinimumRam((7.6 * _gb).round()), false);
    expect(belowMinimumRam(0), false);
  });

  test('Hebrew and English have the same texts', () {
    Map<String, Object?> arb(String name) =>
        jsonDecode(File('lib/l10n/$name').readAsStringSync())
            as Map<String, Object?>;
    Set<String> keys(Map<String, Object?> file) => {
      for (final key in file.keys)
        if (!key.startsWith('@')) key,
    };
    final english = arb('app_en.arb');
    final hebrew = arb('app_he.arb');
    expect(keys(hebrew), keys(english));
    final hebrewLetter = RegExp('[֐-׿]');
    for (final key in keys(hebrew)) {
      if (key == 'appName') continue;
      expect(
        hebrewLetter.hasMatch(hebrew[key]! as String),
        true,
        reason: '$key is not translated',
      );
      // The same placeholders in both languages.
      final placeholders = RegExp(r'\{(\w+)\}');
      expect(
        placeholders
            .allMatches(hebrew[key]! as String)
            .map((m) => m.group(1))
            .toSet(),
        placeholders
            .allMatches(english[key]! as String)
            .map((m) => m.group(1))
            .toSet(),
        reason: key,
      );
    }
  });
}
