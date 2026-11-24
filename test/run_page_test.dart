import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_assist/engine/assist_engine.dart';
import 'package:zerotrust_assist/lab/model_catalog.dart';
import 'package:zerotrust_assist/lab/prompts.dart';
import 'package:zerotrust_assist/lab/result_store.dart';
import 'package:zerotrust_assist/ui/run_page.dart';

import 'fake_engine.dart';

void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('zt-assist-test'));
  tearDown(() => temp.deleteSync(recursive: true));

  testWidgets('runs the test, saves the file and shows the answers', (
    tester,
  ) async {
    // A phone-sized screen, so anything that does not fit shows up as an
    // overflow error.
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final store = ResultStore(Directory('${temp.path}/results'));
    final prompts = labQuickPrompts.take(3).toList();
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: RunPage(
            model: labModels.first,
            modelPath: '/models/test.litertlm',
            device: AssistDevice.cpu,
            prompts: prompts,
            results: store,
            createEngine: () => FakeEngine(
              answer: (messages) => const ['שלום', ' עולם'],
              perf: const AssistPerf(
                promptTokens: 400,
                promptMs: 1000,
                answerTokens: 50,
                answerMs: 2000,
              ),
            ),
          ),
        ),
      );
      // The run and the file write use real timers and real files.
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
        if (find.text('Share results file').evaluate().isNotEmpty) break;
      }
    });

    expect(find.text('Share results file'), findsOneWidget);
    expect(find.text('Copy summary'), findsOneWidget);
    expect(find.textContaining('writes 25 tok/s'), findsOneWidget);
    expect(find.text('Answers'), findsOneWidget);

    final saved = await tester.runAsync(store.list);
    expect(saved!.single.summary, contains('3 requests'));

    // Opening an answer shows the Hebrew text.
    await tester.tap(find.text('Speed (en)'));
    await tester.pumpAndSettle();
    expect(find.text('שלום עולם'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
