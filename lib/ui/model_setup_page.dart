import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/assist_settings.dart';
import '../l10n/l10n.dart';
import '../lab/model_catalog.dart';
import '../lab/model_store.dart';
import '../models/assist_models.dart';
import 'model_tile.dart';
import 'settings_page.dart';

/// The first screen after signing in: pick the small or the large model and
/// download it. Shown again whenever the chosen model is not on the phone.
class ModelSetupPage extends ConsumerStatefulWidget {
  const ModelSetupPage({super.key});

  @override
  ConsumerState<ModelSetupPage> createState() => _ModelSetupPageState();
}

class _ModelSetupPageState extends ConsumerState<ModelSetupPage> {
  /// What the user tapped. Until then the suggestion for this phone shows.
  LabModel? _picked;

  /// The model whose download was started here, so the chat opens by itself
  /// once it is on the phone.
  String? _waitingFor;

  /// Kept in a field: `ref` is no longer usable by the time `dispose` runs.
  late final ModelStore _store;

  @override
  void initState() {
    super.initState();
    _store = ref.read(modelStoreProvider)..addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    final waiting = chatModelById(_waitingFor);
    if (waiting == null) return;
    final stage = _store.stateOf(waiting).stage;
    if (stage == ModelStage.ready) {
      _waitingFor = null;
      ref.read(chosenModelProvider.notifier).choose(waiting.id);
    } else if (stage == ModelStage.failed || stage == ModelStage.missing) {
      _waitingFor = null;
    }
  }

  void _download(LabModel model) {
    setState(() {
      _picked = model;
      _waitingFor = model.id;
    });
    _store.download(model);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final store = ref.watch(modelStoreProvider);
    final device = ref.watch(deviceSnapshotProvider).value;
    final ram = device?.totalRamBytes ?? 0;
    final suggested = recommendedModel(ram);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.appName),
        actions: [
          IconButton(
            key: const Key('setup-settings'),
            tooltip: l.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AssistSettingsPage(),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final picked =
                _picked ??
                chatModelById(ref.watch(chosenModelProvider).value) ??
                suggested;
            final state = store.stateOf(picked);
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      Text(l.setupTitle, style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text(l.setupIntro),
                      const SizedBox(height: 16),
                      if (belowMinimumRam(ram))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            l.setupLowMemory(gigabytesOf(ram)),
                            key: const Key('setup-low-memory'),
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      for (final model in chatModels)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ModelTile(
                            model: model,
                            state: store.stateOf(model),
                            selected: model.id == picked.id,
                            recommended: model.id == suggested.id,
                            freeStorageBytes: device?.freeStorageBytes,
                            onSelect: () => setState(() => _picked = model),
                            onDownload: () => _download(model),
                            onCancel: () => store.cancel(model),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        l.setupSource,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('setup-continue'),
                      onPressed: state.stage == ModelStage.ready
                          ? () => ref
                                .read(chosenModelProvider.notifier)
                                .choose(picked.id)
                          : null,
                      child: Text(l.setupStart),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
