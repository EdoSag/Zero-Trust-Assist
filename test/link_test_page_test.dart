import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_assist/app/assist_config.dart';
import 'package:zerotrust_assist/lab/prompts.dart';
import 'package:zerotrust_assist/lab/ui/link_test_page.dart';
import 'package:zt_assist/testing.dart';
import 'package:zt_assist/zt_assist.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester,
    FakeZtAssist assist, {
    VoidCallback? onActivity,
  }) async {
    // A small phone, so anything that does not fit shows up as an overflow.
    tester.view.physicalSize = const Size(720, 1440);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        // The suite's real theme, as inside the app: its full-width buttons
        // break layouts that a plain theme lets through.
        theme: ZtTheme.light(accent: assistAccent),
        home: LinkTestPage(assist: assist, onActivity: onActivity),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapAsk(WidgetTester tester) async {
    // The list builds its rows as they come near the screen.
    final ask = find.byKey(const Key('link-ask'));
    await tester.scrollUntilVisible(ask, 200);
    await tester.ensureVisible(ask);
    await tester.pump();
    await tester.tap(ask);
    await tester.pump();
  }

  test('the samples carry the notes without the phone test\'s request', () {
    expect(labEnglishNote, startsWith('Project kickoff notes'));
    expect(labEnglishNote, isNot(contains('Summarize these notes')));
    expect(labEnglishNote, endsWith('by next Sunday.'));
    expect(labHebrewNote, startsWith('סיכום פגישת תכנון'));
    expect(labHebrewNote, isNot(contains('סכם את הפתק')));
    expect(linkSamples.map((s) => s.request.task), [
      ZtAssistTask.summarize,
      ZtAssistTask.summarize,
      ZtAssistTask.proofread,
      ZtAssistTask.rewrite,
      ZtAssistTask.quickAdd,
      ZtAssistTask.quickAdd,
      ZtAssistTask.quickAdd,
    ]);
  });

  testWidgets('quick add shows what stood up to the checks', (tester) async {
    final assist = FakeZtAssist(
      answer: (_) => [
        '{"title":"רופא שיניים","date":"2020-01-01",',
        '"time":"09:00","minutes":null,"remind":60,"place":"מרפאה"}',
      ],
      done: const ZtAssistDone(tokens: 40),
    );
    await pumpPage(tester, assist);

    final choice = find.text('Quick add, Hebrew');
    await tester.scrollUntilVisible(choice, 200);
    await tester.ensureVisible(choice);
    await tester.pump();
    await tester.tap(choice);
    await tester.pump();
    await tapAsk(tester);
    await tester.pumpAndSettle();

    expect(assist.requests.single.task, ZtAssistTask.quickAdd);
    final report = tester.widget<SelectableText>(
      find.byKey(const Key('link-report')),
    );
    // The past day and the place the line does not name are dropped.
    expect(
      report.data,
      contains(
        'Read as: title "רופא שיניים", day -, time 09:00, length -, '
        'remind 60, place -.',
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick add says when the answer was not usable', (tester) async {
    final assist = FakeZtAssist(answer: (_) => ['I could not read that.']);
    await pumpPage(tester, assist);

    final choice = find.text('Quick add, English');
    await tester.scrollUntilVisible(choice, 200);
    await tester.ensureVisible(choice);
    await tester.pump();
    await tester.tap(choice);
    await tester.pump();
    await tapAsk(tester);
    await tester.pumpAndSettle();

    final report = tester.widget<SelectableText>(
      find.byKey(const Key('link-report')),
    );
    expect(report.data, contains('Read as: nothing'));
  });

  testWidgets('says it is ready, asks, and shows the answer and the speed', (
    tester,
  ) async {
    var touched = 0;
    final assist = FakeZtAssist(
      answer: (_) => ['The kitchen', ' starts in January.'],
      done: const ZtAssistDone(
        tokens: 34,
        duration: Duration(milliseconds: 3000),
        timeToFirstPiece: Duration(milliseconds: 1000),
        truncated: true,
      ),
    );
    await pumpPage(tester, assist, onActivity: () => touched++);

    expect(find.text('Ready to answer other apps'), findsOneWidget);
    // The Ask button is full width, below the choices. The list builds its
    // rows as they come near the screen.
    await tester.scrollUntilVisible(find.byKey(const Key('link-ask')), 200);
    await tester.pump();
    final ask = tester.getRect(find.byKey(const Key('link-ask')));
    final lastChoice = tester.getRect(find.text(linkSamples.last.label));
    expect(ask.top, greaterThan(lastChoice.bottom));
    expect(ask.width, greaterThan(250));

    await tapAsk(tester);
    await tester.pumpAndSettle();

    expect(assist.requests.single, same(linkSamples.first.request));
    expect(find.text('The kitchen starts in January.'), findsOneWidget);
    final report = tester.widget<SelectableText>(
      find.byKey(const Key('link-report')),
    );
    expect(report.data, contains('34 tokens'));
    expect(report.data, contains('read for 1.0 s and wrote for 2.0 s'));
    expect(report.data, contains('17.0 tokens a second'));
    expect(report.data, contains('only its beginning was read'));
    expect(touched, greaterThan(0));
    // Ready for the next request.
    expect(find.byKey(const Key('link-ask')), findsOneWidget);
    expect(find.byKey(const Key('link-stop')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('another request can be picked', (tester) async {
    final assist = FakeZtAssist();
    await pumpPage(tester, assist);

    await tester.tap(find.text('Proofread, Hebrew'));
    await tester.pump();
    await tapAsk(tester);
    await tester.pumpAndSettle();

    expect(assist.requests.single.task, ZtAssistTask.proofread);
  });

  testWidgets('Stop ends the answer and keeps what was written', (
    tester,
  ) async {
    final gates = [Completer<void>(), Completer<void>()];
    var piece = 0;
    final assist = FakeZtAssist(
      answer: (_) => ['First', ' second'],
      beforePiece: () => gates[piece++].future,
    );
    await pumpPage(tester, assist);

    await tapAsk(tester);
    expect(
      find.text('Loading the model and reading the text...'),
      findsOneWidget,
    );
    gates[0].complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('First'), findsOneWidget);

    final stop = find.byKey(const Key('link-stop'));
    await tester.ensureVisible(stop);
    await tester.tap(stop);
    await tester.pump();
    gates[1].complete();
    await tester.pumpAndSettle();

    expect(assist.cancelled, 1);
    expect(find.text('First'), findsOneWidget);
    expect(find.text('Stopped.'), findsOneWidget);
    expect(find.byKey(const Key('link-ask')), findsOneWidget);
  });

  testWidgets('a failure is said in words', (tester) async {
    final assist = FakeZtAssist(
      state: ZtAssistAvailability.needsModel,
      answer: (_) => const [],
      error: ZtAssistError.noModel,
    );
    await pumpPage(tester, assist);
    expect(find.text('No model on this phone'), findsOneWidget);

    await tapAsk(tester);
    await tester.pumpAndSettle();

    expect(
      find.text('No model is on this phone. Download one first.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('link-report')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving the page frees the model', (tester) async {
    final assist = FakeZtAssist();
    await pumpPage(tester, assist);
    expect(assist.released, 0);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();

    expect(assist.released, 1);
  });
}
