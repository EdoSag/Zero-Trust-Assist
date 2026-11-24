import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_assist/ui/text_direction.dart';

void main() {
  test('text is laid out by its first letter', () {
    expect(directionOf('Hello'), TextDirection.ltr);
    expect(directionOf('שלום'), TextDirection.rtl);
    expect(directionOf('- שלום world'), TextDirection.rtl);
    expect(directionOf('1. Hello שלום'), TextDirection.ltr);
    expect(directionOf('123'), TextDirection.ltr);
    expect(directionOf(''), TextDirection.ltr);
  });
}
