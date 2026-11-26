import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../lab/model_catalog.dart';
import '../lab/model_store.dart';
import '../models/assist_models.dart';

/// "2.6", for the size of a download in gigabytes.
String gigabytesOf(int bytes) => (bytes / 1000000000).toStringAsFixed(1);

/// One model the user can pick: what it is, how big, whether it is on the
/// phone, and the buttons to download or delete it.
class ModelTile extends StatelessWidget {
  const ModelTile({
    super.key,
    required this.model,
    required this.state,
    required this.selected,
    required this.recommended,
    required this.onSelect,
    required this.onDownload,
    required this.onCancel,
    this.onDelete,
    this.freeStorageBytes,
  });

  final LabModel model;
  final ModelState state;
  final bool selected;

  /// Whether this is the model that suits the phone's memory.
  final bool recommended;
  final VoidCallback onSelect;
  final VoidCallback onDownload;
  final VoidCallback onCancel;

  /// Null hides Delete (the first-launch screen has nothing to delete yet).
  final VoidCallback? onDelete;

  /// Free space on the phone, when known.
  final int? freeStorageBytes;

  bool get _tooLittleSpace {
    final free = freeStorageBytes;
    return free != null && free > 0 && free < model.bytes;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final small = model.id == smallModelId;
    final ready = state.stage == ModelStage.ready;
    final error = state.error;
    return Card(
      key: Key('model-${model.id}'),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 14, 16, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 12, top: 2),
                child: Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          small ? l.modelSmall : l.modelLarge,
                          style: theme.textTheme.titleMedium,
                        ),
                        if (recommended)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              l.modelRecommended,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(small ? l.modelSmallHint : l.modelLargeHint),
                    const SizedBox(height: 4),
                    Text(
                      l.modelDetails(
                        small ? 'Gemma 4 E2B' : 'Gemma 4 E4B',
                        gigabytesOf(model.bytes),
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (state.isBusy) ...[
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: state.stage == ModelStage.verifying
                            ? null
                            : state.fraction,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        state.stage == ModelStage.verifying
                            ? l.modelChecking
                            : l.modelDownloading(
                                gigabytesOf(state.receivedBytes),
                                gigabytesOf(model.bytes),
                              ),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    if (ready && error == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          l.modelOnPhone,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    if (state.stage == ModelStage.failed)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          l.modelDownloadFailed,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.error,
                          ),
                        ),
                      ),
                    if (ready && error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          l.modelInUse,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.error,
                          ),
                        ),
                      ),
                    if (!ready && !state.isBusy && _tooLittleSpace)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          l.modelNoSpace(gigabytesOf(freeStorageBytes!)),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.error,
                          ),
                        ),
                      ),
                    // A Wrap, not a Row: the suite's buttons take all the
                    // width a Row gives them.
                    Wrap(
                      spacing: 4,
                      children: [
                        if (state.isBusy)
                          TextButton.icon(
                            key: Key('model-cancel-${model.id}'),
                            onPressed: onCancel,
                            icon: const Icon(Icons.close),
                            label: Text(l.cancel),
                          )
                        else if (!ready)
                          TextButton.icon(
                            key: Key('model-download-${model.id}'),
                            onPressed: _tooLittleSpace ? null : onDownload,
                            icon: const Icon(Icons.download_outlined),
                            label: Text(
                              state.stage == ModelStage.failed
                                  ? l.modelTryAgain
                                  : l.modelDownload,
                            ),
                          ),
                        if (ready && onDelete != null)
                          TextButton.icon(
                            key: Key('model-delete-${model.id}'),
                            onPressed: onDelete,
                            icon: const Icon(Icons.delete_outline),
                            label: Text(l.delete),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
