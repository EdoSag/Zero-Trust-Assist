import 'dart:io';

import '../lab/model_catalog.dart';
import '../lab/model_store.dart';
import '../models/assist_models.dart';

/// The picked model's id in a plain file next to the models.
///
/// The app keeps the pick with its other settings, in the phone's key
/// store. The part of ZT Assist that answers other apps runs as a process
/// of its own and stays away from that store, so the app also writes the
/// pick here, where reading it needs nothing but the file. A model's name
/// is no secret.
class ModelChoiceFile {
  const ModelChoiceFile(this.file);

  /// The file for the models kept under [modelsDirectory].
  ModelChoiceFile.inDirectory(String modelsDirectory)
    : file = File('$modelsDirectory/chosen-model');

  final File file;

  Future<String?> read() async {
    try {
      final id = (await file.readAsString()).trim();
      return id.isEmpty ? null : id;
    } on Object {
      return null; // Not written yet.
    }
  }

  Future<void> write(String modelId) async {
    try {
      await file.parent.create(recursive: true);
      await file.writeAsString(modelId, flush: true);
    } on Object {
      // The pick still works inside the app; other apps get whichever
      // model is on the phone.
    }
  }
}

/// The model that answers other apps: the picked one, or, when no pick is
/// on record or its file is gone, whichever is on the phone, the small one
/// first. Null when neither is.
Future<LabModel?> modelForOtherApps(
  ModelStore store,
  ModelChoiceFile choice,
) async {
  await store.refresh();
  bool ready(LabModel model) => store.stateOf(model).stage == ModelStage.ready;
  final picked = chatModelById(await choice.read());
  if (picked != null && ready(picked)) return picked;
  for (final model in chatModels) {
    if (ready(model)) return model;
  }
  return null;
}
