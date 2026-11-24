import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_assist/app_info.dart';

void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();

  test('the version shown in the app is the one in pubspec.yaml', () {
    expect(
      pubspec,
      contains(RegExp('^version: $appVersion\\+', multiLine: true)),
    );
  });

  test('the engine version in results files is the pinned one', () {
    final parts = engineVersion.split(' ');
    expect(
      pubspec,
      contains(RegExp('^  ${parts[0]}: ${parts[1]}\$', multiLine: true)),
    );
  });
}
