import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

/// The model the user picked to chat with, kept on this phone only: another
/// phone may have less memory and need the other model.
class ChosenModel extends AsyncNotifier<String?> {
  static const _key = 'assist_model';

  @override
  Future<String?> build() async {
    try {
      return await ref.read(ztPreferencesStoreProvider).read(_key);
    } on Object {
      return null; // Unreadable: ask again.
    }
  }

  Future<void> choose(String modelId) async {
    state = AsyncData(modelId);
    await ref.read(ztPreferencesStoreProvider).write(_key, modelId);
  }
}

final chosenModelProvider = AsyncNotifierProvider<ChosenModel, String?>(
  ChosenModel.new,
);
