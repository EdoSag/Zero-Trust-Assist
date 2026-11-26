import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_assist/app/assist_settings.dart';
import 'package:zerotrust_assist/chat/assistant.dart';
import 'package:zerotrust_assist/chat/chat_controller.dart';
import 'package:zerotrust_assist/chat/chat_store.dart';
import 'package:zerotrust_assist/chat/conversation.dart';
import 'package:zerotrust_assist/engine/assist_engine.dart';
import 'package:zerotrust_assist/lab/model_store.dart';
import 'package:zerotrust_assist/models/assist_models.dart';

import 'fake_engine.dart';
import 'support/app.dart';

void main() {
  late TestWorld world;

  ProviderContainer container({
    String? chosen = smallModelId,
    Map<String, ModelState>? states,
    List<Conversation> conversations = const [],
    FakeEngine Function()? engine,
  }) {
    world = TestWorld();
    final made = ProviderContainer(
      overrides: overridesFor(
        world,
        chosen: chosen,
        states: states,
        conversations: conversations,
        engine: engine,
      ),
    );
    addTearDown(made.dispose);
    // Makes the repository, so `world.repository` is set.
    made.read(chatRepositoryProvider);
    return made;
  }

  ChatController controllerOf(ProviderContainer c) =>
      c.read(chatControllerProvider.notifier);
  ChatState stateOf(ProviderContainer c) => c.read(chatControllerProvider);

  test('a message is answered and both are saved', () async {
    final c = container();
    await controllerOf(c).send('  What is the capital of France?  ');

    final chat = stateOf(c);
    expect(chat.phase, ChatPhase.idle);
    expect(chat.problem, isNull);
    expect(chat.messages.map((m) => (m.role, m.text)), [
      (ChatRole.user, 'What is the capital of France?'),
      (ChatRole.assistant, 'Hello there'),
    ]);
    expect(chat.conversation!.title, 'What is the capital of France?');
    // Saved once with the question, before the answer, and once with both.
    expect(world.repository.saved.map((s) => s.messages.length), [1, 2]);
    expect(world.repository.conversations.single.messages, hasLength(2));
  });

  test('the model is loaded once, on the processor, and kept', () async {
    final c = container();
    await controllerOf(c).send('One');
    await controllerOf(c).send('Two');
    expect(world.engines, hasLength(1));
    expect(world.engines.single.loadedDevice, AssistDevice.cpu);
    expect(world.engines.single.disposed, false);
    expect(c.read(assistantProvider).loadedPath, '/models/small.litertlm');
  });

  test('the model sees the instructions and the conversation so far', () async {
    final c = container();
    await controllerOf(c).send('One');
    await controllerOf(c).send('Two');
    final last = world.engines.single.requests.last;
    expect(last.map((m) => (m.role, m.text)).skip(1), [
      (AssistRole.user, 'One'),
      (AssistRole.assistant, 'Hello there'),
      (AssistRole.user, 'Two'),
    ]);
    expect(last.first.role, AssistRole.system);
    expect(last.first.text, contains('ZT Assist'));
  });

  test('the answer shows piece by piece while it is written', () async {
    final seen = <(ChatPhase, String)>[];
    final c = container();
    c.listen(
      chatControllerProvider,
      (_, next) => seen.add((next.phase, next.partial)),
    );
    await controllerOf(c).send('Hi');
    expect(seen, [
      (ChatPhase.loadingModel, ''),
      (ChatPhase.answering, ''),
      (ChatPhase.answering, 'Hello'),
      (ChatPhase.answering, 'Hello there'),
      (ChatPhase.idle, ''),
    ]);
  });

  test('the screen is kept on during an answer and released after', () async {
    final c = container();
    await controllerOf(c).send('Hi');
    expect(world.device.awake, [true, false]);
  });

  test('Stop keeps what was written and marks it', () async {
    late ProviderContainer c;
    var stopped = false;
    c = container(
      engine: () => FakeEngine(
        answer: (_) => const ['One', ' two', ' three'],
        onPiece: (engine) {
          if (!stopped && stateOf(c).partial == 'One two') {
            stopped = true;
            controllerOf(c).stop();
          }
        },
      ),
    );
    await controllerOf(c).send('Count');
    final answer = stateOf(c).messages.last;
    expect(answer.text, 'One two');
    expect(answer.stopped, true);
    expect(stateOf(c).problem, isNull);
    expect(world.repository.conversations.single.messages.last.stopped, true);

    // The next answer is a fresh one, not marked.
    await controllerOf(c).send('Again');
    expect(stateOf(c).messages.last.text, 'One two three');
    expect(stateOf(c).messages.last.stopped, false);
  });

  test('without a model on the phone nothing is sent', () async {
    final c = container(states: {});
    await controllerOf(c).send('Hi');
    expect(stateOf(c).problem, ChatProblem.modelMissing);
    expect(stateOf(c).messages, isEmpty);
    expect(world.repository.saved, isEmpty);
    expect(world.engines, isEmpty);

    controllerOf(c).clearProblem();
    expect(stateOf(c).problem, isNull);
  });

  test('uses the model that was chosen', () async {
    final c = container(
      chosen: largeModelId,
      states: {smallModelId: readySmall, largeModelId: readyLarge},
    );
    await controllerOf(c).send('Hi');
    expect(c.read(assistantProvider).loadedPath, '/models/large.litertlm');
  });

  test(
    'switching the model loads the other one for the next message',
    () async {
      final c = container(
        states: {smallModelId: readySmall, largeModelId: readyLarge},
      );
      await controllerOf(c).send('Hi');
      await c.read(chosenModelProvider.notifier).choose(largeModelId);
      await controllerOf(c).send('Again');
      expect(world.engines, hasLength(2));
      expect(world.engines.first.disposed, true);
      expect(c.read(assistantProvider).loadedPath, '/models/large.litertlm');
    },
  );

  test('a model that does not load keeps the question and says why', () async {
    final c = container(
      engine: () => FakeEngine(loadError: StateError('out of memory')),
    );
    await controllerOf(c).send('Hi');
    final chat = stateOf(c);
    expect(chat.problem, ChatProblem.loadFailed);
    expect(chat.problemDetail, contains('out of memory'));
    expect(chat.messages.single.text, 'Hi');
    expect(chat.phase, ChatPhase.idle);
    expect(world.engines.single.disposed, true);
    expect(world.device.awake, [true, false]);
  });

  test('an answer that breaks keeps what was written', () async {
    var calls = 0;
    final c = container(
      engine: () => FakeEngine(
        answer: (_) => calls++ == 0 ? const ['Part'] : throw StateError('x'),
      ),
    );
    await controllerOf(c).send('First');
    expect(stateOf(c).problem, isNull);
    await controllerOf(c).send('Second');
    expect(stateOf(c).problem, ChatProblem.answerFailed);
    expect(stateOf(c).messages.last.text, 'Second');
  });

  test('a chat that cannot be saved says so', () async {
    final c = container();
    world.repository.failSaves = true;
    await controllerOf(c).send('Hi');
    expect(stateOf(c).problem, ChatProblem.saveFailed);
    // The answer is still on screen.
    expect(stateOf(c).messages, hasLength(2));
  });

  test('opening another chat drops the answer still being written', () async {
    final other = Conversation.start('other', DateTime.utc(2026)).withMessage(
      ChatMessage(role: ChatRole.user, text: 'Old', at: DateTime.utc(2026)),
    );
    late ProviderContainer c;
    c = container(
      conversations: [other],
      engine: () => FakeEngine(
        answer: (_) => const ['One', ' two'],
        onPiece: (engine) {
          if (stateOf(c).partial == 'One') controllerOf(c).open(other);
        },
      ),
    );
    await controllerOf(c).send('New');
    expect(stateOf(c).conversation!.id, 'other');
    expect(stateOf(c).messages.single.text, 'Old');
    expect(stateOf(c).phase, ChatPhase.idle);
    // The question was saved; the half answer was not added anywhere.
    final saved = world.repository.conversations.firstWhere(
      (conversation) => conversation.id != 'other',
    );
    expect(saved.messages.single.text, 'New');
  });

  test(
    'a new chat starts empty and a second message cannot overtake',
    () async {
      final c = container(
        engine: () => FakeEngine(answer: (_) => const ['Answer']),
      );
      final first = controllerOf(c).send('One');
      // Ignored: an answer is on its way.
      await controllerOf(c).send('Two');
      await first;
      expect(stateOf(c).messages.map((m) => m.text), ['One', 'Answer']);

      controllerOf(c).newChat();
      expect(stateOf(c).conversation, isNull);
      await controllerOf(c).send('Fresh');
      expect(world.repository.conversations, hasLength(2));
    },
  );

  test('renames and deletes a chat', () async {
    final c = container();
    await controllerOf(c).send('Hi');
    final conversation = stateOf(c).conversation!;

    await controllerOf(c).rename(conversation, ' Greetings ');
    expect(stateOf(c).conversation!.title, 'Greetings');
    expect(world.repository.conversations.single.title, 'Greetings');
    // An empty name is not a name.
    await controllerOf(c).rename(stateOf(c).conversation!, '   ');
    expect(world.repository.conversations.single.title, 'Greetings');

    await controllerOf(c).delete(stateOf(c).conversation!);
    expect(world.repository.conversations, isEmpty);
    expect(stateOf(c).conversation, isNull);
  });

  test('empty messages are not sent', () async {
    final c = container();
    await controllerOf(c).send('   \n ');
    expect(stateOf(c).messages, isEmpty);
    expect(world.engines, isEmpty);
  });
}
