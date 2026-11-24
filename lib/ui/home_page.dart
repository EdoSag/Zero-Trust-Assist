import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../app_info.dart';
import '../engine/assist_engine.dart';
import '../lab/device_info.dart';
import '../lab/lab_result.dart';
import '../lab/model_catalog.dart';
import '../lab/model_store.dart';
import '../lab/prompts.dart';
import '../lab/result_store.dart';
import 'chat_page.dart';
import 'run_page.dart';

/// The test bench: the phone's state, the models to download, and the runs
/// already made.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.models,
    required this.results,
    this.deviceInfo = const DeviceInfo(),
  });

  final ModelStore models;
  final ResultStore results;
  final DeviceInfo deviceInfo;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DeviceSnapshot? _device;
  List<SavedRun> _runs = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    await widget.models.refresh();
    final device = await widget.deviceInfo.snapshot();
    final runs = await widget.results.list();
    if (!mounted) return;
    setState(() {
      _device = device;
      _runs = runs;
    });
  }

  Future<void> _startRun(LabModel model, String path) async {
    final options = await showModalBottomSheet<RunOptions>(
      context: context,
      showDragHandle: true,
      // Lets the sheet grow past half the screen, so it also fits a small
      // phone.
      isScrollControlled: true,
      builder: (context) => const _RunOptionsSheet(),
    );
    if (options == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => RunPage(
          model: model,
          modelPath: path,
          device: options.device,
          prompts: options.full ? labPrompts : labQuickPrompts,
          results: widget.results,
          deviceInfo: widget.deviceInfo,
        ),
      ),
    );
    await _reload();
  }

  Future<void> _openChat(LabModel model, String path) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ChatPage(model: model, modelPath: path),
      ),
    );
    await _reload();
  }

  Future<void> _confirmDownload(LabModel model) async {
    final free = _device?.freeStorageBytes;
    final tooLittleSpace = free != null && free > 0 && free < model.bytes;
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Download ${model.title}?'),
        content: Text(
          'The file is ${formatGigabytes(model.bytes)} and comes from '
          'huggingface.co/${model.repoId}. Use Wi-Fi. The download continues '
          'where it stopped if it is interrupted.'
          '${tooLittleSpace ? '\n\nOnly ${formatGigabytes(free)} is free on this phone, which is not enough.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: tooLittleSpace
                ? null
                : () => Navigator.of(context).pop(true),
            child: const Text('Download'),
          ),
        ],
      ),
    );
    if (go == true) await widget.models.download(model);
  }

  Future<void> _confirmDelete(LabModel model) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${model.title}?'),
        content: Text(
          'This frees ${formatGigabytes(model.bytes)}. Saved results stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (go != true) return;
    await widget.models.delete(model);
    await _reload();
  }

  Future<void> _shareAll() async {
    await SharePlus.instance.share(
      ShareParams(
        subject: 'ZT Assist phone test results',
        files: [
          for (final run in _runs)
            XFile(run.file.path, mimeType: 'application/json'),
        ],
      ),
    );
  }

  Future<void> _showRun(SavedRun run) async {
    final messenger = ScaffoldMessenger.of(context);
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Saved run'),
        content: SingleChildScrollView(child: SelectableText(run.summary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('delete'),
            child: const Text('Delete'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('copy'),
            child: const Text('Copy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('share'),
            child: const Text('Share file'),
          ),
        ],
      ),
    );
    switch (action) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: run.summary));
        messenger.showSnackBar(const SnackBar(content: Text('Summary copied')));
      case 'share':
        await SharePlus.instance.share(
          ShareParams(
            subject: run.name,
            files: [XFile(run.file.path, mimeType: 'application/json')],
          ),
        );
      case 'delete':
        await widget.results.delete(run);
        await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('ZT Assist phone test'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            'Test build $appVersion. It measures how well AI models run on '
            'this phone. The models run on the phone itself: nothing you type '
            'is sent anywhere. The only network use is downloading the model '
            'files.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          _DeviceCard(device: _device),
          const SizedBox(height: 24),
          Text('Models', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ListenableBuilder(
            listenable: widget.models,
            builder: (context, _) => Column(
              children: [
                for (final model in labModels)
                  _ModelCard(
                    model: model,
                    state: widget.models.stateOf(model),
                    onDownload: () => _confirmDownload(model),
                    onCancel: () => widget.models.cancel(model),
                    onDelete: () => _confirmDelete(model),
                    onRun: (path) => _startRun(model, path),
                    onChat: (path) => _openChat(model, path),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text('Saved runs', style: theme.textTheme.titleMedium),
              ),
              if (_runs.isNotEmpty)
                TextButton.icon(
                  onPressed: _shareAll,
                  icon: const Icon(Icons.share),
                  label: const Text('Share all'),
                ),
            ],
          ),
          if (_runs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No runs yet. Download a model and tap Run test.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          for (final run in _runs)
            Card(
              child: ListTile(
                title: Text(run.name, style: theme.textTheme.bodySmall),
                subtitle: Text(
                  run.summary,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _showRun(run),
              ),
            ),
        ],
      ),
    );
  }
}

/// What the user picked before a run.
class RunOptions {
  const RunOptions({required this.full, required this.device});

  /// The full set of requests, or the short one.
  final bool full;
  final AssistDevice device;
}

class _RunOptionsSheet extends StatefulWidget {
  const _RunOptionsSheet();

  @override
  State<_RunOptionsSheet> createState() => _RunOptionsSheetState();
}

class _RunOptionsSheetState extends State<_RunOptionsSheet> {
  bool _full = false;
  AssistDevice _device = AssistDevice.cpu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Run test', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text('Quick, ${labQuickPrompts.length} requests'),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Full, ${labPrompts.length} requests'),
                ),
              ],
              selected: {_full},
              onSelectionChanged: (value) =>
                  setState(() => _full = value.first),
            ),
            const SizedBox(height: 12),
            SegmentedButton<AssistDevice>(
              segments: const [
                ButtonSegment(value: AssistDevice.cpu, label: Text('CPU')),
                ButtonSegment(value: AssistDevice.gpu, label: Text('GPU')),
              ],
              selected: {_device},
              onSelectionChanged: (value) =>
                  setState(() => _device = value.first),
            ),
            const SizedBox(height: 12),
            Text(
              'Start with Quick on CPU. On GrapheneOS the GPU run is expected '
              'to fail; that is a useful result too. Keep the app open and '
              'the phone unplugged while it runs, so heat and battery are '
              'measured honestly.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(RunOptions(full: _full, device: _device)),
              child: const Text('Start'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device});

  final DeviceSnapshot? device;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final device = this.device;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: device == null
            ? const Text('Reading the phone...')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(device.phoneName, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('${device.soc}, Android API ${device.sdk}'),
                  Text(
                    'Memory: ${formatGigabytes(device.availableRamBytes)} '
                    'free of ${formatGigabytes(device.totalRamBytes)}',
                  ),
                  Text(
                    'Storage free: ${formatGigabytes(device.freeStorageBytes)}',
                  ),
                  Text(
                    'Heat: ${thermalLabel(device.thermalStatus)}. Battery '
                    '${device.batteryPercent}%'
                    '${device.charging ? ', charging' : ''}',
                  ),
                ],
              ),
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.model,
    required this.state,
    required this.onDownload,
    required this.onCancel,
    required this.onDelete,
    required this.onRun,
    required this.onChat,
  });

  final LabModel model;
  final ModelState state;
  final VoidCallback onDownload;
  final VoidCallback onCancel;
  final VoidCallback onDelete;
  final void Function(String path) onRun;
  final void Function(String path) onChat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final path = state.path;
    final error = state.error;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(model.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(model.note),
            const SizedBox(height: 4),
            Text(
              '${formatGigabytes(model.bytes)}, ${model.runtime.label}, '
              '${model.license}',
              style: theme.textTheme.bodySmall,
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 12),
            switch (state.stage) {
              ModelStage.missing => FilledButton.tonalIcon(
                onPressed: onDownload,
                icon: const Icon(Icons.download),
                label: const Text('Download'),
              ),
              ModelStage.failed => FilledButton.tonalIcon(
                onPressed: onDownload,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
              ModelStage.downloading => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: state.fraction),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${formatGigabytes(state.receivedBytes)} of '
                          '${formatGigabytes(model.bytes)}',
                        ),
                      ),
                      TextButton(
                        onPressed: onCancel,
                        child: const Text('Pause'),
                      ),
                    ],
                  ),
                ],
              ),
              ModelStage.verifying => const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(),
                  SizedBox(height: 8),
                  Text('Checking the file. This takes a moment.'),
                ],
              ),
              ModelStage.ready => Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: path == null ? null : () => onRun(path),
                    icon: const Icon(Icons.speed),
                    label: const Text('Run test'),
                  ),
                  OutlinedButton.icon(
                    onPressed: path == null ? null : () => onChat(path),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Chat'),
                  ),
                  IconButton(
                    tooltip: 'Delete the model file',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            },
          ],
        ),
      ),
    );
  }
}
