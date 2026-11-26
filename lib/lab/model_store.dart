import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:llamadart/llamadart.dart';

import 'model_catalog.dart';

/// Where one model file is on its way to the phone.
enum ModelStage { missing, downloading, verifying, ready, failed }

/// The state of one model file.
class ModelState {
  const ModelState(
    this.stage, {
    this.fraction,
    this.receivedBytes = 0,
    this.path,
    this.error,
  });

  final ModelStage stage;

  /// Download progress from 0 to 1, when known.
  final double? fraction;
  final int receivedBytes;

  /// Where the finished file is.
  final String? path;

  /// Why the download failed.
  final String? error;

  bool get isBusy =>
      stage == ModelStage.downloading || stage == ModelStage.verifying;
}

/// Downloads the test's model files and keeps track of which are on the phone.
///
/// Files live in the app's own data folder (not its cache, which Android may
/// empty at any time). A download resumes where it stopped, and a file is only
/// accepted when its SHA-256 matches the one pinned in the model list.
class ModelStore extends ChangeNotifier {
  ModelStore(String directory)
    : _manager = DefaultModelDownloadManager(defaultCacheDirectory: directory);

  final ModelDownloadManager _manager;
  final Map<String, ModelState> _states = {};
  final Map<String, ModelDownloadController> _controllers = {};
  final Map<String, StreamSubscription<ModelDownloadTaskSnapshot>> _listeners =
      {};

  static ModelSource _source(LabModel model) =>
      ModelSource.huggingFace(repoId: model.repoId, filePath: model.fileName);

  ModelState stateOf(LabModel model) =>
      _states[model.id] ?? const ModelState(ModelStage.missing);

  /// Looks on disk for the files that are already complete.
  Future<void> refresh() async {
    for (final model in labModels) {
      if (stateOf(model).isBusy) continue;
      final entry = await _manager.get(_source(model).cacheKey);
      _states[model.id] = entry == null
          ? const ModelState(ModelStage.missing)
          : ModelState(ModelStage.ready, path: entry.filePath);
    }
    notifyListeners();
  }

  /// Starts or resumes the download of [model]. Progress arrives through
  /// [stateOf] and this store's listeners.
  Future<void> download(LabModel model) async {
    if (stateOf(model).isBusy) return;
    final controller = _controllers[model.id] ??= ModelDownloadController(
      manager: _manager,
    );
    _listeners[model.id] ??= controller.snapshots.listen(
      (snapshot) => _onSnapshot(model, snapshot),
    );
    _set(model, const ModelState(ModelStage.downloading));
    try {
      await controller.start(
        _source(model),
        options: ModelLoadOptions(sha256: model.sha256),
      );
    } on Object catch (error) {
      // The snapshot listener normally reports the failure first; this covers
      // a failure thrown before any snapshot.
      if (stateOf(model).isBusy) {
        _set(model, ModelState(ModelStage.failed, error: error.toString()));
      }
    }
  }

  void cancel(LabModel model) => _controllers[model.id]?.cancel();

  Future<void> delete(LabModel model) async {
    try {
      await _manager.remove(_source(model).cacheKey);
    } on ModelCacheEntryInUseException {
      _set(
        model,
        ModelState(
          ModelStage.ready,
          path: stateOf(model).path,
          error: 'The model is in use. Close the test or chat first.',
        ),
      );
      return;
    }
    _set(model, const ModelState(ModelStage.missing));
  }

  void _onSnapshot(LabModel model, ModelDownloadTaskSnapshot snapshot) {
    final progress = snapshot.progress;
    switch (snapshot.stage) {
      case ModelDownloadTaskStage.idle:
        break;
      case ModelDownloadTaskStage.resolving:
      case ModelDownloadTaskStage.checkingCache:
      case ModelDownloadTaskStage.downloading:
        _set(
          model,
          ModelState(
            ModelStage.downloading,
            fraction: snapshot.fraction,
            receivedBytes: progress?.receivedBytes ?? 0,
          ),
        );
      case ModelDownloadTaskStage.verifying:
        _set(model, const ModelState(ModelStage.verifying, fraction: 1));
      case ModelDownloadTaskStage.ready:
        _set(
          model,
          ModelState(ModelStage.ready, path: snapshot.entry?.filePath),
        );
      case ModelDownloadTaskStage.failed:
        _set(
          model,
          ModelState(
            ModelStage.failed,
            error: snapshot.errorMessage ?? 'The download failed.',
          ),
        );
      case ModelDownloadTaskStage.cancelled:
        // The part already downloaded stays on disk, so the next attempt
        // continues from there.
        _set(model, const ModelState(ModelStage.missing));
    }
  }

  void _set(LabModel model, ModelState state) {
    _states[model.id] = state;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final listener in _listeners.values) {
      unawaited(listener.cancel());
    }
    for (final controller in _controllers.values) {
      unawaited(controller.dispose());
    }
    super.dispose();
  }
}
