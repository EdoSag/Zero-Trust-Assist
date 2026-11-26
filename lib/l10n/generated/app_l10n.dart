import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_l10n_en.dart';
import 'app_l10n_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('he'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'ZT Assist'**
  String get appName;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @chatNew.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get chatNew;

  /// No description provided for @chatHint.
  ///
  /// In en, this message translates to:
  /// **'Ask anything'**
  String get chatHint;

  /// No description provided for @chatSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSend;

  /// No description provided for @chatStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get chatStop;

  /// No description provided for @chatStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped before the end'**
  String get chatStopped;

  /// No description provided for @chatLoadingModel.
  ///
  /// In en, this message translates to:
  /// **'Loading the model. The first answer takes a few seconds longer.'**
  String get chatLoadingModel;

  /// No description provided for @chatThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking…'**
  String get chatThinking;

  /// No description provided for @chatEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'How can I help?'**
  String get chatEmptyTitle;

  /// No description provided for @chatEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Answers are written on this phone, without a server. Nothing you type leaves it.'**
  String get chatEmptyHint;

  /// No description provided for @chatDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Answers can be wrong. Check anything important.'**
  String get chatDisclaimer;

  /// No description provided for @chatListEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your chats will show here. They are encrypted and synced to your other devices.'**
  String get chatListEmpty;

  /// No description provided for @chatUntitled.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatUntitled;

  /// No description provided for @chatRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get chatRename;

  /// No description provided for @chatDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this chat?'**
  String get chatDeleteTitle;

  /// No description provided for @chatDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'It is deleted from all your devices and cannot be brought back.'**
  String get chatDeleteBody;

  /// No description provided for @problemModelMissing.
  ///
  /// In en, this message translates to:
  /// **'The model is not on this phone. Download it again or pick the other one.'**
  String get problemModelMissing;

  /// No description provided for @problemLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'The model could not be loaded. Close other apps to free memory and try again.'**
  String get problemLoadFailed;

  /// No description provided for @problemAnswerFailed.
  ///
  /// In en, this message translates to:
  /// **'The answer stopped because of an error. Try again.'**
  String get problemAnswerFailed;

  /// No description provided for @problemSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'This chat could not be saved.'**
  String get problemSaveFailed;

  /// No description provided for @setupTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your model'**
  String get setupTitle;

  /// No description provided for @setupIntro.
  ///
  /// In en, this message translates to:
  /// **'ZT Assist answers on this phone, without a server, so what you write never leaves it. For that it downloads a model once. You can switch later in Settings.'**
  String get setupIntro;

  /// No description provided for @setupLowMemory.
  ///
  /// In en, this message translates to:
  /// **'This phone has {gigabytes} GB of memory. ZT Assist is made for 8 GB or more, so it may be slow or close by itself here.'**
  String setupLowMemory(String gigabytes);

  /// No description provided for @setupSource.
  ///
  /// In en, this message translates to:
  /// **'The models are Gemma 4 by Google, free to use (Apache 2.0 licence). They are downloaded from huggingface.co and checked before use. Use Wi-Fi: the files are large.'**
  String get setupSource;

  /// No description provided for @setupStart.
  ///
  /// In en, this message translates to:
  /// **'Start chatting'**
  String get setupStart;

  /// No description provided for @modelSmall.
  ///
  /// In en, this message translates to:
  /// **'Small model'**
  String get modelSmall;

  /// No description provided for @modelLarge.
  ///
  /// In en, this message translates to:
  /// **'Large model'**
  String get modelLarge;

  /// No description provided for @modelSmallHint.
  ///
  /// In en, this message translates to:
  /// **'Faster, and enough for most everyday questions.'**
  String get modelSmallHint;

  /// No description provided for @modelLargeHint.
  ///
  /// In en, this message translates to:
  /// **'Better answers, but slower. For phones with 12 GB of memory or more.'**
  String get modelLargeHint;

  /// No description provided for @modelRecommended.
  ///
  /// In en, this message translates to:
  /// **'Suits this phone'**
  String get modelRecommended;

  /// No description provided for @modelDetails.
  ///
  /// In en, this message translates to:
  /// **'{name}, {gigabytes} GB'**
  String modelDetails(String name, String gigabytes);

  /// No description provided for @modelDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get modelDownload;

  /// No description provided for @modelTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get modelTryAgain;

  /// No description provided for @modelDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading: {done} of {total} GB'**
  String modelDownloading(String done, String total);

  /// No description provided for @modelChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking the file…'**
  String get modelChecking;

  /// No description provided for @modelOnPhone.
  ///
  /// In en, this message translates to:
  /// **'On this phone'**
  String get modelOnPhone;

  /// No description provided for @modelDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'The download did not finish. It continues where it stopped.'**
  String get modelDownloadFailed;

  /// No description provided for @modelInUse.
  ///
  /// In en, this message translates to:
  /// **'The model is in use. Close the phone test first.'**
  String get modelInUse;

  /// No description provided for @modelNoSpace.
  ///
  /// In en, this message translates to:
  /// **'Not enough free space: only {gigabytes} GB is free.'**
  String modelNoSpace(String gigabytes);

  /// No description provided for @modelDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this model?'**
  String get modelDeleteTitle;

  /// No description provided for @modelDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This frees {gigabytes} GB. Your chats stay. You can download the model again later.'**
  String modelDeleteBody(String gigabytes);

  /// No description provided for @modelsIntro.
  ///
  /// In en, this message translates to:
  /// **'The model that writes the answers. Tap one that is on this phone to use it.'**
  String get modelsIntro;

  /// No description provided for @settingsModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get settingsModel;

  /// No description provided for @settingsModelNone.
  ///
  /// In en, this message translates to:
  /// **'Not chosen yet'**
  String get settingsModelNone;

  /// No description provided for @settingsPhoneTest.
  ///
  /// In en, this message translates to:
  /// **'Phone test'**
  String get settingsPhoneTest;

  /// No description provided for @settingsPhoneTestHint.
  ///
  /// In en, this message translates to:
  /// **'Measures how fast the models run on this phone. In English.'**
  String get settingsPhoneTestHint;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
    case 'he':
      return AppL10nHe();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
