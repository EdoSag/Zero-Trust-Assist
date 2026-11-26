import 'package:zerotrust_assist/lab/search_check.dart';

/// Search vectors for tests: every note points its own way, and a question
/// points the way of the note it wants. With [second] true a question points
/// more at the note after the wanted one, so the wanted note comes second.
List<double> Function(String text) searchVectors({bool second = false}) {
  final notes = {
    for (var i = 0; i < searchNotes.length; i++)
      searchNotePrompt(searchNotes[i].text): i,
  };
  final questions = {
    for (final question in searchQuestions)
      searchQuestionPrompt(question.text): searchNotes.indexWhere(
        (note) => note.id == question.wants,
      ),
  };
  return (text) {
    final vector = List<double>.filled(searchNotes.length, 0);
    final note = notes[text];
    if (note != null) {
      vector[note] = 1;
      return vector;
    }
    final wanted = questions[text];
    if (wanted == null) throw ArgumentError('unknown text: $text');
    vector[wanted] = second ? 0.5 : 1;
    if (second) vector[(wanted + 1) % searchNotes.length] = 1;
    return vector;
  };
}
