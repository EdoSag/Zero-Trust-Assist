// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'ZT Assist';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get settings => 'Settings';

  @override
  String get chatNew => 'New chat';

  @override
  String get chatHint => 'Ask anything';

  @override
  String get chatSend => 'Send';

  @override
  String get chatStop => 'Stop';

  @override
  String get chatStopped => 'Stopped before the end';

  @override
  String get chatLoadingModel =>
      'Loading the model. The first answer takes a few seconds longer.';

  @override
  String get chatThinking => 'Thinking…';

  @override
  String get chatEmptyTitle => 'How can I help?';

  @override
  String get chatEmptyHint =>
      'Answers are written on this phone, without a server. Nothing you type leaves it.';

  @override
  String get chatDisclaimer =>
      'Answers can be wrong. Check anything important.';

  @override
  String get chatListEmpty =>
      'Your chats will show here. They are encrypted and synced to your other devices.';

  @override
  String get chatUntitled => 'Chat';

  @override
  String get chatRename => 'Rename';

  @override
  String get chatDeleteTitle => 'Delete this chat?';

  @override
  String get chatDeleteBody =>
      'It is deleted from all your devices and cannot be brought back.';

  @override
  String get problemModelMissing =>
      'The model is not on this phone. Download it again or pick the other one.';

  @override
  String get problemLoadFailed =>
      'The model could not be loaded. Close other apps to free memory and try again.';

  @override
  String get problemAnswerFailed =>
      'The answer stopped because of an error. Try again.';

  @override
  String get problemSaveFailed => 'This chat could not be saved.';

  @override
  String get setupTitle => 'Choose your model';

  @override
  String get setupIntro =>
      'ZT Assist answers on this phone, without a server, so what you write never leaves it. For that it downloads a model once. You can switch later in Settings.';

  @override
  String setupLowMemory(String gigabytes) {
    return 'This phone has $gigabytes GB of memory. ZT Assist is made for 8 GB or more, so it may be slow or close by itself here.';
  }

  @override
  String get setupSource =>
      'The models are Gemma 4 by Google, free to use (Apache 2.0 licence). They are downloaded from huggingface.co and checked before use. Use Wi-Fi: the files are large.';

  @override
  String get setupStart => 'Start chatting';

  @override
  String get modelSmall => 'Small model';

  @override
  String get modelLarge => 'Large model';

  @override
  String get modelSmallHint =>
      'Faster, and enough for most everyday questions.';

  @override
  String get modelLargeHint =>
      'Better answers, but slower. For phones with 12 GB of memory or more.';

  @override
  String get modelRecommended => 'Suits this phone';

  @override
  String modelDetails(String name, String gigabytes) {
    return '$name, $gigabytes GB';
  }

  @override
  String get modelDownload => 'Download';

  @override
  String get modelTryAgain => 'Try again';

  @override
  String modelDownloading(String done, String total) {
    return 'Downloading: $done of $total GB';
  }

  @override
  String get modelChecking => 'Checking the file…';

  @override
  String get modelOnPhone => 'On this phone';

  @override
  String get modelDownloadFailed =>
      'The download did not finish. It continues where it stopped.';

  @override
  String get modelInUse => 'The model is in use. Close the phone test first.';

  @override
  String modelNoSpace(String gigabytes) {
    return 'Not enough free space: only $gigabytes GB is free.';
  }

  @override
  String get modelDeleteTitle => 'Delete this model?';

  @override
  String modelDeleteBody(String gigabytes) {
    return 'This frees $gigabytes GB. Your chats stay. You can download the model again later.';
  }

  @override
  String get modelsIntro =>
      'The model that writes the answers. Tap one that is on this phone to use it.';

  @override
  String get settingsModel => 'Model';

  @override
  String get settingsModelNone => 'Not chosen yet';

  @override
  String get settingsPhoneTest => 'Phone test';

  @override
  String get settingsPhoneTestHint =>
      'Measures how fast the models run on this phone. In English.';
}
