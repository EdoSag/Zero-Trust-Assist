import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_assist/app/assist_settings.dart';
import 'package:zerotrust_assist/lab/model_store.dart';
import 'package:zerotrust_assist/models/assist_models.dart';
import 'package:zerotrust_assist/service/model_choice.dart';

import 'support/app.dart';

void main() {
  late Directory temp;
  late ModelChoiceFile choice;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('zt-assist-choice');
    // The folder is made on the first write, as on a new phone.
    choice = ModelChoiceFile.inDirectory('${temp.path}/models');
  });
  tearDown(() => temp.deleteSync(recursive: true));

  test('the pick is kept in a file and read back', () async {
    expect(await choice.read(), isNull);
    await choice.write(largeModelId);
    expect(await choice.read(), largeModelId);
    await choice.write(smallModelId);
    expect(await choice.read(), smallModelId);
    expect(choice.file.readAsStringSync(), smallModelId);
  });

  group('the model that answers other apps', () {
    test('is the picked one when it is on the phone', () async {
      await choice.write(largeModelId);
      final store = FixedModelStore({
        smallModelId: readySmall,
        largeModelId: readyLarge,
      });
      expect((await modelForOtherApps(store, choice))!.id, largeModelId);
    });

    test('without a pick on record, the small one if it is there', () async {
      final both = FixedModelStore({
        smallModelId: readySmall,
        largeModelId: readyLarge,
      });
      expect((await modelForOtherApps(both, choice))!.id, smallModelId);
      final onlyLarge = FixedModelStore({largeModelId: readyLarge});
      expect((await modelForOtherApps(onlyLarge, choice))!.id, largeModelId);
    });

    test('a picked model that was deleted gives way to the other', () async {
      await choice.write(largeModelId);
      final store = FixedModelStore({smallModelId: readySmall});
      expect((await modelForOtherApps(store, choice))!.id, smallModelId);
    });

    test('none on the phone, or one still downloading: none', () async {
      expect(await modelForOtherApps(FixedModelStore({}), choice), isNull);
      final downloading = FixedModelStore({
        smallModelId: const ModelState(ModelStage.downloading, fraction: 0.4),
      });
      expect(await modelForOtherApps(downloading, choice), isNull);
    });

    test('a pick this version does not know is ignored', () async {
      await choice.write('some-future-model');
      final store = FixedModelStore({smallModelId: readySmall});
      expect((await modelForOtherApps(store, choice))!.id, smallModelId);
    });
  });

  group('the app writes its pick where the other apps part reads it', () {
    ProviderContainer container(TestWorld world, {String? chosen}) {
      final made = ProviderContainer(
        overrides: [
          ...overridesFor(world, chosen: chosen),
          modelChoiceFileProvider.overrideWithValue(choice),
        ],
      );
      addTearDown(made.dispose);
      return made;
    }

    test('when a model is picked', () async {
      final c = container(TestWorld());
      await c.read(chosenModelProvider.notifier).choose(largeModelId);
      expect(await choice.read(), largeModelId);
    });

    test('and for a pick made before the file existed, on opening', () async {
      final c = container(TestWorld(), chosen: smallModelId);
      expect(await choice.read(), isNull);
      expect(await c.read(chosenModelProvider.future), smallModelId);
      expect(await choice.read(), smallModelId);
    });

    test('nothing is written before a model was ever picked', () async {
      final c = container(TestWorld(), chosen: null);
      expect(await c.read(chosenModelProvider.future), isNull);
      expect(choice.file.existsSync(), false);
    });
  });
}
