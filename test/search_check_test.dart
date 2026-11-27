import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_assist/lab/search_check.dart';

import 'fake_engine.dart';
import 'support/search_vectors.dart';

void main() {
  test('every question is after a note of the pile, in its own group', () {
    final ids = searchNotes.map((note) => note.id).toSet();
    expect(ids.length, searchNotes.length);
    final hebrew = RegExp('[א-ת]');
    for (final question in searchQuestions) {
      expect(ids, contains(question.wants), reason: question.text);
      final note = searchNotes.firstWhere((n) => n.id == question.wants);
      final askedInHebrew = hebrew.hasMatch(question.text);
      final writtenInHebrew = hebrew.hasMatch(note.text);
      expect(question.group, switch ((askedInHebrew, writtenInHebrew)) {
        (true, true) => SearchGroup.hebrew,
        (false, false) => SearchGroup.english,
        _ => SearchGroup.crossLanguage,
      }, reason: question.text);
    }
    // Enough of each to tell a good model from a lucky one.
    for (final group in SearchGroup.values) {
      expect(
        searchQuestions.where((q) => q.group == group).length,
        greaterThanOrEqualTo(6),
      );
    }
  });

  test('no question is found by its words alone', () {
    // A question that repeats its note's rarest words would be found by a
    // plain word search, and say nothing about the model.
    for (final question in searchQuestions) {
      final note = searchNotes.firstWhere((n) => n.id == question.wants);
      final words = question.text
          .toLowerCase()
          .split(RegExp(r'[^a-zא-ת]+'))
          .where((word) => word.length > 3);
      final shared = words.where(note.text.toLowerCase().contains).length;
      expect(shared, lessThanOrEqualTo(1), reason: question.text);
    }
  });

  test('the model is asked with the words it was trained on', () async {
    final engine = FakeEngine(vector: searchVectors());
    await runSearchCheck(engine.embed);
    expect(engine.embedded.length, searchNotes.length + searchQuestions.length);
    expect(
      engine.embedded.first,
      'title: none | text: ${searchNotes.first.text}',
    );
    expect(
      engine.embedded.last,
      'task: search result | query: ${searchQuestions.last.text}',
    );
  });

  test('a model that finds every note scores full marks', () async {
    final progress = <int>[];
    final report = await runSearchCheck(
      FakeEngine(vector: searchVectors()).embed,
      onProgress: (done, total) {
        expect(total, searchNotes.length + searchQuestions.length);
        progress.add(done);
      },
    );
    expect(progress.first, 1);
    expect(progress.last, searchNotes.length + searchQuestions.length);
    expect(report.vectorSize, searchNotes.length);
    expect(report.notes, searchNotes.length);
    expect(report.first(), searchQuestions.length);
    expect(report.firstThree(), searchQuestions.length);
    expect(report.first(SearchGroup.hebrew), report.asked(SearchGroup.hebrew));
    expect(report.hebrewGoodEnough, isTrue);

    final text = report.describe(model: 'Test model', loadMilliseconds: 1234);
    expect(text, contains('Model: Test model'));
    expect(text, contains('Ready in 1.2 s'));
    expect(text, contains('Hebrew: 10 / 10 of 10'));
    expect(text, contains('All: 24 / 24 of 24'));
    expect(text, contains('good enough to build search on'));
    expect(text, isNot(contains('Not on top')));
  });

  test('a note in second place counts for the first three only', () async {
    final report = await runSearchCheck(
      FakeEngine(vector: searchVectors(second: true)).embed,
    );
    expect(report.first(), 0);
    expect(report.firstThree(), searchQuestions.length);
    expect(report.answers.every((answer) => answer.rank == 2), isTrue);
    expect(report.hebrewGoodEnough, isFalse);

    final text = report.describe();
    expect(text, contains('Hebrew: 0 / 10 of 10'));
    expect(text, contains('not good enough yet'));
    expect(text, contains('Not on top:'));
    expect(text, contains('"what is the wifi code" wanted wifi (place 2)'));
  });

  test('a question after a note that is missing counts as lost', () async {
    const notes = [
      SearchNote('a', 'one'),
      SearchNote('b', 'two'),
      SearchNote('c', 'three'),
    ];
    final report = await runSearchCheck(
      (texts) async => [
        for (final _ in texts) [1.0, 0.0],
      ],
      notes: notes,
      questions: const [SearchQuestion(SearchGroup.english, 'x', 'gone')],
    );
    expect(report.answers.single.rank, 4);
    expect(report.first(), 0);
    expect(report.firstThree(), 0);
  });

  test('cosine tells alike from unrelated', () {
    expect(cosine([1, 0], [2, 0]), closeTo(1, 1e-9));
    expect(cosine([1, 0], [0, 3]), 0);
    expect(cosine([1, 0], [-1, 0]), closeTo(-1, 1e-9));
    expect(cosine([0, 0], [1, 1]), 0);
  });

  test('a chat model cannot make search vectors', () {
    expect(FakeEngine().embed(['x']), throwsStateError);
  });
}
