import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_assist/engine/assist_engine.dart';
import 'package:zerotrust_assist/service/assist_protocol.dart';

AssistRequest request(
  AssistTask task,
  String text, {
  String? instruction,
  String? language,
  int? maxTokens,
}) => AssistRequest(
  id: 'r1',
  task: task,
  text: text,
  instruction: instruction,
  language: language,
  maxTokens: maxTokens,
);

String userMessage(TaskPrompt prompt) => prompt.messages.last.text;

void main() {
  group('reading a request', () {
    test('a full request is understood', () {
      final read = AssistRequest.fromMap({
        'id': '10123:7',
        'task': 'translate',
        'text': 'Hello',
        'language': 'he',
        'maxTokens': 64,
        'instruction': null,
      })!;
      expect(read.id, '10123:7');
      expect(read.task, AssistTask.translate);
      expect(read.text, 'Hello');
      expect(read.language, 'he');
      expect(read.maxTokens, 64);
    });

    test('what cannot be answered is refused, not guessed', () {
      // A job from a newer app.
      expect(
        AssistRequest.fromMap({'id': 'a', 'task': 'draw', 'text': 'x'}),
        isNull,
      );
      // Nothing to work on.
      expect(
        AssistRequest.fromMap({'id': 'a', 'task': 'summarize', 'text': '  '}),
        isNull,
      );
      expect(AssistRequest.fromMap({'id': 'a', 'task': 'summarize'}), isNull);
      // No id to answer to.
      expect(AssistRequest.fromMap({'task': 'summarize', 'text': 'x'}), isNull);
      // The app's own question, without the question.
      expect(
        AssistRequest.fromMap({'id': 'a', 'task': 'ask', 'text': 'x'}),
        isNull,
      );
    });
  });

  group('the instruction', () {
    test('is in Hebrew above Hebrew text and in English above English', () {
      final hebrew = buildTaskPrompt(
        request(AssistTask.summarize, 'סיכום ישיבת ועד הבית מיום ראשון'),
      );
      expect(userMessage(hebrew), startsWith('סכם את הטקסט הבא'));
      expect(userMessage(hebrew), endsWith('סיכום ישיבת ועד הבית מיום ראשון'));

      final english = buildTaskPrompt(
        request(AssistTask.summarize, 'Notes from the building meeting'),
      );
      expect(userMessage(english), startsWith('Summarize the following text'));
    });

    test('mixed text goes by the language most of it is in', () {
      expect(mostlyHebrew('פגישה עם David ב-Zoom מחר בבוקר'), true);
      expect(mostlyHebrew('Meeting with דוד tomorrow morning'), false);
      // Digits and punctuation alone decide nothing: English.
      expect(mostlyHebrew('12:30, 14/11'), false);
    });

    test('the model is told the same rules the phone test used', () {
      final prompt = buildTaskPrompt(request(AssistTask.title, 'Shopping'));
      expect(prompt.messages.first.role, AssistRole.system);
      expect(prompt.messages.first.text, taskSystemPrompt);
      expect(prompt.messages, hasLength(2));
    });

    test('translation goes to the other language unless one is named', () {
      String instruction(String text, [String? language]) => taskInstruction(
        request(AssistTask.translate, text, language: language),
        hebrew: mostlyHebrew(text),
      );
      expect(instruction('שלום עולם'), 'תרגם לאנגלית:');
      expect(instruction('Hello world'), 'Translate to Hebrew:');
      expect(instruction('Hello world', 'en'), 'Translate to English:');
      expect(instruction('שלום עולם', 'he'), 'תרגם לעברית:');
    });

    test("an app's own question is sent as written", () {
      final prompt = buildTaskPrompt(
        request(
          AssistTask.ask,
          'Milk, eggs, bread',
          instruction: '  Sort this shopping list by aisle:  ',
        ),
      );
      expect(
        userMessage(prompt),
        'Sort this shopping list by aisle:\n\nMilk, eggs, bread',
      );
    });

    test('every job has words in both languages', () {
      for (final task in AssistTask.values) {
        for (final hebrew in [true, false]) {
          final words = taskInstruction(
            request(task, 'x', instruction: 'Do it'),
            hebrew: hebrew,
          );
          expect(words.trim(), isNotEmpty, reason: '$task hebrew=$hebrew');
        }
      }
    });
  });

  group('length', () {
    test('a text the model can take is sent whole', () {
      final prompt = buildTaskPrompt(
        request(AssistTask.summarize, 'א' * readLetters),
      );
      expect(prompt.truncated, false);
      expect(userMessage(prompt), endsWith('א' * readLetters));
    });

    test('a longer one is cut at the end and says so', () {
      final prompt = buildTaskPrompt(
        request(AssistTask.summarize, '${'א' * readLetters}סוף'),
      );
      expect(prompt.truncated, true);
      expect(userMessage(prompt), isNot(contains('סוף')));
    });

    test('a text to rewrite is cut sooner: its answer is as long', () {
      final text = 'a' * (transformLetters + 1);
      expect(
        buildTaskPrompt(request(AssistTask.rewrite, text)).truncated,
        true,
      );
      expect(
        buildTaskPrompt(request(AssistTask.summarize, text)).truncated,
        false,
      );
    });

    test('a cut never splits a letter made of two code units', () {
      final prompt = buildTaskPrompt(
        request(AssistTask.summarize, '🙂' * (readLetters + 5)),
      );
      expect(userMessage(prompt), endsWith('🙂'));
      expect(
        userMessage(prompt).runes.where((r) => r == 0x1F642),
        hasLength(readLetters),
      );
    });

    test('the answer may be as long as the text for a rewrite', () {
      final short = buildTaskPrompt(request(AssistTask.proofread, 'Hi ther'));
      expect(short.maxTokens, 128);
      final long = buildTaskPrompt(
        request(AssistTask.proofread, 'א' * transformLetters),
      );
      expect(long.maxTokens, transformLetters ~/ 2 + 64);
      expect(long.maxTokens, lessThanOrEqualTo(taskAnswerTokens));
    });

    test('an app can ask for a shorter answer, not a longer one', () {
      expect(
        buildTaskPrompt(
          request(AssistTask.summarize, 'x', maxTokens: 100),
        ).maxTokens,
        100,
      );
      expect(
        buildTaskPrompt(
          request(AssistTask.summarize, 'x', maxTokens: 5000),
        ).maxTokens,
        384,
      );
      expect(
        buildTaskPrompt(request(AssistTask.title, 'x', maxTokens: 1)).maxTokens,
        16,
      );
      // Its own question may run as long as a chat answer.
      expect(
        buildTaskPrompt(
          request(AssistTask.ask, 'x', instruction: 'Why?', maxTokens: 5000),
        ).maxTokens,
        1024,
      );
    });
  });
}
