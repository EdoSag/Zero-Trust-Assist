import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../service/model_choice.dart';

/// Where the pick is also written for the part of the app that answers
/// other apps (see [ModelChoiceFile]). `main` puts the real file in; null,
/// as in tests, writes nothing.
final modelChoiceFileProvider = Provider<ModelChoiceFile?>((ref) => null);

/// The model the user picked to chat with, kept on this phone only: another
/// phone may have less memory and need the other model.
class ChosenModel extends AsyncNotifier<String?> {
  static const _key = 'assist_model';

  @override
  Future<String?> build() async {
    String? chosen;
    try {
      chosen = await ref.read(ztPreferencesStoreProvider).read(_key);
    } on Object {
      return null; // Unreadable: ask again.
    }
    // A pick made before other apps could ask ZT Assist was never written
    // to the file; opening the app catches up.
    if (chosen != null) await ref.read(modelChoiceFileProvider)?.write(chosen);
    return chosen;
  }

  Future<void> choose(String modelId) async {
    state = AsyncData(modelId);
    await ref.read(modelChoiceFileProvider)?.write(modelId);
    await ref.read(ztPreferencesStoreProvider).write(_key, modelId);
  }
}

final chosenModelProvider = AsyncNotifierProvider<ChosenModel, String?>(
  ChosenModel.new,
);
