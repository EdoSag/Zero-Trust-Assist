/// The fixed set of requests every model answers in the phone test.
///
/// Two long "speed" requests measure reading and writing speed. Forty short
/// ones cover the jobs the first features need (summarize, rewrite,
/// proofread, translate, quick add, titles, lists, questions) in Hebrew,
/// English and mixed text, so the answers of two models can be compared side
/// by side. The wording must not change between runs that are compared.
library;

/// What a request asks the model to do.
enum LabCategory {
  speed('Speed'),
  summarize('Summarize'),
  rewrite('Rewrite'),
  proofread('Proofread'),
  translate('Translate'),
  quickAdd('Quick add'),
  title('Title and tags'),
  list('Lists'),
  ask('Questions');

  const LabCategory(this.label);

  final String label;
}

/// One request of the test.
class LabPrompt {
  const LabPrompt({
    required this.id,
    required this.category,
    required this.language,
    required this.text,
    String? answerLanguage,
    this.maxTokens = 256,
    this.expectedDate,
    this.expectedTime,
    this.inQuickSet = false,
  }) : answerLanguage = answerLanguage ?? language;

  /// Stable name, used to line up answers from different runs.
  final String id;
  final LabCategory category;

  /// `he`, `en` or `mixed`.
  final String language;

  /// The language the answer is written in: the same as [language], except
  /// for translations. Writing speed is grouped by this one.
  final String answerLanguage;

  /// What the model is sent as the user's message.
  final String text;

  /// Cap on the answer's length.
  final int maxTokens;

  /// Quick add only: the date (`YYYY-MM-DD`) a correct answer names.
  final String? expectedDate;

  /// Quick add only: the time (`HH:MM`) a correct answer names, or `none`
  /// when the note has no time.
  final String? expectedTime;

  /// Whether the short version of the test includes this request.
  final bool inQuickSet;
}

/// Sent as the system message with every request.
const String labSystemPrompt =
    'You are ZT Assist, a writing and organizing assistant that runs on the '
    "user's phone. Do exactly what the user asks. Answer in the same language "
    "as the user's text unless asked to translate. Give only the result, with "
    'no introduction and no closing remark.';

/// The date the quick add requests are anchored to.
const String labToday = 'Tuesday, 2026-11-24';

const String _quickAddInstruction =
    'Today is $labToday. Turn the note below into JSON with exactly these '
    'keys: "type" ("task" or "event"), "title" (short, in the note\'s '
    'language), "date" (YYYY-MM-DD), "time" (HH:MM in 24-hour time, or null), '
    '"reminder_minutes_before" (a number, or null). Reply with the JSON '
    'only.\n\nNote: ';

const String _titleInstructionHe =
    'הצע כותרת קצרה (עד חמש מילים) ושלוש תגיות לפתק הבא. ענה בפורמט:\n'
    'כותרת: ...\nתגיות: ..., ..., ...\n\n';

const String _titleInstructionEn =
    'Suggest a short title (up to five words) and three tags for this note. '
    'Answer in the format:\nTitle: ...\nTags: ..., ..., ...\n\n';

const String _longEnglishNote = '''
Project kickoff notes, kitchen renovation

We met on Sunday evening with the contractor, the designer and the electrician to go over the plan for the kitchen. The work is planned to start on the first week of January and should take about five weeks if nothing unexpected turns up behind the walls. The contractor warned that in a building of this age there is a fair chance of finding old water pipes that need replacing, and he asked us to keep about ten percent of the budget aside for that.

The first week is demolition. The old cabinets, the countertop and the floor tiles all come out. We need to empty the kitchen completely before then and find somewhere to put the fridge, probably the living room. The contractor will cover the hallway floor and seal the doorway with plastic sheeting to keep the dust out of the rest of the apartment, but he said honestly that some dust always gets through.

The second week is plumbing and electricity. The sink moves to the wall under the window, which means new water and drain lines. The electrician wants to add a separate circuit for the oven and another for the dishwasher, and to replace the old fuse box while he is at it. He will send a separate quote for the fuse box by Thursday. We agreed on six double sockets above the countertop and two more on the island.

The third week is plastering, painting and the new floor. We chose the large grey tiles, sixty by sixty, and the designer will confirm that the supplier has enough from the same batch. The walls will be painted an off-white, and the wall behind the stove gets a glass panel instead of tiles because it is easier to clean.

The fourth and fifth weeks are the cabinets, the countertop and the appliances. The cabinets are being built to order and the carpenter needs final measurements by the fifteenth of December, so the designer will come on Wednesday morning to measure again. The countertop can only be measured after the cabinets are installed, and it takes about ten days to cut and deliver, so there will be roughly a week and a half with cabinets but no countertop and no sink. We should plan to eat simply during that time.

Money: the total quote is 92,000 shekels, not including appliances. We pay thirty percent when work starts, thirty percent after the plumbing and electricity pass inspection, thirty percent when the cabinets are installed and the last ten percent two weeks after everything is finished, once we have checked that nothing leaks and all the doors close properly. The appliances are a separate budget of about 18,000 shekels, and the designer suggested waiting for the end-of-year sales before ordering the oven and the dishwasher.

Open questions: whether to keep the gas stove or switch to induction, where exactly the island should stand so that two people can pass behind it, and whether the neighbors downstairs need to be told in writing about the noisy days. The contractor will send a written schedule by the end of the week, and we will answer the open questions by next Sunday.

Summarize these notes in five short bullet points.''';

const String _longHebrewNote = '''
סיכום פגישת תכנון, טיול משפחתי לצפון

נפגשנו אתמול בערב אצל סבא וסבתא כדי לתכנן את הטיול המשפחתי לצפון בחופשת חנוכה. בסוף הוחלט לנסוע לשלושה ימים, מיום שלישי עד יום חמישי, ולא לארבעה כמו שתכננו בהתחלה, כי דני צריך לחזור לעבודה ביום שישי בבוקר. נהיה בסך הכול אחד עשר אנשים: שישה מבוגרים וחמישה ילדים, והקטנה ביותר בת שנתיים.

לגבי הלינה, מיכל מצאה צימר גדול במושב ליד ראש פינה שיש בו ארבעה חדרי שינה, מטבח מאובזר וחצר עם פינת מנגל. המחיר הוא 2,400 שקלים ללילה לכל המשפחה, כולל ארוחת בוקר. בעל המקום ביקש מקדמה של אלף שקלים עד יום ראשון, ומיכל תעביר אותה ואחר כך נתחשבן בינינו. אם נבטל עד שבוע לפני ההגעה מקבלים את המקדמה בחזרה.

ביום הראשון ניסע ישר לשמורת החולה לראות את העגורים, כי בעונה הזאת יש שם עשרות אלפי ציפורים. צריך להזמין מראש את הסיור בעגלה, ואבא יטפל בזה מחר. ביום השני מתוכנן מסלול הליכה קצר בנחל שמתאים גם לעגלה של הקטנה, ואחריו ארוחת צהריים במסעדה בכפר הדרוזי. אם ירד גשם נלך במקום זה למוזיאון בקיבוץ. ביום השלישי נעצור בדרך הביתה בעכו העתיקה, נאכל חומוס בשוק ונצא לפני החושך כדי לא להיתקע בפקקים.

חלוקת משימות: רונן אחראי על הבשר והפחמים למנגל של הערב הראשון, נועה מביאה משחקי קופסה וחנוכייה עם נרות לכל הערבים, וסבתא התעקשה להכין סופגניות. כל משפחה מביאה מצעים לילדים ומגבות. צריך גם לבדוק שבשני הרכבים יש כיסאות בטיחות מתאימים, ולתאם מי נוסע עם מי.

נשאר פתוח: האם לשכור רכב שלישי או להצטופף בשניים, ומה עושים אם תחזית מזג האוויר תהיה גשומה לכל שלושת הימים. נחליט על זה בקבוצת המשפחה עד סוף השבוע.

סכם את הפתק בחמש נקודות קצרות.''';

/// The long English note without its closing request, for a test that
/// brings a request of its own.
final String labEnglishNote = _withoutLastLine(_longEnglishNote);

/// The long Hebrew note without its closing request.
final String labHebrewNote = _withoutLastLine(_longHebrewNote);

String _withoutLastLine(String note) =>
    note.substring(0, note.trimRight().lastIndexOf('\n')).trim();

/// Every request of the test, in the order it runs.
const List<LabPrompt> labPrompts = [
  // Speed. Long texts, so the reading speed is measured on real input.
  LabPrompt(
    id: 'speed-en',
    category: LabCategory.speed,
    language: 'en',
    text: _longEnglishNote,
    maxTokens: 220,
    inQuickSet: true,
  ),
  LabPrompt(
    id: 'speed-he',
    category: LabCategory.speed,
    language: 'he',
    text: _longHebrewNote,
    maxTokens: 220,
    inQuickSet: true,
  ),

  // Summarize.
  LabPrompt(
    id: 'sum-he-1',
    category: LabCategory.summarize,
    language: 'he',
    inQuickSet: true,
    text: '''
סכם את הפתק הבא בשלוש נקודות קצרות:

סיכום ישיבת ועד הבית מיום ראשון: השתתפו שבעה דיירים. הוחלט להחליף את דלת הכניסה לבניין לאחר שהמנעול נשבר פעמיים בחודש האחרון. התקבלו שלוש הצעות מחיר, והזולה ביותר עומדת על 4,200 שקלים כולל התקנה. רונית מקומה שלישית תתאם עם המתקין מועד בשבוע הבא. בנוסף עלה נושא הניקיון בחדר המדרגות: המנקה הנוכחי מגיע רק פעם בשבוע, והוצע לעבור לפעמיים בשבוע בתוספת של 150 שקלים לחודש לכל הבניין. ההצבעה על כך נדחתה לישיבה הבאה כי חסרו דיירים. לבסוף, יוסי הזכיר שתשלום ועד הבית לרבעון הבא צריך להגיע עד ה-10 בחודש.''',
  ),
  LabPrompt(
    id: 'sum-he-2',
    category: LabCategory.summarize,
    language: 'he',
    text: '''
סכם במשפט אחד או שניים:

דיברתי עם סוכנת הנסיעות לגבי הטיול ליוון בפסח. הטיסה הישירה לאתונה יוצאת ביום חמישי בבוקר וחוזרת ביום שלישי בערב, והמחיר לזוג הוא 1,850 שקלים כולל מזוודה אחת. המלון במרכז העיר עולה 420 שקלים ללילה עם ארוחת בוקר, אבל יש אפשרות זולה יותר ב-310 שקלים בלי ארוחת בוקר ובמרחק רבע שעה הליכה מהמרכז. היא ממליצה לסגור עד סוף השבוע כי המחירים עולים לקראת החג. צריך גם לבדוק שהדרכונים בתוקף לפחות חצי שנה מיום החזרה.''',
  ),
  LabPrompt(
    id: 'sum-en-1',
    category: LabCategory.summarize,
    language: 'en',
    text: '''
Summarize this note in three short bullet points:

Team sync, Monday. The mobile release is delayed by one week because the payment screen still crashes on older phones. Maya found the cause and expects a fix by Wednesday, after which testing needs two more days. Marketing asked us to keep the launch email ready but not to send it until the new date is confirmed. Tom will update the customers who were promised the feature this week. Separately, the office moves to the third floor on the 15th, and everyone should pack their desk by the 14th in the afternoon.''',
  ),
  LabPrompt(
    id: 'sum-en-2',
    category: LabCategory.summarize,
    language: 'en',
    text: '''
Summarize in one sentence:

Sourdough bread rises without commercial yeast. Instead it uses a starter, a mixture of flour and water that has been left to ferment so that wild yeast and bacteria grow in it. The bacteria produce acids that give the bread its sour taste and help it stay fresh longer, while the yeast produces the gas that makes the dough rise. Because this process is slow, a sourdough loaf usually takes a full day to make, most of it waiting.''',
  ),
  LabPrompt(
    id: 'sum-mix-1',
    category: LabCategory.summarize,
    language: 'mixed',
    text: '''
סכם בשתי נקודות קצרות:

סיכום ה-sprint: סיימנו את ה-login flow החדש ואת ה-migration של ה-database, אבל ה-dashboard עדיין לא מוכן כי חיכינו ל-API מהצוות של יעל. ה-QA מצא שלושה bugs ב-checkout, שניים מהם כבר תוקנו. ב-sprint הבא נתמקד ב-dashboard וב-performance של מסך הבית, ונעשה demo ללקוח ביום חמישי.''',
  ),

  // Rewrite.
  LabPrompt(
    id: 'rw-he-1',
    category: LabCategory.rewrite,
    language: 'he',
    inQuickSet: true,
    text: '''
נסח מחדש את ההודעה הבאה בצורה מנומסת ורשמית, מתאימה למייל לבעל הדירה:

היי, המזגן בסלון שוב לא עובד וכבר שבוע שאני מחכה שתשלח מישהו. חם פה בטירוף. מתי זה מסתדר?''',
  ),
  LabPrompt(
    id: 'rw-he-2',
    category: LabCategory.rewrite,
    language: 'he',
    text: '''
קצר את הטקסט הבא לחצי מאורכו בלי לאבד את המידע החשוב:

רציתי לעדכן את כולם שבעקבות השיפוצים שמתבצעים בימים אלה בקומה השנייה של הבניין, ישיבת הצוות השבועית שלנו, שמתקיימת בדרך כלל בימי שני בשעה עשר בבוקר בחדר הישיבות הגדול, תעבור החל מהשבוע הבא ועד להודעה חדשה לימי שלישי בשעה אחת עשרה, ותתקיים בחדר הישיבות הקטן שבקומת הכניסה, ליד המטבחון.''',
  ),
  LabPrompt(
    id: 'rw-he-3',
    category: LabCategory.rewrite,
    language: 'he',
    text: '''
נסח מחדש בטון חם וידידותי:

לכל העובדים: החל מיום ראשון חל איסור על חניה ברחבה הקדמית. רכב שיחנה שם ייגרר על חשבון בעליו.''',
  ),
  LabPrompt(
    id: 'rw-en-1',
    category: LabCategory.rewrite,
    language: 'en',
    text: '''
Rewrite this to be polite and professional:

You sent the wrong invoice again. Fix it today, I'm not paying until it's right.''',
  ),
  LabPrompt(
    id: 'rw-en-2',
    category: LabCategory.rewrite,
    language: 'en',
    text: '''
Rewrite this in simpler words that a ten-year-old would understand:

Photosynthesis is the process by which plants convert light energy into chemical energy, synthesizing glucose from carbon dioxide and water while releasing oxygen as a byproduct.''',
  ),

  // Proofread.
  LabPrompt(
    id: 'pr-he-1',
    category: LabCategory.proofread,
    language: 'he',
    inQuickSet: true,
    text: '''
תקן שגיאות כתיב והקלדה בטקסט הבא והחזר רק את הטקסט המתוקן:

שלום רב, רצתי לברר האם אפשר לדחות את הפגישה שנקבה ליום רבעי בשעה עשר. יש לי התנגשות עם תור לרופה ואשמח לקבוע מועד חלופי בהקדם האפשרי.''',
  ),
  LabPrompt(
    id: 'pr-he-2',
    category: LabCategory.proofread,
    language: 'he',
    text: '''
תקן שגיאות כתיב ופיסוק והחזר רק את הטקסט המתוקן:

אתמול הלכנו לים עם הילדים היה ממש כייף אבל שחכנו להביא קרם הגנה וכולם נשרפו. בפעם הבאה אנחנו צרכים להכין רשימה מראש''',
  ),
  LabPrompt(
    id: 'pr-he-3',
    category: LabCategory.proofread,
    language: 'he',
    text: '''
תקן שגיאות והחזר רק את הטקסט המתוקן:

המשלוח אמור להגיעה מחר בין השעות 8 ל12. אם אתה לא בבית השליח ישעיר את החבילה אצל השכן או שיחזיר אותה לסניף הדואר הקרוב''',
  ),
  LabPrompt(
    id: 'pr-en-1',
    category: LabCategory.proofread,
    language: 'en',
    text: '''
Fix the spelling and grammar mistakes and return only the corrected text:

I recieved you're message yesterday but I didnt had time to answer. Can we meat on thursday insted of wendsday?''',
  ),
  LabPrompt(
    id: 'pr-en-2',
    category: LabCategory.proofread,
    language: 'en',
    text: '''
Fix the mistakes and return only the corrected text:

The team have finish the report and send it to the manger last friday, however their is still some number's that needs to be check.''',
  ),

  // Translate.
  LabPrompt(
    id: 'tr-he-en-1',
    category: LabCategory.translate,
    answerLanguage: 'en',
    language: 'he',
    inQuickSet: true,
    text: '''
תרגם לאנגלית:

תודה רבה על ההזמנה לחתונה. לצערנו לא נוכל להגיע כי נהיה בחו"ל באותו שבוע, אבל נשמח מאוד לחגוג איתכם כשנחזור.''',
  ),
  LabPrompt(
    id: 'tr-he-en-2',
    category: LabCategory.translate,
    answerLanguage: 'en',
    language: 'he',
    text: '''
תרגם לאנגלית:

החבילה שהזמנתי לפני שבועיים עדיין לא הגיעה. מספר ההזמנה הוא 48213. אבקש לקבל עדכון על מצב המשלוח או החזר כספי מלא.''',
  ),
  LabPrompt(
    id: 'tr-en-he-1',
    category: LabCategory.translate,
    answerLanguage: 'he',
    language: 'en',
    inQuickSet: true,
    text: '''
Translate to Hebrew:

Your appointment is confirmed for Monday at 3:30 PM. Please arrive ten minutes early and bring your ID card and any previous test results.''',
  ),
  LabPrompt(
    id: 'tr-en-he-2',
    category: LabCategory.translate,
    answerLanguage: 'he',
    language: 'en',
    text: '''
Translate to Hebrew:

We are sorry, but the item you ordered is out of stock. You can wait about two weeks for the next delivery, choose a different color, or cancel the order for a full refund.''',
  ),
  LabPrompt(
    id: 'tr-en-he-3',
    category: LabCategory.translate,
    answerLanguage: 'he',
    language: 'en',
    text: '''
Translate to Hebrew:

The weather will be sunny tomorrow morning, with a chance of rain in the evening. Don't forget to take an umbrella if you plan to stay out late.''',
  ),

  // Quick add. The answer must be JSON; the date and time are checked.
  LabPrompt(
    id: 'qa-he-1',
    category: LabCategory.quickAdd,
    language: 'he',
    inQuickSet: true,
    maxTokens: 120,
    expectedDate: '2026-11-25',
    expectedTime: '09:00',
    text: '$_quickAddInstructionמחר ב-9 רופא שיניים, להזכיר שעה לפני',
  ),
  LabPrompt(
    id: 'qa-he-2',
    category: LabCategory.quickAdd,
    language: 'he',
    maxTokens: 120,
    expectedDate: '2026-11-27',
    expectedTime: 'none',
    text: '$_quickAddInstructionלקנות מתנה ליום ההולדת של אמא עד יום שישי',
  ),
  LabPrompt(
    id: 'qa-he-3',
    category: LabCategory.quickAdd,
    language: 'he',
    maxTokens: 120,
    expectedDate: '2026-11-29',
    expectedTime: '16:30',
    text:
        '$_quickAddInstructionפגישה עם רואה החשבון ביום ראשון הבא בארבע וחצי אחר הצהריים',
  ),
  LabPrompt(
    id: 'qa-en-1',
    category: LabCategory.quickAdd,
    language: 'en',
    maxTokens: 120,
    expectedDate: '2026-11-26',
    expectedTime: '14:00',
    text:
        '${_quickAddInstruction}Call the insurance company on Thursday at 2pm, remind me 15 minutes before',
  ),
  LabPrompt(
    id: 'qa-mix-1',
    category: LabCategory.quickAdd,
    language: 'mixed',
    maxTokens: 120,
    expectedDate: '2026-12-01',
    expectedTime: 'none',
    text: '$_quickAddInstructionלשלוח את ה-invoice ל-David עד ה-1 בדצמבר',
  ),

  // Title and tags.
  LabPrompt(
    id: 'tl-he-1',
    category: LabCategory.title,
    language: 'he',
    inQuickSet: true,
    maxTokens: 80,
    text:
        '${_titleInstructionHe}2 כוסות קמח, כפית אבקת אפייה, חצי כוס סוכר, 2 ביצים, כוס חלב, 50 גרם חמאה מומסת. לערבב יבשים, להוסיף רטובים, לטגן על מחבת חמה עד שמזהיב משני הצדדים. סבתא תמיד הוסיפה קצת וניל.',
  ),
  LabPrompt(
    id: 'tl-he-2',
    category: LabCategory.title,
    language: 'he',
    maxTokens: 80,
    text:
        '$_titleInstructionHeהטסט לרכב עד סוף ינואר. לפני זה צריך להחליף צמיגים קדמיים ולבדוק את הבלמים. המוסך של אבי נתן הצעה של 1,400 שקלים. הביטוח מתחדש בפברואר, לבקש הצעות מחיר משלוש חברות.',
  ),
  LabPrompt(
    id: 'tl-en-1',
    category: LabCategory.title,
    language: 'en',
    maxTokens: 80,
    text:
        '${_titleInstructionEn}Monday: 5 km run, easy pace. Wednesday: upper body, 3 sets of push-ups, rows and shoulder press. Friday: long run, try for 10 km. Stretch after every session and drink more water. Goal is the half marathon in March.',
  ),
  LabPrompt(
    id: 'tl-en-2',
    category: LabCategory.title,
    language: 'en',
    maxTokens: 80,
    text:
        '${_titleInstructionEn}Finished the book about sleep. Main points: keep the same bedtime every day, no caffeine after noon, the bedroom should be cool and dark, and screens in the last hour make it harder to fall asleep. Want to try the fixed bedtime for two weeks and see if mornings get easier.',
  ),
  LabPrompt(
    id: 'tl-mix-1',
    category: LabCategory.title,
    language: 'mixed',
    maxTokens: 80,
    text:
        '$_titleInstructionHeרעיונות ל-app חדש: מעקב אחרי subscriptions חודשיים, התראה לפני חידוש, סיכום הוצאות בגרף. לבדוק אם יש API של הבנקים. לדבר עם נועה על ה-design.',
  ),

  // Lists.
  LabPrompt(
    id: 'cl-he-1',
    category: LabCategory.list,
    language: 'he',
    inQuickSet: true,
    text: '''
הפוך את הפתק הבא לרשימת משימות, משימה אחת בכל שורה:

לקראת המעבר לדירה החדשה צריך להזמין מובילים, להעביר את חשבון החשמל והמים על השם שלנו, לעדכן כתובת בבנק ובקופת החולים, ולקנות וילונות לסלון. גם לא לשכוח להחזיר את המפתחות לבעל הדירה הישן עד סוף החודש.''',
  ),
  LabPrompt(
    id: 'cl-he-2',
    category: LabCategory.list,
    language: 'he',
    text: '''
מה צריך לעשות לפי ההודעה הבאה, ועד מתי? ענה ברשימה קצרה:

הורים יקרים, טיול שנתי של כיתה ד' יתקיים ביום שלישי ה-8 בדצמבר. יש להחזיר אישור הורים חתום עד יום חמישי הקרוב ולהעביר תשלום של 85 שקלים דרך האפליקציה עד יום ראשון. ביום הטיול יש להגיע עם כובע, שלושה ליטרים מים ונעליים סגורות.''',
  ),
  LabPrompt(
    id: 'cl-he-3',
    category: LabCategory.list,
    language: 'he',
    text: '''
כתוב רשימת קניות לפי הטקסט הבא, פריט בכל שורה:

לארוחת שישי אני רוצה להכין עוף בתנור עם תפוחי אדמה ובצל, סלט ירקות עם עגבניות, מלפפונים ופלפל אדום, ולקינוח סלט פירות עם תפוחים, בננות ותפוזים. חסר לנו גם שמן זית וחלות.''',
  ),
  LabPrompt(
    id: 'cl-en-1',
    category: LabCategory.list,
    language: 'en',
    text: '''
Turn this note into a to-do list, one task per line:

Before the trip I need to renew my passport, book the airport taxi, ask Dana to water the plants and pick up the mail, buy travel insurance, and download the maps for offline use.''',
  ),
  LabPrompt(
    id: 'cl-en-2',
    category: LabCategory.list,
    language: 'en',
    text: '''
What do I need to do according to this message, and by when? Answer as a short list:

Hi all, the quarterly report is due on December 4. Please send me your team's numbers by Monday, review the draft I will share on Wednesday, and confirm your attendance at the review meeting by Friday.''',
  ),

  // Questions.
  LabPrompt(
    id: 'ask-he-1',
    category: LabCategory.ask,
    language: 'he',
    inQuickSet: true,
    text: '''
ענה על השאלה לפי הטקסט בלבד.

טקסט: הספרייה העירונית פתוחה בימים ראשון עד חמישי משעה 9:00 עד 19:00, וביום שישי משעה 9:00 עד 13:00. בשבת הספרייה סגורה. ניתן לשאול עד חמישה ספרים לשלושה שבועות, ולהאריך את ההשאלה פעם אחת דרך האתר.

שאלה: עד איזו שעה הספרייה פתוחה ביום שישי, וכמה ספרים אפשר לשאול?''',
  ),
  LabPrompt(
    id: 'ask-he-2',
    category: LabCategory.ask,
    language: 'he',
    text:
        'הסבר בשניים-שלושה משפטים פשוטים מה ההבדל בין ריבית קבועה לריבית משתנה במשכנתא.',
  ),
  LabPrompt(
    id: 'ask-en-1',
    category: LabCategory.ask,
    language: 'en',
    text: '''
Answer the question using only the text.

Text: The warranty covers manufacturing defects for 24 months from the purchase date. It does not cover water damage, broken screens or battery wear. To make a claim, bring the device and the receipt to an authorized service center.

Question: Is a cracked screen covered, and what do I need to bring to make a claim?''',
  ),
  LabPrompt(
    id: 'ask-en-2',
    category: LabCategory.ask,
    language: 'en',
    text:
        'Give me three practical tips for falling asleep faster. Keep each tip to one sentence.',
  ),
  LabPrompt(
    id: 'ask-mix-1',
    category: LabCategory.ask,
    language: 'mixed',
    text:
        'כתוב הודעת WhatsApp קצרה לצוות שמודיעה שה-deploy נדחה ליום חמישי בגלל bug ב-payment flow.',
  ),
];

/// The two long requests alone: under a minute, for comparing settings.
List<LabPrompt> get labSpeedPrompts => labPrompts
    .where((prompt) => prompt.category == LabCategory.speed)
    .toList(growable: false);

/// The requests of the short test: both speed requests and one or two from
/// each kind of job.
List<LabPrompt> get labQuickPrompts =>
    labPrompts.where((prompt) => prompt.inQuickSet).toList(growable: false);
