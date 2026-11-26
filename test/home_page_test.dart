import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_assist/lab/model_catalog.dart';
import 'package:zerotrust_assist/lab/model_store.dart';
import 'package:zerotrust_assist/lab/prompts.dart';
import 'package:zerotrust_assist/lab/result_store.dart';
import 'package:zerotrust_assist/ui/home_page.dart';

/// A store with fixed states, so the page can be shown without downloads.
class _FixedStore extends ModelStore {
  _FixedStore(super.directory, this.states);

  final Map<String, ModelState> states;

  @override
  Future<void> refresh() async {}

  @override
  ModelState stateOf(LabModel model) =>
      states[model.id] ?? const ModelState(ModelStage.missing);
}

void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('zt-assist-test'));
  tearDown(() => temp.deleteSync(recursive: true));

  Future<void> pumpHome(WidgetTester tester, ModelStore store) async {
    // A small phone, so anything that does not fit shows up as an overflow.
    tester.view.physicalSize = const Size(720, 1440);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomePage(
            models: store,
            results: ResultStore(Directory('${temp.path}/results')),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
  }

  testWidgets('lists every model in each of its states', (tester) async {
    final store = _FixedStore(temp.path, {
      labModels[0].id: const ModelState(ModelStage.ready, path: '/m/a'),
      labModels[1].id: const ModelState(
        ModelStage.downloading,
        fraction: 0.4,
        receivedBytes: 1463812096,
      ),
      labModels[2].id: const ModelState(
        ModelStage.failed,
        error: 'No connection.',
      ),
    });
    await pumpHome(tester, store);

    for (final model in labModels) {
      await tester.scrollUntilVisible(find.text(model.title), 200);
      expect(find.text(model.title), findsOneWidget);
    }
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(find.text('Run test'), -200);
    expect(find.text('Chat'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Pause'), 200);
    expect(find.text('1.5 GB of 3.7 GB'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Try again'), 200);
    expect(find.text('No connection.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Download'), 200);
    await tester.scrollUntilVisible(
      find.text('No runs yet. Download a model and tap Run test.'),
      200,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Run test asks how long and on which chip', (tester) async {
    final store = _FixedStore(temp.path, {
      labModels[0].id: const ModelState(ModelStage.ready, path: '/m/a'),
    });
    await pumpHome(tester, store);

    await tester.scrollUntilVisible(find.text('Run test'), 200);
    await tester.tap(find.text('Run test'));
    await tester.pumpAndSettle();

    for (final label in [
      'Speed',
      'Quick',
      'Full',
      'Auto',
      '2',
      '4',
      '6',
      '8',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(
      find.textContaining('Quick: ${labQuickPrompts.length} requests'),
      findsOneWidget,
    );
    expect(find.text('CPU'), findsOneWidget);
    expect(find.text('GPU'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a download needs a yes, and shows the size and source', (
    tester,
  ) async {
    await pumpHome(tester, _FixedStore(temp.path, const {}));

    await tester.scrollUntilVisible(find.text('Download').first, 200);
    await tester.tap(find.text('Download').first);
    await tester.pumpAndSettle();

    expect(find.text('Download ${labModels.first.title}?'), findsOneWidget);
    expect(
      find.textContaining('huggingface.co/${labModels.first.repoId}'),
      findsOneWidget,
    );
    expect(find.textContaining('2.6 GB'), findsWidgets);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
