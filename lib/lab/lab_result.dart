import 'device_info.dart';
import 'model_catalog.dart';
import 'prompts.dart';

/// Where the speed numbers of one answer came from, best first.
enum SpeedSource {
  /// Counted and timed inside the native library.
  runtimeCounters('runtime counters'),

  /// Token counts and timings the runtime attached to the answer.
  usage('runtime usage'),

  /// Timed by the app with a stopwatch, with tokens counted afterwards. Less
  /// exact: it includes the time the text takes to reach the app.
  stopwatch('stopwatch');

  const SpeedSource(this.label);

  final String label;
}

/// The answer to one request, with its measurements.
class PromptResult {
  const PromptResult({
    required this.promptId,
    required this.category,
    required this.language,
    required this.answerLanguage,
    required this.answer,
    required this.firstTextMs,
    required this.totalMs,
    this.promptTokens,
    this.answerTokens,
    this.readTokensPerSecond,
    this.writeTokensPerSecond,
    this.speedSource,
    this.thermalStatus,
    this.checkPassed,
    this.checkNote,
    this.error,
  });

  final String promptId;
  final LabCategory category;

  /// The language of the request's text.
  final String language;

  /// The language the answer is written in (differs for translations).
  final String answerLanguage;
  final String answer;

  /// Stopwatch time until the first text of the answer showed up. This is the
  /// wait the user feels.
  final int? firstTextMs;

  /// Stopwatch time for the whole answer.
  final int totalMs;

  /// Tokens the model read for this request.
  final int? promptTokens;

  /// Tokens it wrote.
  final int? answerTokens;

  /// Reading speed. Null when too little was read to measure it.
  final double? readTokensPerSecond;

  /// Writing speed. Null when too little was written to measure it.
  final double? writeTokensPerSecond;
  final SpeedSource? speedSource;

  /// The phone's heat level right after this answer.
  final int? thermalStatus;

  /// Quick add only: whether the date and time were right.
  final bool? checkPassed;
  final String? checkNote;

  /// What went wrong, when the request failed.
  final String? error;

  Map<String, Object?> toJson() => {
    'prompt_id': promptId,
    'category': category.name,
    'language': language,
    'answer_language': answerLanguage,
    'answer': answer,
    'first_text_ms': firstTextMs,
    'total_ms': totalMs,
    'prompt_tokens': promptTokens,
    'answer_tokens': answerTokens,
    'read_tokens_per_second': _round(readTokensPerSecond),
    'write_tokens_per_second': _round(writeTokensPerSecond),
    'speed_source': speedSource?.label,
    'thermal_status': thermalStatus,
    if (checkPassed != null) 'check_passed': checkPassed,
    if (checkNote != null) 'check_note': checkNote,
    if (error != null) 'error': error,
  };
}

/// One model measured once on one phone.
class LabRun {
  const LabRun({
    required this.appVersion,
    required this.engineVersion,
    required this.model,
    required this.requestedDevice,
    required this.contextSize,
    required this.startedAt,
    required this.finishedAt,
    required this.results,
    this.backendName,
    this.loadMs,
    this.loadError,
    this.warmUpMs,
    this.deviceAtStart,
    this.deviceAfterLoad,
    this.deviceAtEnd,
    this.peakAppMemoryBytes,
    this.peakThermalStatus,
    this.cancelled = false,
  });

  final String appVersion;

  /// The engine package and its version.
  final String engineVersion;
  final LabModel model;

  /// `cpu` or `gpu`, as asked for.
  final String requestedDevice;

  /// What the runtime says it is running on.
  final String? backendName;
  final int contextSize;
  final DateTime startedAt;
  final DateTime finishedAt;

  /// Time to load the model file into memory.
  final int? loadMs;

  /// Why the model did not load. When set there are no [results].
  final String? loadError;

  /// Time for a first tiny answer right after loading. One-time set-up costs
  /// land here instead of in the first measured request.
  final int? warmUpMs;
  final DeviceSnapshot? deviceAtStart;
  final DeviceSnapshot? deviceAfterLoad;
  final DeviceSnapshot? deviceAtEnd;

  /// The most memory the app held at any check during the run.
  final int? peakAppMemoryBytes;

  /// The hottest level the phone reported during the run.
  final int? peakThermalStatus;
  final List<PromptResult> results;

  /// Whether the run was stopped before the last request.
  final bool cancelled;

  Iterable<PromptResult> get _answered =>
      results.where((result) => result.error == null);

  /// Median reading speed over the requests long enough to measure it.
  double? get medianReadSpeed =>
      median(_answered.map((result) => result.readTokensPerSecond));

  /// Median writing speed over all answers, or over the answers written in
  /// one [language]. A translation counts under the language it produced.
  double? medianWriteSpeed({String? language}) => median(
    _answered
        .where(
          (result) => language == null || result.answerLanguage == language,
        )
        .map((result) => result.writeTokensPerSecond),
  );

  /// Median wait until the first text appeared, for the short requests (the
  /// two long speed requests would skew it).
  double? get medianFirstTextMs => median(
    _answered
        .where((result) => result.category != LabCategory.speed)
        .map((result) => result.firstTextMs?.toDouble()),
  );

  int get failedCount => results.where((result) => result.error != null).length;

  int get quickAddTotal =>
      results.where((result) => result.checkPassed != null).length;

  int get quickAddPassed =>
      results.where((result) => result.checkPassed == true).length;

  /// Memory the app gained by loading the model.
  int? get loadMemoryBytes {
    final before = deviceAtStart?.appMemoryBytes;
    final after = deviceAfterLoad?.appMemoryBytes;
    if (before == null || after == null || before == 0 || after == 0) {
      return null;
    }
    return after - before;
  }

  Duration get elapsed => finishedAt.difference(startedAt);

  /// A name for the saved file that sorts by time and says what was run.
  String get fileName {
    final stamp = startedAt
        .toUtc()
        .toIso8601String()
        .substring(0, 19)
        .replaceAll(':', '')
        .replaceAll('-', '');
    return 'zt-assist-$stamp-${model.id}-$requestedDevice.json';
  }

  /// The run in a few lines, for pasting into a chat.
  String summaryText() {
    final lines = <String>['ZT Assist phone test ($appVersion)'];
    final device = deviceAtStart;
    if (device != null) {
      lines.add(
        '${device.phoneName}, ${device.soc}, Android API ${device.sdk}, '
        '${formatGigabytes(device.totalRamBytes)} RAM',
      );
    }
    lines.add(
      'Model: ${model.title} on ${model.runtime.label}, '
      'asked for ${requestedDevice.toUpperCase()}'
      '${backendName == null ? '' : ', running on $backendName'}',
    );
    if (loadError != null) {
      lines.add('The model did not load: $loadError');
      return lines.join('\n');
    }
    lines.add(
      'Load ${formatSeconds(loadMs)}, first answer after load '
      '${formatSeconds(warmUpMs)}, wait before a short answer starts '
      '${formatSeconds(medianFirstTextMs?.round())}',
    );
    final hebrew = medianWriteSpeed(language: 'he');
    final english = medianWriteSpeed(language: 'en');
    lines.add(
      'Reads ${formatSpeed(medianReadSpeed)}, writes '
      '${formatSpeed(medianWriteSpeed())} '
      '(Hebrew ${formatSpeed(hebrew)}, English ${formatSpeed(english)})',
    );
    final gained = loadMemoryBytes;
    final peak = peakAppMemoryBytes;
    lines.add(
      'Memory: ${gained == null ? 'n/a' : '+${formatGigabytes(gained)}'} '
      'after load, peak ${peak == null ? 'n/a' : formatGigabytes(peak)}',
    );
    final end = deviceAtEnd;
    if (device != null && end != null) {
      lines.add(
        'Heat: ${thermalLabel(device.thermalStatus)} at the start, '
        '${thermalLabel(peakThermalStatus ?? end.thermalStatus)} at the '
        'worst. Battery ${device.batteryPercent}% to ${end.batteryPercent}%'
        '${end.charging ? ' (charging)' : ''}',
      );
    }
    if (quickAddTotal > 0) {
      lines.add(
        'Quick add: $quickAddPassed of $quickAddTotal dates and times right',
      );
    }
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;
    lines.add(
      '${results.length} requests in $minutes min $seconds s'
      '${failedCount == 0 ? '' : ', $failedCount failed'}'
      '${cancelled ? ' (stopped early)' : ''}',
    );
    return lines.join('\n');
  }

  Map<String, Object?> toJson() => {
    'format': 1,
    'app_version': appVersion,
    'engine': engineVersion,
    'model': {
      'id': model.id,
      'title': model.title,
      'runtime': model.runtime.label,
      'repo': model.repoId,
      'file': model.fileName,
      'bytes': model.bytes,
      'sha256': model.sha256,
    },
    'requested_device': requestedDevice,
    'backend': backendName,
    'context_size': contextSize,
    'started_at': startedAt.toUtc().toIso8601String(),
    'finished_at': finishedAt.toUtc().toIso8601String(),
    'cancelled': cancelled,
    'load_ms': loadMs,
    if (loadError != null) 'load_error': loadError,
    'warm_up_ms': warmUpMs,
    'device_at_start': deviceAtStart?.toJson(),
    'device_after_load': deviceAfterLoad?.toJson(),
    'device_at_end': deviceAtEnd?.toJson(),
    'peak_app_memory_bytes': peakAppMemoryBytes,
    'peak_thermal_status': peakThermalStatus,
    'summary': {
      'median_read_tokens_per_second': _round(medianReadSpeed),
      'median_write_tokens_per_second': _round(medianWriteSpeed()),
      'median_write_tokens_per_second_he': _round(
        medianWriteSpeed(language: 'he'),
      ),
      'median_write_tokens_per_second_en': _round(
        medianWriteSpeed(language: 'en'),
      ),
      'median_write_tokens_per_second_mixed': _round(
        medianWriteSpeed(language: 'mixed'),
      ),
      'median_first_text_ms': medianFirstTextMs?.round(),
      'load_memory_bytes': loadMemoryBytes,
      'quick_add_passed': quickAddPassed,
      'quick_add_total': quickAddTotal,
      'failed': failedCount,
      'text': summaryText(),
    },
    'results': [for (final result in results) result.toJson()],
  };
}

/// The middle value of [values], ignoring the missing ones. Null when there
/// are none.
double? median(Iterable<double?> values) {
  final sorted = values.whereType<double>().toList()..sort();
  if (sorted.isEmpty) return null;
  final middle = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[middle];
  return (sorted[middle - 1] + sorted[middle]) / 2;
}

/// "24 tok/s", or "n/a".
String formatSpeed(double? tokensPerSecond) {
  if (tokensPerSecond == null) return 'n/a';
  final digits = tokensPerSecond < 10 ? 1 : 0;
  return '${tokensPerSecond.toStringAsFixed(digits)} tok/s';
}

/// "3.2 s", or "n/a".
String formatSeconds(int? milliseconds) {
  if (milliseconds == null) return 'n/a';
  return '${(milliseconds / 1000).toStringAsFixed(1)} s';
}

/// "1.7 GB" (decimal gigabytes, like the phone's own settings).
String formatGigabytes(int bytes) =>
    '${(bytes / 1000000000).toStringAsFixed(1)} GB';

double? _round(double? value) =>
    value == null ? null : (value * 10).round() / 10;
