import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_assist/chat/assistant.dart';
import 'package:zerotrust_assist/engine/assist_engine.dart';
import 'package:zerotrust_assist/service/assist_protocol.dart';
import 'package:zerotrust_assist/service/engine_host.dart';

import 'fake_engine.dart';

void main() {
  late List<(String, Map<String, Object?>)> sent;
  late List<FakeEngine> engines;

  EngineHost host({
    String? path = '/models/small.litertlm',
    FakeEngine Function()? engine,
  }) {
    sent = [];
    engines = [];
    return EngineHost(
      assistant: Assistant(
        createEngine: () {
          final made = (engine ?? FakeEngine.new)();
          engines.add(made);
          return made;
        },
      ),
      modelPath: () async => path,
      emit: (method, arguments) => sent.add((method, arguments)),
    );
  }

  Map<String, Object?> ask(String id, {String task = 'summarize'}) => {
    'id': id,
    'task': task,
    'text': 'Notes from the building meeting',
  };

  Future<void> settle() => pumpEventQueue();

  List<String> methods() => [for (final (method, _) in sent) method];

  test('a request is answered piece by piece, then closed', () async {
    final h = host();
    h.ask(ask('1:a'));
    await settle();

    expect(methods(), ['chunk', 'chunk', 'done']);
    expect(sent[0].$2, {'id': '1:a', 'text': 'Hello'});
    expect(sent[1].$2, {'id': '1:a', 'text': ' there'});
    final done = sent[2].$2;
    expect(done['id'], '1:a');
    expect(done['stopped'], false);
    expect(done['truncated'], false);
    expect(done['tokens'], 2);
    expect(done['milliseconds'], isA<int>());
    expect(done['firstMilliseconds'], isA<int>());
  });

  test('the model gets the job, and the same answer every time', () async {
    final h = host();
    h.ask(ask('1:a', task: 'title'));
    await settle();
    final request = engines.single.requests.single;
    expect(request.first.role, AssistRole.system);
    expect(request.last.text, startsWith('Suggest a short title'));
    expect(engines.single.temperatures.single, 0);
    expect(engines.single.loadedDevice, AssistDevice.cpu);
  });

  test("the runtime's own count of the answer is passed on", () async {
    final h = host(
      engine: () => FakeEngine(
        usage: const AssistUsage(
          promptTokens: 120,
          cachedPromptTokens: 0,
          completionTokens: 41,
          timeToFirstToken: null,
          duration: null,
        ),
      ),
    );
    h.ask(ask('1:a'));
    await settle();
    expect(sent.last.$2['tokens'], 41);
  });

  test('requests wait their turn and the model is loaded once', () async {
    final gate = Completer<void>();
    final h = host(engine: () => FakeEngine(beforePiece: () => gate.future));
    h.ask(ask('1:a'));
    h.ask(ask('2:a'));
    await settle();
    expect(sent, isEmpty);
    expect((await h.status())['busy'], true);

    gate.complete();
    await settle();
    expect(
      [for (final (_, arguments) in sent) arguments['id']],
      ['1:a', '1:a', '1:a', '2:a', '2:a', '2:a'],
    );
    expect(engines, hasLength(1));
    expect((await h.status())['busy'], false);
  });

  test('stopping keeps what was written and says it was stopped', () async {
    late EngineHost h;
    h = host(
      engine: () => FakeEngine(
        answer: (_) => const ['One', ' two', ' three'],
        onPiece: (engine) {
          if (sent.length == 2) h.cancel('1:a');
        },
      ),
    );
    h.ask(ask('1:a'));
    await settle();
    expect(methods(), ['chunk', 'chunk', 'done']);
    expect(sent.last.$2['stopped'], true);

    // The next request is a fresh one.
    h.ask(ask('1:b'));
    await settle();
    expect(sent.last.$2['id'], '1:b');
    expect(sent.last.$2['stopped'], false);
  });

  test(
    'a request stopped while it waits is closed without the model',
    () async {
      final gate = Completer<void>();
      final h = host(engine: () => FakeEngine(beforePiece: () => gate.future));
      h.ask(ask('1:a'));
      h.ask(ask('2:a'));
      await settle();
      h.cancel('2:a');
      expect(sent.single.$1, 'done');
      expect(sent.single.$2['id'], '2:a');
      expect(sent.single.$2['stopped'], true);

      gate.complete();
      await settle();
      expect(engines.single.requests, hasLength(1));
      // Stopping something unknown, or already answered, does nothing.
      final before = sent.length;
      h.cancel('2:a');
      h.cancel('nobody');
      expect(sent, hasLength(before));
    },
  );

  test('stopped while the model loads, nothing is written', () async {
    final loading = Completer<void>();
    final h = host(engine: () => FakeEngine(beforeLoad: () => loading.future));
    h.ask(ask('1:a'));
    await settle();
    h.cancel('1:a');
    loading.complete();
    await settle();
    expect(methods(), ['done']);
    expect(sent.single.$2['stopped'], true);
    expect(engines.single.requests, isEmpty);
  });

  test('without a model on the phone the app is told so', () async {
    final h = host(path: null);
    expect((await h.status())['ready'], false);
    h.ask(ask('1:a'));
    await settle();
    expect(sent.single.$1, 'failed');
    expect(sent.single.$2['code'], AssistFailure.noModel);
    expect(engines, isEmpty);
  });

  test(
    'a model that does not load, or breaks, fails that request only',
    () async {
      var first = true;
      final h = host(
        engine: () {
          if (first) {
            first = false;
            return FakeEngine(loadError: StateError('out of memory'));
          }
          return FakeEngine(
            answer: (messages) => messages.last.text.contains('boom')
                ? throw StateError('boom')
                : const ['Fine'],
          );
        },
      );
      h.ask(ask('1:a'));
      await settle();
      expect(sent.single.$1, 'failed');
      expect(sent.single.$2['code'], AssistFailure.loadFailed);
      expect(sent.single.$2['detail'], contains('out of memory'));

      sent.clear();
      h.ask({'id': '1:b', 'task': 'summarize', 'text': 'boom'});
      h.ask(ask('1:c'));
      await settle();
      expect(methods(), ['failed', 'chunk', 'done']);
      expect(sent.first.$2['code'], AssistFailure.failed);
      expect(sent.last.$2['id'], '1:c');
    },
  );

  test('a request this version does not know is refused', () async {
    final h = host();
    h.ask({'id': '1:a', 'task': 'draw', 'text': 'A cat'});
    expect(sent.single.$1, 'failed');
    expect(sent.single.$2, {
      'id': '1:a',
      'code': AssistFailure.unsupported,
      'detail': null,
    });
    expect(engines, isEmpty);
  });

  test('a long text is cut and the app is told', () async {
    final h = host();
    h.ask({'id': '1:a', 'task': 'summarize', 'text': 'a' * (readLetters + 10)});
    await settle();
    expect(sent.last.$2['truncated'], true);
  });

  test(
    'status says which version this is and whether a model is there',
    () async {
      expect(await host().status(), {
        'protocol': assistProtocol,
        'ready': true,
        'busy': false,
      });
    },
  );

  test('shutting down stops everything and frees the model', () async {
    final gate = Completer<void>();
    final h = host(
      engine: () => FakeEngine(
        answer: (_) => const ['One', ' two'],
        beforePiece: () => gate.future,
      ),
    );
    h.ask(ask('1:a'));
    h.ask(ask('2:a'));
    await settle();
    final closing = h.shutdown();
    gate.complete();
    await closing;
    await settle();

    expect(engines.single.disposed, true);
    // Both were closed as stopped; nothing was written after the shutdown.
    final closed = {
      for (final (method, arguments) in sent)
        if (method == 'done') arguments['id']: arguments['stopped'],
    };
    expect(closed, {'1:a': true, '2:a': true});
    expect(methods().where((m) => m == 'chunk'), isEmpty);

    // Anything asked after that is turned away at once.
    sent.clear();
    h.ask(ask('3:a'));
    expect(sent.single.$2['stopped'], true);
    expect(engines, hasLength(1));
  });
  group('quick add', () {
    Map<String, Object?> quick(String id) => {
      'id': id,
      'task': 'quickAdd',
      'text': 'Dentist tomorrow at 9',
    };

    test('the model is stopped once the object has closed', () async {
      final h = host(
        engine: () => FakeEngine(
          answer: (_) => const [
            '{"title":"Dentist",',
            '"time":"09:00"}',
            '\n\nNote: Buy milk\n',
            '{"title":"Buy milk"}',
          ],
        ),
      );
      h.ask(quick('1:a'));
      await settle();

      expect(methods(), ['chunk', 'chunk', 'done']);
      expect(sent[1].$2['text'], '"time":"09:00"}');
      // The end of the answer, not an answer cut short.
      expect(sent[2].$2['stopped'], false);
      expect(sent[2].$2['tokens'], 2);
      expect(
        engines.single.requests.single.last.text,
        endsWith('Note: Dentist tomorrow at 9'),
      );
    });

    test('a piece that goes past the object is cut at its end', () async {
      final h = host(
        engine: () => FakeEngine(
          answer: (_) => const [
            '{"title":"Dentist","time":"09:00"}\n\nNote: Buy milk\n{"title":',
            '"Buy milk"}',
          ],
        ),
      );
      h.ask(quick('1:a'));
      await settle();

      expect(methods(), ['chunk', 'done']);
      expect(sent[0].$2['text'], '{"title":"Dentist","time":"09:00"}');
      expect(sent[1].$2['stopped'], false);
    });

    test('the next request is answered as usual', () async {
      final h = host(
        engine: () => FakeEngine(
          answer: (messages) => messages.last.text.contains('Note: ')
              ? const ['{"title":"Dentist"}', ' and more']
              : const ['A', ' summary'],
        ),
      );
      h.ask(quick('1:a'));
      h.ask(ask('2:a'));
      await settle();

      expect(methods(), ['chunk', 'done', 'chunk', 'chunk', 'done']);
      expect(sent[0].$2, {'id': '1:a', 'text': '{"title":"Dentist"}'});
      expect(sent[3].$2, {'id': '2:a', 'text': ' summary'});
      expect(sent[4].$2['stopped'], false);
    });

    test('an answer with no object runs to its end', () async {
      final h = host(
        engine: () => FakeEngine(answer: (_) => const ['I cannot', ' read it']),
      );
      h.ask(quick('1:a'));
      await settle();
      expect(methods(), ['chunk', 'chunk', 'done']);
      expect(sent[2].$2['stopped'], false);
    });
  });
}
