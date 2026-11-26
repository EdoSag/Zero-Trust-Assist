import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../lab/device_info.dart';
import '../lab/model_catalog.dart';
import '../lab/model_store.dart';

/// The two models a user can chat with. The phone test lists more.
const String smallModelId = 'gemma-4-e2b-litert';
const String largeModelId = 'gemma-4-e4b-litert';

LabModel get smallModel => labModels.firstWhere((m) => m.id == smallModelId);
LabModel get largeModel => labModels.firstWhere((m) => m.id == largeModelId);

/// Small first: it is the default.
List<LabModel> get chatModels => [smallModel, largeModel];

LabModel? chatModelById(String? id) {
  for (final model in chatModels) {
    if (model.id == id) return model;
  }
  return null;
}

const int _gigabyte = 1000 * 1000 * 1000;

/// The large model is for phones sold with 12 GB of memory or more. Such a
/// phone reports a little less than 12 GB, so the line sits at 11.
const int largeModelRamBytes = 11 * _gigabyte;

/// The app is meant for phones sold with 8 GB or more, which report a little
/// less than 8.
const int minimumRamBytes = 7 * _gigabyte;

/// The model to suggest on a phone with [totalRamBytes] of memory. Small
/// when the amount is unknown (0).
LabModel recommendedModel(int totalRamBytes) =>
    totalRamBytes >= largeModelRamBytes ? largeModel : smallModel;

/// Whether the phone has less memory than the app is meant for. False when
/// the amount is unknown.
bool belowMinimumRam(int totalRamBytes) =>
    totalRamBytes > 0 && totalRamBytes < minimumRamBytes;

/// The downloaded models. `main` puts the real one in.
final modelStoreProvider = Provider<ModelStore>(
  (ref) => throw UnimplementedError('modelStoreProvider is set in main()'),
);

/// The phone's memory, storage and screen lock.
final deviceInfoProvider = Provider<DeviceInfo>((ref) => const DeviceInfo());

/// What the phone reports about itself, read once.
final deviceSnapshotProvider = FutureProvider<DeviceSnapshot?>(
  (ref) => ref.watch(deviceInfoProvider).snapshot(),
);
