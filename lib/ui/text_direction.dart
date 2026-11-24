import 'package:flutter/material.dart';

/// Right-to-left when the first letter of [text] is Hebrew or Arabic, so a
/// Hebrew answer is laid out correctly in an English screen.
TextDirection directionOf(String text) {
  for (final rune in text.runes) {
    if (rune >= 0x0590 && rune <= 0x08FF) return TextDirection.rtl;
    final isLatin =
        (rune >= 0x41 && rune <= 0x5A) || (rune >= 0x61 && rune <= 0x7A);
    if (isLatin) return TextDirection.ltr;
  }
  return TextDirection.ltr;
}

/// Text laid out in its own reading direction, selectable for copying.
class AutoDirectionText extends StatelessWidget {
  const AutoDirectionText(this.text, {super.key, this.style, this.fill = true});

  final String text;
  final TextStyle? style;

  /// Whether the text takes the full width, so right-to-left text starts at
  /// the right edge. A chat bubble passes false and hugs its text instead.
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final direction = directionOf(text);
    final selectable = SelectableText(
      text,
      style: style,
      textDirection: direction,
      textAlign: TextAlign.start,
    );
    return fill
        ? SizedBox(width: double.infinity, child: selectable)
        : selectable;
  }
}
