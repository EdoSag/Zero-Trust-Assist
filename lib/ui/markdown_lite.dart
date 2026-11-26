import 'package:flutter/material.dart';

import 'text_direction.dart';

/// One block of an answer: a paragraph, a heading, a list line or code.
class MarkdownBlock {
  const MarkdownBlock(
    this.spans, {
    this.heading = false,
    this.bullet,
    this.indent = 0,
    this.code = false,
  });

  /// The text, cut where the style changes.
  final List<MarkdownSpan> spans;
  final bool heading;

  /// What stands before a list line: "•" or its number ("2."). Null for
  /// other blocks.
  final String? bullet;

  /// How deep a list line is nested, from 0.
  final int indent;

  /// A block of code, shown as written.
  final bool code;

  String get text => spans.map((span) => span.text).join();
}

class MarkdownSpan {
  const MarkdownSpan(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.code = false,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool code;
}

final RegExp _heading = RegExp(r'^\s{0,3}#{1,6}\s+(.*?)\s*#*\s*$');
final RegExp _bullet = RegExp(r'^(\s*)[*\-+•]\s+(.*)$');
final RegExp _numbered = RegExp(r'^(\s*)(\d{1,3})[.)]\s+(.*)$');
final RegExp _fence = RegExp(r'^\s*```');
final RegExp _inline = RegExp(
  r'(\*\*|__)(?=\S)(.+?)(?<=\S)\1' // bold
  r'|(?<![\w*])\*(?=\S)([^*\n]+?)(?<=\S)\*(?![\w*])' // italic
  r'|`([^`\n]+)`', // code
);

/// Splits the model's answer into blocks.
///
/// The models write a small part of Markdown: bold, lists, headings and
/// code. This reads that part and shows anything else as written, so no
/// stray symbol can break an answer. A half-written answer (still being
/// typed) is read the same way.
List<MarkdownBlock> parseMarkdown(String source) {
  final blocks = <MarkdownBlock>[];
  final paragraph = <String>[];
  final code = <String>[];
  var inCode = false;

  void endParagraph() {
    if (paragraph.isEmpty) return;
    blocks.add(MarkdownBlock(parseInline(paragraph.join(' '))));
    paragraph.clear();
  }

  for (final line in source.replaceAll('\r\n', '\n').split('\n')) {
    if (_fence.hasMatch(line)) {
      if (inCode) {
        blocks.add(MarkdownBlock([MarkdownSpan(code.join('\n'))], code: true));
        code.clear();
      } else {
        endParagraph();
      }
      inCode = !inCode;
      continue;
    }
    if (inCode) {
      code.add(line);
      continue;
    }
    if (line.trim().isEmpty) {
      endParagraph();
      continue;
    }
    final heading = _heading.firstMatch(line);
    if (heading != null) {
      endParagraph();
      blocks.add(MarkdownBlock(parseInline(heading.group(1)!), heading: true));
      continue;
    }
    final bullet = _bullet.firstMatch(line);
    if (bullet != null) {
      endParagraph();
      blocks.add(
        MarkdownBlock(
          parseInline(bullet.group(2)!),
          bullet: '•',
          indent: bullet.group(1)!.length ~/ 2,
        ),
      );
      continue;
    }
    final numbered = _numbered.firstMatch(line);
    if (numbered != null) {
      endParagraph();
      blocks.add(
        MarkdownBlock(
          parseInline(numbered.group(3)!),
          bullet: '${numbered.group(2)}.',
          indent: numbered.group(1)!.length ~/ 2,
        ),
      );
      continue;
    }
    paragraph.add(line.trim());
  }
  endParagraph();
  // Code still being written when the answer was cut.
  if (code.isNotEmpty) {
    blocks.add(MarkdownBlock([MarkdownSpan(code.join('\n'))], code: true));
  }
  return blocks;
}

/// Splits one line where bold, italic or code starts and ends.
List<MarkdownSpan> parseInline(String text) {
  final spans = <MarkdownSpan>[];
  var from = 0;
  for (final match in _inline.allMatches(text)) {
    if (match.start > from) {
      spans.add(MarkdownSpan(text.substring(from, match.start)));
    }
    if (match.group(2) != null) {
      spans.add(MarkdownSpan(match.group(2)!, bold: true));
    } else if (match.group(3) != null) {
      spans.add(MarkdownSpan(match.group(3)!, italic: true));
    } else {
      spans.add(MarkdownSpan(match.group(4)!, code: true));
    }
    from = match.end;
  }
  if (from < text.length) spans.add(MarkdownSpan(text.substring(from)));
  return spans;
}

/// An answer with its bold text, lists, headings and code shown as such.
/// Each block is laid out in its own reading direction, so a Hebrew answer
/// with an English line in it reads correctly.
class MarkdownLite extends StatelessWidget {
  const MarkdownLite(this.source, {super.key, this.style});

  final String source;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = style ?? theme.textTheme.bodyLarge ?? const TextStyle();
    final mono = base.copyWith(
      fontFamily: 'monospace',
      fontSize: (base.fontSize ?? 16) * 0.9,
    );
    final blocks = parseMarkdown(source);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < blocks.length; index++)
          Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : 6),
            child: _block(context, blocks[index], base, mono),
          ),
      ],
    );
  }

  Widget _block(
    BuildContext context,
    MarkdownBlock block,
    TextStyle base,
    TextStyle mono,
  ) {
    final theme = Theme.of(context);
    if (block.code) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        // Code reads left to right in every language.
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Text(
            block.text,
            style: mono,
            textDirection: TextDirection.ltr,
          ),
        ),
      );
    }
    final direction = directionOf(block.text);
    final text = Text.rich(
      TextSpan(
        children: [
          for (final span in block.spans)
            TextSpan(
              text: span.text,
              style: span.code
                  ? mono
                  : TextStyle(
                      fontWeight: span.bold || block.heading
                          ? FontWeight.w700
                          : null,
                      fontStyle: span.italic ? FontStyle.italic : null,
                    ),
            ),
        ],
      ),
      style: base,
      textDirection: direction,
      textAlign: TextAlign.start,
    );
    final bullet = block.bullet;
    if (bullet == null) return text;
    return Directionality(
      textDirection: direction,
      child: Padding(
        padding: EdgeInsetsDirectional.only(start: 12.0 * block.indent),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: bullet.length > 1 ? 28 : 18,
              child: Text(bullet, style: base),
            ),
            Expanded(child: text),
          ],
        ),
      ),
    );
  }
}
