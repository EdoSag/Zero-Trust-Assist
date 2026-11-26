import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/assist_settings.dart';
import '../chat/assistant.dart';
import '../l10n/l10n.dart';
import '../lab/model_catalog.dart';
import '../lab/model_store.dart';
import '../models/assist_models.dart';
import 'model_tile.dart';

/// Settings, Model: switch between the small and the large model, download
/// the other one, or delete one to free space.
class ModelsPage extends ConsumerStatefulWidget {
  const ModelsPage({super.key});

  @override
  ConsumerState<ModelsPage> createState() => _ModelsPageState();
}

class _ModelsPageState extends ConsumerState<ModelsPage> {
  @override
  void initState() {
    super.initState();
    ref.read(modelStoreProvider).refresh();
  }

  Future<void> _use(LabModel model) async {
    final store = ref.read(modelStoreProvider);
    if (store.stateOf(model).stage != ModelStage.ready) return;
    await ref.read(chosenModelProvider.notifier).choose(model.id);
  }

  Future<void> _delete(LabModel model) async {
    final l = context.l10n;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.modelDeleteTitle),
        content: Text(l.modelDeleteBody(gigabytesOf(model.bytes))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            key: const Key('model-delete-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (sure != true) return;
    // The file cannot be deleted while the model is in memory.
    await ref.read(assistantProvider).unload();
    await ref.read(modelStoreProvider).delete(model);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final store = ref.watch(modelStoreProvider);
    final device = ref.watch(deviceSnapshotProvider).value;
    final chosen = ref.watch(chosenModelProvider).value;
    final suggested = recommendedModel(device?.totalRamBytes ?? 0);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsModel)),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              Text(l.modelsIntro),
              const SizedBox(height: 12),
              for (final model in chatModels)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ModelTile(
                    model: model,
                    state: store.stateOf(model),
                    selected: model.id == chosen,
                    recommended: model.id == suggested.id,
                    freeStorageBytes: device?.freeStorageBytes,
                    onSelect: () => _use(model),
                    onDownload: () => store.download(model),
                    onCancel: () => store.cancel(model),
                    onDelete: () => _delete(model),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
