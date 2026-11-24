import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../app_info.dart';
import '../engine/assist_engine.dart';
import '../engine/llamadart_engine.dart';
import '../lab/device_info.dart';
import '../lab/lab_result.dart';
import '../lab/lab_runner.dart';
import '../lab/model_catalog.dart';
import '../lab/prompts.dart';
import '../lab/result_store.dart';
import 'text_direction.dart';

/// Runs the test for one model and shows the result when it is done.
class RunPage extends StatefulWidget {
  const RunPage({
    super.key,
    required this.model,
    required this.modelPath,
    required this.device,
    required this.prompts,
    required this.results,
    this.deviceInfo = const DeviceInfo(),
    this.createEngine = LlamadartEngine.new,
  });

  final LabModel model;
  final String modelPath;
  final AssistDevice device;
  final List<LabPrompt> prompts;
  final ResultStore results;
  final DeviceInfo deviceInfo;

  /// Tests pass a fake engine here.
  final AssistEngine Function() createEngine;

  @override
  State<RunPage> createState() => _RunPageState();
}

class _RunPageState extends State<RunPage> {
  late final LabRunner _runner = LabRunner(
    createEngine: widget.createEngine,
    readDevice: widget.deviceInfo.snapshot,
    appVersion: appVersion,
    engineVersion: engineVersion,
  );

  LabProgress _progress = const LabProgress.loading();
  String _liveAnswer = '';
  String _pendingAnswer = '';
  Timer? _flush;
  LabRun? _run;
  File? _file;
  bool _stopping = false;

  @override
  void initState() {
    super.initState();
    // The answer arrives a few characters at a time, many times a second.
    // Repainting on each piece would slow the very thing being measured, so
    // the text on screen is refreshed on a slow timer instead.
    _flush = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_pendingAnswer == _liveAnswer || !mounted) return;
      setState(() => _liveAnswer = _pendingAnswer);
    });
    _start();
  }

  Future<void> _start() async {
    await widget.deviceInfo.keepAwake(true);
    final run = await _runner.run(
      model: widget.model,
      modelPath: widget.modelPath,
      device: widget.device,
      prompts: widget.prompts,
      onProgress: (progress) {
        _pendingAnswer = '';
        if (mounted) setState(() => _progress = progress);
      },
      onText: (answer) => _pendingAnswer = answer,
    );
    await widget.deviceInfo.keepAwake(false);
    _flush?.cancel();
    File? file;
    try {
      file = await widget.results.save(run);
    } on FileSystemException {
      // The result is still on screen and can be copied.
      file = null;
    }
    if (!mounted) return;
    setState(() {
      _run = run;
      _file = file;
    });
  }

  void _stop() {
    setState(() => _stopping = true);
    _runner.cancel();
  }

  @override
  void dispose() {
    _flush?.cancel();
    _runner.cancel();
    unawaited(widget.deviceInfo.keepAwake(false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final run = _run;
    return PopScope(
      // Leaving in the middle would throw the measurements away, so the way
      // out while running is the Stop button, which keeps them.
      canPop: run != null,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: run != null,
          title: Text(widget.model.title),
        ),
        body: SafeArea(
          child: run == null ? _buildRunning(context) : _buildDone(run),
        ),
      ),
    );
  }

  Widget _buildRunning(BuildContext context) {
    final theme = Theme.of(context);
    final prompt = _progress.prompt;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            prompt == null
                ? 'Loading the model...'
                : 'Request ${_progress.done + 1} of ${_progress.total}: '
                      '${prompt.category.label} (${prompt.language})',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: prompt == null || _progress.total == 0
                ? null
                : _progress.done / _progress.total,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              reverse: true,
              child: AutoDirectionText(_liveAnswer),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _stopping ? null : _stop,
            child: Text(
              _stopping ? 'Stopping...' : 'Stop and keep what was measured',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDone(LabRun run) {
    final theme = Theme.of(context);
    final file = _file;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText(run.summaryText()),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: file == null
                  ? null
                  : () => SharePlus.instance.share(
                      ShareParams(
                        subject: run.fileName,
                        files: [XFile(file.path, mimeType: 'application/json')],
                      ),
                    ),
              icon: const Icon(Icons.share),
              label: const Text('Share results file'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await Clipboard.setData(ClipboardData(text: run.summaryText()));
                messenger.showSnackBar(
                  const SnackBar(content: Text('Summary copied')),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy summary'),
            ),
          ],
        ),
        if (file == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'The results file could not be saved. Copy the summary instead.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        const SizedBox(height: 24),
        if (run.results.isNotEmpty)
          Text('Answers', style: theme.textTheme.titleMedium),
        for (final result in run.results) _ResultTile(result: result),
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result});

  final PromptResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = result.error;
    final check = result.checkPassed;
    return Card(
      child: ExpansionTile(
        shape: const Border(),
        title: Text('${result.category.label} (${result.language})'),
        subtitle: Text(
          error != null
              ? 'Failed'
              : 'Writes ${formatSpeed(result.writeTokensPerSecond)}, '
                    '${formatSeconds(result.totalMs)}'
                    '${check == null ? '' : (check ? ', correct' : ', wrong')}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (error != null)
            Text(error, style: TextStyle(color: theme.colorScheme.error))
          else
            AutoDirectionText(result.answer),
          if (result.checkNote != null) ...[
            const SizedBox(height: 8),
            Text(
              'Check: ${result.checkNote}',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '${result.promptId}. Read ${result.promptTokens ?? '?'} tokens at '
            '${formatSpeed(result.readTokensPerSecond)}, wrote '
            '${result.answerTokens ?? '?'} tokens. First text after '
            '${formatSeconds(result.firstTextMs)}. '
            'Measured by ${result.speedSource?.label ?? 'nothing'}.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
