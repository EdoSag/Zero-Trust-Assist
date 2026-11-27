import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_assist/app/assist_config.dart';
import 'package:zerotrust_assist/lab/model_catalog.dart';
import 'package:zerotrust_assist/lab/ui/search_test_page.dart';

import 'fake_engine.dart';
import 'support/search_vectors.dart';

void main() {
  final model = labModels.firstWhere((m) => m.search);

  Future<void> pumpPage(WidgetTester tester, FakeEngine engine) async {
    // A small phone, so anything that does not fit shows up as an overflow.
    tester.view.physicalSize = const Size(720, 1440);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          // The suite's real theme, as inside the app: its full-width
          // buttons break layouts that a plain theme lets through.
          theme: ZtTheme.light(accent: assistAccent),
          home: SearchTestPage(
            model: model,
            modelPath: '/models/search.gguf',
            createEngine: () => engine,
          ),
        ),
      );
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
        if (find.text('Loading the model...').evaluate().isEmpty &&
            find.textContaining('Reading the notes').evaluate().isEmpty &&
            find.textContaining('Searching').evaluate().isEmpty) {
          break;
        }
      }
    });
    await tester.pump();
  }

  testWidgets('runs the searches and shows the report', (tester) async {
    final engine = FakeEngine(vector: searchVectors());
    await pumpPage(tester, engine);

    expect(find.textContaining('Model: ${model.title}'), findsOneWidget);
    expect(find.textContaining('Hebrew: 10 / 10 of 10'), findsOneWidget);
    expect(find.textContaining('good enough'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // The two buttons sit under the report, one above the other, each as
    // wide as the report and inside the screen.
    final report = tester.getRect(find.byType(Card));
    final share = tester.getRect(
      find.widgetWithText(FilledButton, 'Share report'),
    );
    final copy = tester.getRect(
      find.widgetWithText(OutlinedButton, 'Copy report'),
    );
    expect(share.top, greaterThan(report.bottom));
    expect(copy.top, greaterThan(share.bottom));
    for (final button in [share, copy]) {
      expect(button.left, greaterThanOrEqualTo(16));
      expect(button.right, lessThanOrEqualTo(360 - 16));
      expect(button.width, greaterThan(250));
      expect(button.height, greaterThan(30));
    }

    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.tap(find.text('Copy report'));
    await tester.pump();
    expect(copied, contains('All: 24 / 24 of 24'));
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a model that cannot search says so', (tester) async {
    await pumpPage(tester, FakeEngine());

    expect(find.text('The test did not run'), findsOneWidget);
    expect(find.textContaining('not a search model'), findsOneWidget);
    expect(find.text('Share report'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a file that does not load says so', (tester) async {
    await pumpPage(tester, FakeEngine(loadError: StateError('bad file')));

    expect(find.text('The test did not run'), findsOneWidget);
    expect(find.textContaining('bad file'), findsOneWidget);
  });

  testWidgets('leaving the page frees the model', (tester) async {
    final engine = FakeEngine(vector: searchVectors());
    await pumpPage(tester, engine);
    await tester.pumpWidget(const SizedBox());
    expect(engine.disposed, isTrue);
  });
}
