import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_assist/lab/lab_result.dart';
import 'package:zerotrust_assist/lab/model_catalog.dart';
import 'package:zerotrust_assist/lab/prompts.dart';
import 'package:zerotrust_assist/lab/result_store.dart';

PromptResult _result(
  String id, {
  String language = 'en',
  LabCategory category = LabCategory.summarize,
  double? read,
  double? write,
  int? firstTextMs = 500,
  bool? check,
  String? error,
}) {
  return PromptResult(
    promptId: id,
    category: category,
    language: language,
    answer: 'answer $id',
    firstTextMs: firstTextMs,
    totalMs: 2000,
    readTokensPerSecond: read,
    writeTokensPerSecond: write,
    speedSource: SpeedSource.runtimeCounters,
    checkPassed: check,
    error: error,
  );
}

LabRun _run(List<PromptResult> results, {bool cancelled = false}) {
  return LabRun(
    appVersion: '0.1.0',
    engineVersion: 'fake 1.0',
    model: labModels.first,
    requestedDevice: 'cpu',
    backendName: 'CPU',
    contextSize: 4096,
    startedAt: DateTime.utc(2026, 11, 24, 18, 5, 9),
    finishedAt: DateTime.utc(2026, 11, 24, 18, 9, 39),
    loadMs: 3200,
    warmUpMs: 900,
    results: results,
    cancelled: cancelled,
  );
}

void main() {
  test('median ignores missing values', () {
    expect(median([]), isNull);
    expect(median([null, null]), isNull);
    expect(median([3, null, 1, 2]), 2);
    expect(median([4, 1, 3, 2]), 2.5);
  });

  test('formats speeds, times and sizes', () {
    expect(formatSpeed(null), 'n/a');
    expect(formatSpeed(24.4), '24 tok/s');
    expect(formatSpeed(8.26), '8.3 tok/s');
    expect(formatSeconds(3240), '3.2 s');
    expect(formatSeconds(null), 'n/a');
    expect(formatGigabytes(2588147712), '2.6 GB');
  });

  test('summarizes speeds overall and per language', () {
    final run = _run([
      _result('a', language: 'en', read: 300, write: 26),
      _result('b', language: 'he', read: 280, write: 20),
      _result('c', language: 'he', write: 22),
      _result('d', language: 'he', write: 99, error: 'failed'),
      _result('e', category: LabCategory.quickAdd, check: true),
      _result('f', category: LabCategory.quickAdd, check: false),
    ]);
    expect(run.medianReadSpeed, 290);
    expect(run.medianWriteSpeed(), 22);
    expect(run.medianWriteSpeed(language: 'he'), 21);
    expect(run.medianWriteSpeed(language: 'en'), 26);
    expect(run.failedCount, 1);
    expect(run.quickAddPassed, 1);
    expect(run.quickAddTotal, 2);

    final summary = run.summaryText();
    expect(summary, contains('Gemma 4 E2B on LiteRT-LM'));
    expect(summary, contains('running on CPU'));
    expect(summary, contains('Reads 290 tok/s, writes 22 tok/s'));
    expect(summary, contains('Hebrew 21 tok/s, English 26 tok/s'));
    expect(summary, contains('Quick add: 1 of 2'));
    expect(summary, contains('6 requests in 4 min 30 s, 1 failed'));
  });

  test('the long speed requests do not count in the wait for first text', () {
    final run = _run([
      _result('speed', category: LabCategory.speed, firstTextMs: 9000),
      _result('a', firstTextMs: 400),
      _result('b', firstTextMs: 600),
    ]);
    expect(run.medianFirstTextMs, 500);
  });

  test('a stopped run says so', () {
    expect(_run([], cancelled: true).summaryText(), contains('stopped early'));
  });

  test('the file name sorts by time and names the model', () {
    expect(
      _run([]).fileName,
      'zt-assist-20261124T180509-gemma-4-e2b-litert-cpu.json',
    );
  });

  test('the results file holds the answers and the summary', () {
    final json = _run([
      _result('a', language: 'he', read: 300.04, write: 21.26),
    ]).toJson();
    final decoded = jsonDecode(jsonEncode(json)) as Map<String, Object?>;
    expect(decoded['format'], 1);
    expect((decoded['model'] as Map)['sha256'], labModels.first.sha256);
    final result = (decoded['results'] as List).single as Map;
    expect(result['answer'], 'answer a');
    expect(result['write_tokens_per_second'], 21.3);
    expect(result['speed_source'], 'runtime counters');
    expect((decoded['summary'] as Map)['text'], contains('ZT Assist'));
  });

  group('ResultStore', () {
    late Directory temp;

    setUp(() => temp = Directory.systemTemp.createTempSync('zt-assist-test'));
    tearDown(() => temp.deleteSync(recursive: true));

    test('saves runs and lists them newest first', () async {
      final store = ResultStore(Directory('${temp.path}/results'));
      expect(await store.list(), isEmpty);

      final older = _run([_result('a', write: 20)]);
      final newer = LabRun(
        appVersion: '0.1.0',
        engineVersion: 'fake 1.0',
        model: labModels[1],
        requestedDevice: 'gpu',
        contextSize: 4096,
        startedAt: DateTime.utc(2026, 11, 25, 7),
        finishedAt: DateTime.utc(2026, 11, 25, 7, 3),
        loadError: 'no GPU',
        results: const [],
      );
      await store.save(older);
      await store.save(newer);
      File('${temp.path}/results/broken.json').writeAsStringSync('{');

      final saved = await store.list();
      expect(saved.map((run) => run.name), [newer.fileName, older.fileName]);
      expect(saved.first.summary, contains('did not load: no GPU'));

      await store.delete(saved.first);
      expect((await store.list()).single.name, older.fileName);
    });
  });
}
