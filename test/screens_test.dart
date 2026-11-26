import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_assist/app/assist_settings.dart';
import 'package:zerotrust_assist/chat/assistant.dart';
import 'package:zerotrust_assist/chat/conversation.dart';
import 'package:zerotrust_assist/lab/model_store.dart';
import 'package:zerotrust_assist/models/assist_models.dart';
import 'package:zerotrust_assist/ui/assist_home.dart';
import 'package:zerotrust_assist/ui/chat_home_page.dart';
import 'package:zerotrust_assist/ui/model_setup_page.dart';
import 'package:zerotrust_assist/ui/models_page.dart';
import 'package:zerotrust_assist/ui/settings_page.dart';

import 'fake_engine.dart';
import 'support/app.dart';

const _gb = 1000 * 1000 * 1000;

Conversation _chat(String id, String text, DateTime at) => Conversation.start(
  id,
  at,
).withMessage(ChatMessage(role: ChatRole.user, text: text, at: at));

/// [text] among the messages, not in the title bar (which repeats the first
/// message as the chat's name).
Finder _inMessages(Finder text) =>
    find.descendant(of: find.byType(ListView), matching: text);

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());

  group('first launch', () {
    testWidgets('offers both models and suggests the large one on a 16 GB '
        'phone', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        app(const AssistHome(), world, chosen: null, states: {}),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ModelSetupPage), findsOneWidget);
      expect(find.text('Choose your model'), findsOneWidget);
      expect(find.text('Small model'), findsOneWidget);
      expect(find.text('Large model'), findsOneWidget);
      expect(find.text('Gemma 4 E2B, 2.6 GB'), findsOneWidget);
      expect(find.text('Gemma 4 E4B, 3.7 GB'), findsOneWidget);
      // The mark sits in the large model's card, not the small one's.
      expect(
        find.descendant(
          of: find.byKey(const Key('model-$largeModelId')),
          matching: find.text('Suits this phone'),
        ),
        findsOneWidget,
      );
      expect(find.text('Suits this phone'), findsOneWidget);
      expect(find.byKey(const Key('setup-low-memory')), findsNothing);
      // Nothing is on the phone yet, so there is nothing to start with.
      final start = tester.widget<FilledButton>(
        find.byKey(const Key('setup-continue')),
      );
      expect(start.onPressed, isNull);
      // The button is on screen and as wide as the page allows.
      final rect = tester.getRect(find.byKey(const Key('setup-continue')));
      expect(rect.width, greaterThan(300));
      expect(rect.bottom, lessThanOrEqualTo(740));
      expect(tester.takeException(), isNull);
    });

    testWidgets('suggests the small model on an 8 GB phone and warns below '
        'that', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        app(
          const AssistHome(),
          world,
          chosen: null,
          states: {},
          device: FakeDeviceInfo(ramBytes: (7.6 * _gb).round()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('model-$smallModelId')),
          matching: find.text('Suits this phone'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('setup-low-memory')), findsNothing);

      world = TestWorld();
      await tester.pumpWidget(
        app(
          const AssistHome(),
          world,
          chosen: null,
          states: {},
          device: FakeDeviceInfo(ramBytes: (5.6 * _gb).round()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('setup-low-memory')), findsOneWidget);
      expect(find.textContaining('5.6 GB of memory'), findsOneWidget);
    });

    testWidgets('downloads the picked model and opens the chat when it is '
        'ready', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        app(const AssistHome(), world, chosen: null, states: {}),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('model-download-$smallModelId')));
      await tester.pump();
      expect(world.store.downloads, [smallModelId]);
      expect(
        find.byKey(const Key('model-cancel-$smallModelId')),
        findsOneWidget,
      );

      world.store.set(
        smallModel,
        const ModelState(
          ModelStage.downloading,
          fraction: 0.5,
          receivedBytes: 1294073856,
        ),
      );
      await tester.pump();
      expect(find.text('Downloading: 1.3 of 2.6 GB'), findsOneWidget);
      expect(tester.takeException(), isNull);

      world.store.set(smallModel, readySmall);
      await tester.pumpAndSettle();
      expect(find.byType(ChatHomePage), findsOneWidget);
      expect(world.prefs.values['assist_model'], smallModelId);
    });

    testWidgets('a model already on the phone can be used right away', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(
        app(
          const AssistHome(),
          world,
          chosen: null,
          states: {smallModelId: readySmall, largeModelId: readyLarge},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('On this phone'), findsNWidgets(2));

      // The large one is suggested on this phone; take the small one.
      await tester.tap(find.text('Small model'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('setup-continue')));
      await tester.pumpAndSettle();
      expect(find.byType(ChatHomePage), findsOneWidget);
      expect(world.prefs.values['assist_model'], smallModelId);
    });

    testWidgets('says when the phone has no room for a model', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        app(
          const AssistHome(),
          world,
          chosen: null,
          states: {},
          device: FakeDeviceInfo(freeBytes: 3 * _gb),
        ),
      );
      await tester.pumpAndSettle();
      // 3 GB free: room for the small model (2.6), not the large (3.7).
      expect(find.textContaining('only 3.0 GB is free'), findsOneWidget);
      final large = tester.widget<TextButton>(
        find.byKey(const Key('model-download-$largeModelId')),
      );
      final small = tester.widget<TextButton>(
        find.byKey(const Key('model-download-$smallModelId')),
      );
      expect(large.onPressed, isNull);
      expect(small.onPressed, isNotNull);
    });

    testWidgets('a deleted model brings the choice back', (tester) async {
      phone(tester);
      await tester.pumpWidget(app(const AssistHome(), world));
      await tester.pumpAndSettle();
      expect(find.byType(ChatHomePage), findsOneWidget);

      world.store.set(smallModel, const ModelState(ModelStage.missing));
      await tester.pumpAndSettle();
      expect(find.byType(ModelSetupPage), findsOneWidget);
    });
  });

  group('chat', () {
    testWidgets('a message and its answer show as bubbles on their sides', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(app(const ChatHomePage(), world));
      await tester.pumpAndSettle();

      expect(find.text('How can I help?'), findsOneWidget);
      // Nothing to send yet.
      expect(
        tester.widget<IconButton>(find.byKey(const Key('chat-send'))).onPressed,
        isNull,
      );

      await tester.enterText(
        find.byKey(const Key('chat-input')),
        'What is the capital of France?',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pumpAndSettle();

      expect(find.text('How can I help?'), findsNothing);
      // Once in the title bar, once as the message.
      expect(find.text('What is the capital of France?'), findsNWidgets(2));
      final question = tester.getRect(
        _inMessages(find.text('What is the capital of France?')),
      );
      final answer = tester.getRect(find.text('Hello there'));
      // English: the question at the right, the answer at the left, the
      // answer below the question, both inside the screen.
      expect(question.right, greaterThan(300));
      expect(answer.left, lessThan(40));
      expect(answer.top, greaterThan(question.bottom));
      expect(question.left, greaterThanOrEqualTo(0));
      expect(answer.right, lessThanOrEqualTo(360));
      // The box is empty again and the answer can be copied.
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('chat-input')))
            .controller!
            .text,
        '',
      );
      expect(find.byTooltip('Copy'), findsOneWidget);
      expect(world.repository.conversations.single.messages, hasLength(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the answer while it is written, with Stop', (
      tester,
    ) async {
      phone(tester);
      final gates = [Completer<void>(), Completer<void>(), Completer<void>()];
      var piece = 0;
      await tester.pumpWidget(
        app(
          const ChatHomePage(),
          world,
          engine: () => FakeEngine(
            answer: (_) => const ['The capital', ' is Paris', '.'],
            beforePiece: () => gates[piece++].future,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('chat-input')), 'Capital?');
      await tester.pump();
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pump();
      await tester.pump();

      // Waiting for the first words.
      expect(find.byKey(const Key('chat-waiting')), findsOneWidget);
      expect(find.byKey(const Key('chat-stop')), findsOneWidget);
      expect(find.byKey(const Key('chat-send')), findsNothing);

      gates[0].complete();
      await tester.pump();
      await tester.pump();
      expect(find.text('The capital'), findsOneWidget);
      gates[1].complete();
      await tester.pump();
      await tester.pump();
      expect(find.text('The capital is Paris'), findsOneWidget);

      await tester.tap(find.byKey(const Key('chat-stop')));
      gates[2].complete();
      await tester.pumpAndSettle();
      expect(find.text('The capital is Paris'), findsOneWidget);
      expect(find.text('Stopped before the end'), findsOneWidget);
      expect(find.byKey(const Key('chat-send')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a missing model is explained, with the way to fix it', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(app(const ChatHomePage(), world, states: {}));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('chat-input')), 'Hi');
      await tester.pump();
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('chat-problem')), findsOneWidget);
      expect(find.textContaining('not on this phone'), findsOneWidget);
      final bar = tester.getRect(find.byKey(const Key('chat-problem')));
      expect(bar.left, greaterThanOrEqualTo(0));
      expect(bar.right, lessThanOrEqualTo(360));
      await tester.tap(find.byKey(const Key('problem-models')));
      await tester.pumpAndSettle();
      expect(find.byType(ModelsPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failed load says why', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        app(
          const ChatHomePage(),
          world,
          engine: () => FakeEngine(loadError: StateError('out of memory')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('chat-input')), 'Hi');
      await tester.pump();
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pumpAndSettle();
      expect(find.textContaining('could not be loaded'), findsOneWidget);
      expect(find.textContaining('out of memory'), findsOneWidget);
      // The question is still there to send again.
      expect(find.text('Hi'), findsNWidgets(2));

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-problem')), findsNothing);
    });

    testWidgets('the side panel lists the chats, newest first, and opens '
        'one', (tester) async {
      phone(tester);
      final now = DateTime.now();
      await tester.pumpWidget(
        app(
          const ChatHomePage(),
          world,
          conversations: [
            _chat('old', 'Trip to Rome', now.subtract(const Duration(days: 3))),
            _chat(
              'new',
              'Dinner ideas',
              now.subtract(const Duration(hours: 1)),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();

      final newer = tester.getRect(find.text('Dinner ideas'));
      final older = tester.getRect(find.text('Trip to Rome'));
      expect(newer.top, lessThan(older.top));
      expect(find.text('New chat'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      // The settings row is at the bottom, on screen.
      expect(tester.getRect(find.text('Settings')).bottom, lessThan(740));

      await tester.tap(find.text('Trip to Rome'));
      await tester.pumpAndSettle();
      // The panel closed and the chat is open: title bar and message.
      expect(find.text('Dinner ideas'), findsNothing);
      expect(find.text('Trip to Rome'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('renames and deletes a chat from the side panel', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(
        app(
          const ChatHomePage(),
          world,
          conversations: [_chat('c1', 'Trip to Rome', DateTime.now())],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('chat-menu-c1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('rename-field')), 'Italy');
      await tester.tap(find.byKey(const Key('rename-save')));
      await tester.pumpAndSettle();
      expect(world.repository.conversations.single.title, 'Italy');
      expect(find.text('Italy'), findsOneWidget);

      await tester.tap(find.byKey(const Key('chat-menu-c1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this chat?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('delete-confirm')));
      await tester.pumpAndSettle();
      expect(world.repository.conversations, isEmpty);
      expect(find.textContaining('Your chats will show here'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('New chat clears the screen', (tester) async {
      phone(tester);
      await tester.pumpWidget(app(const ChatHomePage(), world));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('chat-input')), 'Hi');
      await tester.pump();
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chat-new')));
      await tester.pumpAndSettle();
      expect(find.text('How can I help?'), findsOneWidget);
      expect(find.text('Hello there'), findsNothing);
      expect(world.repository.conversations, hasLength(1));
    });
  });

  group('Hebrew', () {
    testWidgets('the chat is mirrored and in Hebrew', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        app(
          const ChatHomePage(),
          world,
          locale: ZtLanguages.hebrew,
          engine: () => FakeEngine(answer: (_) => const ['פריז', ' היא הבירה']),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        Directionality.of(tester.element(find.byType(ChatHomePage))),
        TextDirection.rtl,
      );
      expect(find.text('במה אפשר לעזור?'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('chat-input')), 'מה הבירה?');
      await tester.pump();
      // The send button is at the left of the box in Hebrew.
      final send = tester.getRect(find.byKey(const Key('chat-send')));
      final box = tester.getRect(find.byKey(const Key('chat-input')));
      expect(send.right, lessThanOrEqualTo(box.left));
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pumpAndSettle();

      final question = tester.getRect(_inMessages(find.text('מה הבירה?')));
      final answer = tester.getRect(find.text('פריז היא הבירה'));
      // Mirrored: the question at the left, the answer at the right.
      expect(question.left, lessThan(60));
      expect(answer.right, greaterThan(300));
      expect(answer.top, greaterThan(question.bottom));
      expect(find.byTooltip('העתקה'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the model choice is in Hebrew and fits', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        app(
          const AssistHome(),
          world,
          locale: ZtLanguages.hebrew,
          chosen: null,
          states: {},
          device: FakeDeviceInfo(ramBytes: (5.6 * _gb).round()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('בחירת מודל'), findsOneWidget);
      expect(find.text('מודל קטן'), findsOneWidget);
      expect(find.text('מודל גדול'), findsOneWidget);
      expect(find.text('Gemma 4 E2B, 2.6 ג״ב'), findsOneWidget);
      expect(find.text('להתחיל לשוחח'), findsOneWidget);
      expect(find.byKey(const Key('setup-low-memory')), findsOneWidget);
      // The radio mark is at the right of the card's text.
      final card = find.byKey(const Key('model-$smallModelId'));
      final mark = tester.getRect(
        find.descendant(
          of: card,
          matching: find.byIcon(Icons.radio_button_checked),
        ),
      );
      final title = tester.getRect(find.text('מודל קטן'));
      expect(mark.left, greaterThanOrEqualTo(title.right));
      expect(tester.takeException(), isNull);
    });
  });

  group('settings', () {
    testWidgets('the app rows name the model and open the model list', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(
        app(const Scaffold(body: AppSettingsRows()), world),
      );
      await tester.pumpAndSettle();
      expect(find.text('Model'), findsOneWidget);
      expect(find.text('Small model'), findsOneWidget);
      expect(find.text('Phone test'), findsOneWidget);

      await tester.tap(find.byKey(const Key('setting-model')));
      await tester.pumpAndSettle();
      expect(find.byType(ModelsPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('switches to the other model when it is on the phone', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(
        app(const ModelsPage(), world, states: {smallModelId: readySmall}),
      );
      await tester.pumpAndSettle();
      final container = _container(tester);

      // Not on the phone: tapping it changes nothing.
      await tester.tap(find.text('Large model'));
      await tester.pumpAndSettle();
      expect(container.read(chosenModelProvider).value, smallModelId);

      world.store.set(largeModel, readyLarge);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Large model'));
      await tester.pumpAndSettle();
      expect(container.read(chosenModelProvider).value, largeModelId);
      expect(world.prefs.values['assist_model'], largeModelId);
    });

    testWidgets('deleting a model asks first and frees its memory', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(app(const ModelsPage(), world));
      await tester.pumpAndSettle();
      final container = _container(tester);
      await container.read(assistantProvider).ensureLoaded(readySmall.path!);

      await tester.tap(find.byKey(const Key('model-delete-$smallModelId')));
      await tester.pumpAndSettle();
      expect(find.text('Delete this model?'), findsOneWidget);
      expect(find.textContaining('frees 2.6 GB'), findsOneWidget);
      await tester.tap(find.byKey(const Key('model-delete-confirm')));
      await tester.pumpAndSettle();

      expect(world.store.deleted, [smallModelId]);
      expect(world.engines.single.disposed, true);
      expect(container.read(assistantProvider).loadedPath, isNull);
      expect(
        find.byKey(const Key('model-download-$smallModelId')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
