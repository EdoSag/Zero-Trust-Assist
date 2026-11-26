import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../engine/assist_engine.dart';
import '../../engine/llamadart_engine.dart';
import '../device_info.dart';
import '../lab_result.dart';
import '../model_catalog.dart';
import '../search_check.dart';

/// Runs the search test with one search model and shows how it did: how
/// often the right note was found, in Hebrew and in English, and how long
/// the phone needed. Nothing is saved; the report can be copied or shared.
class SearchTestPage extends StatefulWidget {
  const SearchTestPage({
    super.key,
    required this.model,
    required this.modelPath,
    this.deviceInfo = const DeviceInfo(),
    this.createEngine = LlamadartEngine.new,
    this.onActivity,
    this.activityEvery = const Duration(seconds: 10),
  });

  final LabModel model;
  final String modelPath;
  final DeviceInfo deviceInfo;

  /// Tests pass a fake engine here.
  final AssistEngine Function() createEngine;

  /// Called every few seconds while the test runs, so the app's lock timer
  /// does not cut it short. See `RunPage.onActivity`.
  final VoidCallback? onActivity;

  /// How often [onActivity] is called.
  final Duration activityEvery;

  @override
  State<SearchTestPage> createState() => _SearchTestPageState();
}

class _SearchTestPageState extends State<SearchTestPage> {
  late final AssistEngine _engine = widget.createEngine();
  Timer? _activity;

  bool _loaded = false;
  int _done = 0;
  int _total = 0;
  String? _report;
  String? _error;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _activity = Timer.periodic(
      widget.activityEvery,
      (_) => widget.onActivity?.call(),
    );
    _run();
  }

  Future<void> _run() async {
    await widget.deviceInfo.keepAwake(true);
    String? report;
    String? error;
    try {
      final load = Stopwatch()..start();
      // The search model reads at most about 2,000 tokens of a text.
      await _engine.load(widget.modelPath, contextSize: 2048);
      load.stop();
      if (mounted) setState(() => _loaded = true);
      final result = await runSearchCheck(
        _embed,
        onProgress: (done, total) {
          if (!mounted) return;
          setState(() {
            _done = done;
            _total = total;
          });
        },
      );
      final device = await widget.deviceInfo.snapshot();
      final lines = [
        result.describe(
          model: widget.model.title,
          loadMilliseconds: load.elapsedMilliseconds,
        ),
        if (device != null) ...[
          '',
          'Phone: ${device.phoneName}, heat ${thermalLabel(device.thermalStatus)}, '
              'app memory ${formatGigabytes(device.appMemoryBytes)}',
        ],
      ];
      report = lines.join('\n');
    } on _Closed {
      // The page was left in the middle: nothing to show.
    } on Object catch (failure) {
      error = failure.toString();
    }
    _activity?.cancel();
    await widget.deviceInfo.keepAwake(false);
    if (!mounted) return;
    setState(() {
      _report = report;
      _error = error;
    });
  }

  Future<List<List<double>>> _embed(List<String> texts) {
    // Leaving the page ends the test at the next text.
    if (_closed) throw const _Closed();
    return _engine.embed(texts);
  }

  @override
  void dispose() {
    _closed = true;
    _activity?.cancel();
    unawaited(widget.deviceInfo.keepAwake(false));
    unawaited(_engine.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final error = _error;
    return Scaffold(
      appBar: AppBar(title: const Text('Search test')),
      body: SafeArea(
        child: report != null
            ? _buildDone(context, report)
            : error != null
            ? _buildFailed(context, error)
            : _buildRunning(context),
      ),
    );
  }

  Widget _buildRunning(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            !_loaded
                ? 'Loading the model...'
                : _done < searchNotes.length
                ? 'Reading the notes: $_done of ${searchNotes.length}'
                : 'Searching: ${_done - searchNotes.length} of '
                      '${_total - searchNotes.length}',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: !_loaded || _total == 0 ? null : _done / _total,
          ),
          const SizedBox(height: 16),
          Text(
            '${searchNotes.length} sample notes in Hebrew and English are '
            'read, then ${searchQuestions.length} searches are made in other '
            'words than the notes use. It takes under a minute. Keep this '
            'screen open.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildFailed(BuildContext context, String error) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('The test did not run', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SelectableText(
            error,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDone(BuildContext context, String report) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText(report),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => SharePlus.instance.share(
                ShareParams(subject: 'ZT Assist search test', text: report),
              ),
              icon: const Icon(Icons.share),
              label: const Text('Share report'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await Clipboard.setData(ClipboardData(text: report));
                messenger.showSnackBar(
                  const SnackBar(content: Text('Report copied')),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy report'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Thrown inside the test when its page was closed.
class _Closed implements Exception {
  const _Closed();
}
