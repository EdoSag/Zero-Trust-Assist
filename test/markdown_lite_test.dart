import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_assist/ui/markdown_lite.dart';

void main() {
  test('reads bold, italic and code inside a line', () {
    final spans = parseInline('A **bold** word, an *italic* one and `code`.');
    expect(
      spans.map((s) => s.text).join(),
      'A bold word, an italic one and code.',
    );
    expect(spans.where((s) => s.bold).single.text, 'bold');
    expect(spans.where((s) => s.italic).single.text, 'italic');
    expect(spans.where((s) => s.code).single.text, 'code');
  });

  test('leaves stars and underscores that are not styling', () {
    for (final text in ['2 * 3 * 4 = 24', 'snake_case_name', 'a * b']) {
      final spans = parseInline(text);
      expect(spans.map((s) => s.text).join(), text);
      expect(spans.any((s) => s.bold || s.italic), false, reason: text);
    }
  });

  test('reads the lists the models write', () {
    final blocks = parseMarkdown(
      '*   **Timeline:** five weeks\n'
      '*   **Budget:** 92,000\n'
      '    - nested point\n'
      '1. First\n'
      '2) Second',
    );
    expect(blocks.map((b) => b.bullet), ['•', '•', '•', '1.', '2.']);
    expect(blocks[0].text, 'Timeline: five weeks');
    expect(blocks[0].spans.first.bold, true);
    expect(blocks[2].indent, 2);
    expect(blocks[4].text, 'Second');
  });

  test('reads headings, paragraphs and code', () {
    final blocks = parseMarkdown(
      '## Plan\n\nFirst line\nsame paragraph\n\n```dart\nfinal a = 1;\n```\nAfter',
    );
    expect(blocks[0].heading, true);
    expect(blocks[0].text, 'Plan');
    expect(blocks[1].text, 'First line same paragraph');
    expect(blocks[2].code, true);
    expect(blocks[2].text, 'final a = 1;');
    expect(blocks[3].text, 'After');
  });

  test('an answer cut in the middle still reads', () {
    final blocks = parseMarkdown('Here is **half a bo\n```\ncode with no end');
    expect(blocks[0].text, 'Here is **half a bo');
    expect(blocks[1].code, true);
    expect(blocks[1].text, 'code with no end');
    expect(parseMarkdown(''), isEmpty);
  });

  testWidgets('each block follows its own reading direction', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MarkdownLite('שלום עולם\n\nHello world\n\n* נקודה'),
        ),
      ),
    );
    Text text(String value) => tester.widget<Text>(
      find.byWidgetPredicate(
        (w) => w is Text && w.textSpan?.toPlainText() == value,
      ),
    );
    expect(text('שלום עולם').textDirection, TextDirection.rtl);
    expect(text('Hello world').textDirection, TextDirection.ltr);
    // The bullet of a Hebrew line sits to its right.
    final bullet = tester.getRect(find.text('•'));
    final line = tester.getRect(
      find.byWidgetPredicate(
        (w) => w is Text && w.textSpan?.toPlainText() == 'נקודה',
      ),
    );
    expect(bullet.left, greaterThanOrEqualTo(line.right));
  });
}
