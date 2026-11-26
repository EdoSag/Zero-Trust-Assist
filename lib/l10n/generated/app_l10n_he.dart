// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class AppL10nHe extends AppL10n {
  AppL10nHe([String locale = 'he']) : super(locale);

  @override
  String get appName => 'ZT Assist';

  @override
  String get cancel => 'ביטול';

  @override
  String get close => 'סגירה';

  @override
  String get copy => 'העתקה';

  @override
  String get copied => 'הועתק';

  @override
  String get delete => 'מחיקה';

  @override
  String get save => 'שמירה';

  @override
  String get settings => 'הגדרות';

  @override
  String get chatNew => 'שיחה חדשה';

  @override
  String get chatHint => 'אפשר לשאול כל דבר';

  @override
  String get chatSend => 'שליחה';

  @override
  String get chatStop => 'עצירה';

  @override
  String get chatStopped => 'נעצר לפני הסוף';

  @override
  String get chatLoadingModel =>
      'המודל נטען. התשובה הראשונה לוקחת כמה שניות יותר.';

  @override
  String get chatThinking => 'חושב…';

  @override
  String get chatEmptyTitle => 'במה אפשר לעזור?';

  @override
  String get chatEmptyHint =>
      'התשובות נכתבות בטלפון הזה, בלי שרת. שום דבר שתכתבו לא יוצא ממנו.';

  @override
  String get chatDisclaimer =>
      'תשובות יכולות להיות שגויות. כדאי לבדוק כל דבר חשוב.';

  @override
  String get chatListEmpty =>
      'השיחות שלך יופיעו כאן. הן מוצפנות ומסונכרנות למכשירים האחרים שלך.';

  @override
  String get chatUntitled => 'שיחה';

  @override
  String get chatRename => 'שינוי שם';

  @override
  String get chatDeleteTitle => 'למחוק את השיחה?';

  @override
  String get chatDeleteBody =>
      'היא תימחק מכל המכשירים שלך ולא ניתן יהיה לשחזר אותה.';

  @override
  String get problemModelMissing =>
      'המודל לא נמצא בטלפון הזה. אפשר להוריד אותו שוב או לבחור במודל השני.';

  @override
  String get problemLoadFailed =>
      'לא ניתן היה לטעון את המודל. כדאי לסגור אפליקציות אחרות כדי לפנות זיכרון ולנסות שוב.';

  @override
  String get problemAnswerFailed => 'התשובה נעצרה בגלל שגיאה. אפשר לנסות שוב.';

  @override
  String get problemSaveFailed => 'לא ניתן היה לשמור את השיחה.';

  @override
  String get setupTitle => 'בחירת מודל';

  @override
  String get setupIntro =>
      'ZT Assist עונה בטלפון הזה, בלי שרת, ולכן מה שתכתבו לא יוצא ממנו. לשם כך הוא מוריד מודל פעם אחת. אפשר להחליף אחר כך בהגדרות.';

  @override
  String setupLowMemory(String gigabytes) {
    return 'בטלפון הזה יש $gigabytes ג״ב זיכרון. ZT Assist מיועד ל־8 ג״ב ומעלה, ולכן כאן הוא עלול להיות איטי או להיסגר מעצמו.';
  }

  @override
  String get setupSource =>
      'המודלים הם Gemma 4 של Google, חופשיים לשימוש (רישיון Apache 2.0). הם יורדים מ־huggingface.co ונבדקים לפני השימוש. מומלץ Wi-Fi: הקבצים גדולים.';

  @override
  String get setupStart => 'להתחיל לשוחח';

  @override
  String get modelSmall => 'מודל קטן';

  @override
  String get modelLarge => 'מודל גדול';

  @override
  String get modelSmallHint => 'מהיר יותר, ומספיק לרוב השאלות היומיומיות.';

  @override
  String get modelLargeHint =>
      'תשובות טובות יותר, אבל איטי יותר. לטלפונים עם 12 ג״ב זיכרון ומעלה.';

  @override
  String get modelRecommended => 'מתאים לטלפון הזה';

  @override
  String modelDetails(String name, String gigabytes) {
    return '$name, $gigabytes ג״ב';
  }

  @override
  String get modelDownload => 'הורדה';

  @override
  String get modelTryAgain => 'לנסות שוב';

  @override
  String modelDownloading(String done, String total) {
    return 'מוריד: $done מתוך $total ג״ב';
  }

  @override
  String get modelChecking => 'בודק את הקובץ…';

  @override
  String get modelOnPhone => 'נמצא בטלפון';

  @override
  String get modelDownloadFailed =>
      'ההורדה לא הסתיימה. היא תמשיך מהמקום שבו נעצרה.';

  @override
  String get modelInUse => 'המודל בשימוש. יש לסגור קודם את בדיקת הטלפון.';

  @override
  String modelNoSpace(String gigabytes) {
    return 'אין מספיק מקום פנוי: רק $gigabytes ג״ב פנויים.';
  }

  @override
  String get modelDeleteTitle => 'למחוק את המודל?';

  @override
  String modelDeleteBody(String gigabytes) {
    return 'הפעולה תפנה $gigabytes ג״ב. השיחות שלך נשארות. אפשר להוריד את המודל שוב אחר כך.';
  }

  @override
  String get modelsIntro =>
      'המודל שכותב את התשובות. הקישו על מודל שנמצא בטלפון כדי להשתמש בו.';

  @override
  String get settingsModel => 'מודל';

  @override
  String get settingsModelNone => 'עדיין לא נבחר';

  @override
  String get settingsPhoneTest => 'בדיקת טלפון';

  @override
  String get settingsPhoneTestHint =>
      'מודדת כמה מהר המודלים רצים בטלפון הזה. באנגלית.';
}
