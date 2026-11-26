/// Shown in the app and written into every results file. Kept equal to the
/// version in `pubspec.yaml` by `test/app_info_test.dart`.
const String appVersion = '0.1.0';

/// The build number GitHub gave this APK, empty for a local build.
const String buildNumber = String.fromEnvironment('ZT_BUILD');

/// The version with its build, so results from two builds of the same version
/// can be told apart.
const String appVersionLabel = buildNumber == ''
    ? appVersion
    : '$appVersion build $buildNumber';

/// The engine package the models run on, written into every results file so
/// numbers from different builds can be told apart.
const String engineVersion = 'llamadart 0.20.7';
