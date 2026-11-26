/// The phone test for search by meaning: a small pile of notes, questions
/// that use other words than the note they are after, and a count of how
/// often the right note comes out on top.
///
/// It answers two things before search is built into the other apps: is the
/// search model good enough in Hebrew, and how long does a phone need to
/// read a note and to answer a search.
library;

import 'dart:math' as math;

/// One note of the pile.
class SearchNote {
  const SearchNote(this.id, this.text);

  final String id;
  final String text;
}

/// Which language a question and its note are in.
enum SearchGroup {
  english('English'),
  hebrew('Hebrew'),

  /// The question is in one language and the note in the other.
  crossLanguage('Across languages');

  const SearchGroup(this.label);

  final String label;
}

/// A question, and the note that answers it.
class SearchQuestion {
  const SearchQuestion(this.group, this.text, this.wants);

  final SearchGroup group;
  final String text;

  /// The [SearchNote.id] that should come out on top.
  final String wants;
}

/// The notes of the test: the kind of thing people keep in a notes app, half
/// in English and half in Hebrew, with several close to one another so the
/// right one is not found by its subject alone.
const List<SearchNote> searchNotes = [
  SearchNote(
    'wifi',
    'Home internet: the router is behind the TV. Network name Sagron5, the '
        'password is on the sticker under it. Technician: 03-555-0142.',
  ),
  SearchNote(
    'passport',
    'Passport renewal. Need two photos, the old passport and the fee '
        'receipt. Appointment at the office on Herzl street, takes about three '
        'weeks to arrive.',
  ),
  SearchNote(
    'car-service',
    'Car: annual service at 60,000 km, change the oil and the brake pads. '
        'Garage said the front tyres will need replacing before winter.',
  ),
  SearchNote(
    'car-insurance',
    'Car insurance ends on 14 March. Last year the price was 3,200. Ask '
        'two other companies for a quote before renewing.',
  ),
  SearchNote(
    'pasta',
    'Quick dinner: boil pasta, fry garlic and chili in olive oil, add '
        'cherry tomatoes and basil. Ten minutes, the kids like it.',
  ),
  SearchNote(
    'gift-dana',
    'Dana turns 30 in June. She mentioned wanting a film camera or a '
        'pottery class. Budget around 400.',
  ),
  SearchNote(
    'book-list',
    'Books to read: The Remains of the Day, Sapiens, A Gentleman in Moscow. '
        'Noa recommended the last one.',
  ),
  SearchNote(
    'run-plan',
    'Running plan: three times a week, easy pace on Sunday and Tuesday, '
        'long run on Friday morning. Goal: 10 km without stopping by May.',
  ),
  SearchNote(
    'meeting-budget',
    'Team meeting notes: the budget for next quarter is cut by ten percent. '
        'We postpone the new hire and keep the conference trip.',
  ),
  SearchNote(
    'plants',
    'Balcony plants: water the basil every two days, the cactus once a '
        'month. Move the lemon tree inside when it gets cold.',
  ),
  SearchNote(
    'flight',
    'Flight to Athens on 2 August, 06:40 from terminal 3. Seats 14A and '
        '14B. One suitcase each, check in online the day before.',
  ),
  SearchNote(
    'landlord',
    'Apartment: the lease ends in September. The landlord agreed to fix '
        'the leaking tap in the bathroom and repaint the bedroom.',
  ),
  SearchNote(
    'רופא-ילדים',
    'רופאת הילדים: ד"ר לוי, קופת חולים ברחוב הנשיא. '
        'חיסון הבא לתינוק בגיל שנה. לזכור להביא את פנקס החיסונים.',
  ),
  SearchNote(
    'חשמל',
    'חשבון החשמל האחרון היה גבוה מאוד, 780 שקל לחודשיים. '
        'לבדוק אם הדוד נשאר דולק בלילה ולשקול לעבור לספק זול יותר.',
  ),
  SearchNote(
    'עוגה',
    'עוגת שוקולד של סבתא: שש ביצים, כוס סוכר, 200 גרם '
        'שוקולד מריר, חצי כוס שמן. לאפות 35 דקות בחום בינוני.',
  ),
  SearchNote(
    'חתונה',
    'החתונה של יעל ואורי ביום חמישי בגן אירועים ליד '
        'קיסריה. להביא צ\'ק, לתאם נסיעה משותפת עם ההורים.',
  ),
  SearchNote(
    'גן',
    'הרשמה לגן לשנה הבאה נסגרת בסוף ינואר. צריך צילום תעודת '
        'זהות של שני ההורים ואישור מגורים מהעירייה.',
  ),
  SearchNote(
    'מחשב',
    'המחשב הנייד איטי מאוד. הטכנאי המליץ להחליף לכונן '
        'מהיר ולהוסיף זיכרון, בערך 600 שקל כולל עבודה.',
  ),
  SearchNote(
    'טיול',
    'טיול לצפון בסוכות: לינה בצימר בראש פינה, מסלול הליכה '
        'בנחל עמוד, ביקור ביקב ביום האחרון.',
  ),
  SearchNote(
    'וטרינר',
    'הכלב צריך חיסון כלבת עד סוף החודש. הווטרינר פתוח '
        'בימי שישי עד הצהריים. לשאול גם על טיפול נגד קרציות.',
  ),
  SearchNote(
    'שיפוץ',
    'שיפוץ המטבח: הקבלן נתן הצעת מחיר של 45 אלף. ארונות '
        'חדשים, שיש ומשטח עבודה. העבודה תימשך כחמישה שבועות.',
  ),
  SearchNote(
    'ארנונה',
    'ארנונה: אפשר לקבל הנחה אם משלמים את כל השנה מראש '
        'עד סוף פברואר. לבדוק גם זכאות להנחת מילואים.',
  ),
  SearchNote(
    'שיעורי-פסנתר',
    'שיעורי פסנתר לנועה בימי שלישי בחמש אחר '
        'הצהריים אצל המורה מיכל. 150 שקל לשיעור, לשלם בתחילת כל חודש.',
  ),
  SearchNote(
    'רעיונות-עבודה',
    'רעיונות לפגישה עם הלקוח: להציג את הגרסה '
        'החדשה של האפליקציה, לדבר על לוח הזמנים ולבקש משוב על העיצוב.',
  ),
];

/// The questions. Each uses other words than its note, the way a person
/// asks for something they wrote down months ago.
const List<SearchQuestion> searchQuestions = [
  SearchQuestion(SearchGroup.english, 'what is the wifi code', 'wifi'),
  SearchQuestion(
    SearchGroup.english,
    'documents I need for a new travel document',
    'passport',
  ),
  SearchQuestion(
    SearchGroup.english,
    'when do the wheels need changing',
    'car-service',
  ),
  SearchQuestion(
    SearchGroup.english,
    'how much did I pay to insure the vehicle',
    'car-insurance',
  ),
  SearchQuestion(SearchGroup.english, 'something fast to cook', 'pasta'),
  SearchQuestion(
    SearchGroup.english,
    'birthday present ideas for my friend',
    'gift-dana',
  ),
  SearchQuestion(SearchGroup.english, 'when is our plane leaving', 'flight'),
  SearchQuestion(
    SearchGroup.english,
    'repairs the owner of the flat promised',
    'landlord',
  ),
  SearchQuestion(SearchGroup.hebrew, 'מתי הזריקה הבאה של התינוק', 'רופא-ילדים'),
  SearchQuestion(
    SearchGroup.hebrew,
    'למה אנחנו משלמים כל כך הרבה על חשמל',
    'חשמל',
  ),
  SearchQuestion(SearchGroup.hebrew, 'מתכון לקינוח', 'עוגה'),
  SearchQuestion(SearchGroup.hebrew, 'איפה האירוע של יעל', 'חתונה'),
  SearchQuestion(
    SearchGroup.hebrew,
    'אילו מסמכים צריך לרישום לגן הילדים',
    'גן',
  ),
  SearchQuestion(SearchGroup.hebrew, 'כמה יעלה לשדרג את הלפטופ', 'מחשב'),
  SearchQuestion(SearchGroup.hebrew, 'איפה ישנים בחופשה בחג', 'טיול'),
  SearchQuestion(
    SearchGroup.hebrew,
    'כמה זמן ייקח לבנות את המטבח החדש',
    'שיפוץ',
  ),
  SearchQuestion(SearchGroup.hebrew, 'איך לחסוך במיסים לעירייה', 'ארנונה'),
  SearchQuestion(SearchGroup.hebrew, 'באיזה יום החוג של נועה', 'שיעורי-פסנתר'),
  SearchQuestion(
    SearchGroup.crossLanguage,
    'מה הסיסמה של האינטרנט בבית',
    'wifi',
  ),
  SearchQuestion(SearchGroup.crossLanguage, 'מתי הטיסה ליוון', 'flight'),
  SearchQuestion(
    SearchGroup.crossLanguage,
    'כמה פעמים בשבוע אני רץ',
    'run-plan',
  ),
  SearchQuestion(
    SearchGroup.crossLanguage,
    'dog vaccination deadline',
    'וטרינר',
  ),
  SearchQuestion(
    SearchGroup.crossLanguage,
    'chocolate cake ingredients',
    'עוגה',
  ),
  SearchQuestion(
    SearchGroup.crossLanguage,
    'what to show the client at the meeting',
    'רעיונות-עבודה',
  ),
];

/// The words the search model wants in front of a question. The model was
/// trained with them; without them it finds less.
String searchQuestionPrompt(String question) =>
    'task: search result | query: ${question.trim()}';

/// The words the search model wants in front of a text that is searched.
String searchNotePrompt(String text) => 'title: none | text: ${text.trim()}';

/// How alike two vectors point: 1 for the same direction, 0 for unrelated.
double cosine(List<double> a, List<double> b) {
  final length = math.min(a.length, b.length);
  var dot = 0.0;
  var aa = 0.0;
  var bb = 0.0;
  for (var i = 0; i < length; i++) {
    dot += a[i] * b[i];
    aa += a[i] * a[i];
    bb += b[i] * b[i];
  }
  if (aa == 0 || bb == 0) return 0;
  return dot / (math.sqrt(aa) * math.sqrt(bb));
}

/// How one question came out.
class SearchAnswer {
  const SearchAnswer({
    required this.question,
    required this.rank,
    required this.found,
    required this.milliseconds,
  });

  final SearchQuestion question;

  /// The place of the wanted note among the results: 1 is on top.
  final int rank;

  /// The note that came out on top.
  final String found;

  /// How long turning the question into a vector took.
  final int milliseconds;
}

/// The outcome of the whole test.
class SearchReport {
  const SearchReport({
    required this.vectorSize,
    required this.notes,
    required this.noteLetters,
    required this.indexMilliseconds,
    required this.answers,
  });

  /// How many numbers a vector has.
  final int vectorSize;

  /// How many notes were read.
  final int notes;

  /// Their length together, in letters.
  final int noteLetters;

  /// How long reading all the notes took.
  final int indexMilliseconds;
  final List<SearchAnswer> answers;

  Iterable<SearchAnswer> _of(SearchGroup? group) =>
      group == null ? answers : answers.where((a) => a.question.group == group);

  int asked([SearchGroup? group]) => _of(group).length;

  /// Questions whose note came out on top.
  int first([SearchGroup? group]) =>
      _of(group).where((a) => a.rank == 1).length;

  /// Questions whose note was among the first three, which is what a list
  /// of search results shows without scrolling.
  int firstThree([SearchGroup? group]) =>
      _of(group).where((a) => a.rank <= 3).length;

  double get millisecondsPerNote => notes == 0 ? 0 : indexMilliseconds / notes;

  double get millisecondsPerQuestion => answers.isEmpty
      ? 0
      : answers.map((a) => a.milliseconds).reduce((a, b) => a + b) /
            answers.length;

  /// Good enough to build on: nearly every Hebrew question finds its note
  /// among the first three, and most have it on top.
  bool get hebrewGoodEnough {
    final hebrew = asked(SearchGroup.hebrew);
    if (hebrew == 0) return false;
    return firstThree(SearchGroup.hebrew) / hebrew >= 0.8 &&
        first(SearchGroup.hebrew) / hebrew >= 0.6;
  }

  /// The report as text, to read on the phone and to send on.
  String describe({String? model, int? loadMilliseconds}) {
    final out = StringBuffer();
    out.writeln('Search by meaning, phone test');
    if (model != null) out.writeln('Model: $model');
    if (loadMilliseconds != null) {
      out.writeln('Ready in ${_seconds(loadMilliseconds)}');
    }
    out.writeln('Vector size: $vectorSize');
    out.writeln(
      'Read $notes notes ($noteLetters letters) in '
      '${_seconds(indexMilliseconds)}, '
      '${millisecondsPerNote.round()} ms a note',
    );
    out.writeln(
      'A search takes ${millisecondsPerQuestion.round()} ms on average',
    );
    out.writeln();
    out.writeln('Right note on top / among the first three:');
    for (final group in SearchGroup.values) {
      if (asked(group) == 0) continue;
      out.writeln(
        '  ${group.label}: ${first(group)} / ${firstThree(group)} '
        'of ${asked(group)}',
      );
    }
    out.writeln('  All: ${first()} / ${firstThree()} of ${asked()}');
    out.writeln();
    out.writeln(
      hebrewGoodEnough
          ? 'Hebrew: good enough to build search on.'
          : 'Hebrew: not good enough yet. Another model is needed.',
    );
    final missed = answers.where((a) => a.rank > 1).toList();
    if (missed.isNotEmpty) {
      out.writeln();
      out.writeln('Not on top:');
      for (final answer in missed) {
        out.writeln(
          '  "${answer.question.text}" wanted ${answer.question.wants} '
          '(place ${answer.rank}), got ${answer.found}',
        );
      }
    }
    return out.toString().trimRight();
  }

  static String _seconds(int milliseconds) =>
      '${(milliseconds / 1000).toStringAsFixed(1)} s';
}

/// Reads the notes, asks the questions and counts. [embed] turns texts into
/// vectors (the search model); [onProgress] is called after every text.
Future<SearchReport> runSearchCheck(
  Future<List<List<double>>> Function(List<String> texts) embed, {
  List<SearchNote> notes = searchNotes,
  List<SearchQuestion> questions = searchQuestions,
  void Function(int done, int total)? onProgress,
}) async {
  final total = notes.length + questions.length;
  var done = 0;

  // One note at a time, the way an app will read them: as they are written.
  final vectors = <String, List<double>>{};
  final index = Stopwatch()..start();
  for (final note in notes) {
    vectors[note.id] = (await embed([searchNotePrompt(note.text)])).single;
    onProgress?.call(++done, total);
  }
  index.stop();

  final answers = <SearchAnswer>[];
  for (final question in questions) {
    final watch = Stopwatch()..start();
    final asked = (await embed([searchQuestionPrompt(question.text)])).single;
    watch.stop();
    final order = notes.map((note) => note.id).toList()
      ..sort(
        (a, b) =>
            cosine(asked, vectors[b]!).compareTo(cosine(asked, vectors[a]!)),
      );
    final place = order.indexOf(question.wants);
    answers.add(
      SearchAnswer(
        question: question,
        // A question after a note that is not in the pile counts as lost.
        rank: place < 0 ? notes.length + 1 : place + 1,
        found: order.isEmpty ? '' : order.first,
        milliseconds: watch.elapsedMilliseconds,
      ),
    );
    onProgress?.call(++done, total);
  }

  return SearchReport(
    vectorSize: vectors.isEmpty ? 0 : vectors.values.first.length,
    notes: notes.length,
    noteLetters: notes.fold(0, (sum, note) => sum + note.text.runes.length),
    indexMilliseconds: index.elapsedMilliseconds,
    answers: answers,
  );
}
