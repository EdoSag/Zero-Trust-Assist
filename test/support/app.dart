import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_assist/app/assist_config.dart';
import 'package:zerotrust_assist/chat/assistant.dart';
import 'package:zerotrust_assist/chat/chat_store.dart';
import 'package:zerotrust_assist/chat/conversation.dart';
import 'package:zerotrust_assist/l10n/l10n.dart';
import 'package:zerotrust_assist/lab/device_info.dart';
import 'package:zerotrust_assist/lab/model_catalog.dart';
import 'package:zerotrust_assist/lab/model_store.dart';
import 'package:zerotrust_assist/models/assist_models.dart';

import '../fake_engine.dart';

/// Keeps the conversations in memory, in place of the encrypted store.
class MemoryChatRepository extends ChatRepository {
  MemoryChatRepository(
    super.ref, {
    List<Conversation> conversations = const [],
  }) {
    for (final conversation in conversations) {
      _conversations[conversation.id] = conversation;
    }
  }

  final _conversations = <String, Conversation>{};
  final _changes = StreamController<void>.broadcast();
  var _nextId = 0;

  /// Makes every save fail, as when the phone's storage is full.
  bool failSaves = false;

  /// Every save, in order.
  final saved = <Conversation>[];

  List<Conversation> get conversations =>
      _conversations.values.toList()..sort(compareConversations);

  Stream<List<Conversation>> watch() async* {
    yield conversations;
    yield* _changes.stream.map((_) => conversations);
  }

  @override
  String newId() => 'chat-${++_nextId}';

  @override
  Future<void> save(Conversation conversation) async {
    if (failSaves) throw StateError('disk full');
    saved.add(conversation);
    _conversations[conversation.id] = conversation;
    _changes.add(null);
  }

  @override
  Future<void> delete(String id) async {
    _conversations.remove(id);
    _changes.add(null);
  }
}

/// A model store with fixed states, so nothing is downloaded.
class FixedModelStore extends ModelStore {
  FixedModelStore(this.states) : super('/nowhere');

  final Map<String, ModelState> states;
  final downloads = <String>[];
  final deleted = <String>[];

  /// Puts [model] in [state], as a download moving on would.
  void set(LabModel model, ModelState state) {
    states[model.id] = state;
    notifyListeners();
  }

  @override
  Future<void> refresh() async {}

  @override
  ModelState stateOf(LabModel model) =>
      states[model.id] ?? const ModelState(ModelStage.missing);

  @override
  Future<void> download(LabModel model) async {
    downloads.add(model.id);
    set(model, const ModelState(ModelStage.downloading, fraction: 0));
  }

  @override
  void cancel(LabModel model) =>
      set(model, const ModelState(ModelStage.missing));

  @override
  Future<void> delete(LabModel model) async {
    deleted.add(model.id);
    set(model, const ModelState(ModelStage.missing));
  }
}

/// A phone with [ramBytes] of memory. Remembers when the screen was kept on.
class FakeDeviceInfo implements DeviceInfo {
  FakeDeviceInfo({
    this.ramBytes = 16 * 1000 * 1000 * 1000,
    this.freeBytes = 60 * 1000 * 1000 * 1000,
  });

  final int ramBytes;
  final int freeBytes;
  final awake = <bool>[];

  @override
  Future<DeviceSnapshot?> snapshot() async => DeviceSnapshot(
    manufacturer: 'Google',
    model: 'Pixel 10 Pro',
    soc: 'Google Tensor G5',
    sdk: 37,
    totalRamBytes: ramBytes,
    availableRamBytes: ramBytes ~/ 2,
    lowMemory: false,
    appMemoryBytes: 250000000,
    freeStorageBytes: freeBytes,
    thermalStatus: 0,
    batteryPercent: 80,
    charging: false,
  );

  @override
  Future<void> keepAwake(bool on) async => awake.add(on);
}

const readySmall = ModelState(ModelStage.ready, path: '/models/small.litertlm');
const readyLarge = ModelState(ModelStage.ready, path: '/models/large.litertlm');

/// What a test can look at after [overridesFor] built the app's parts.
class TestWorld {
  late MemoryChatRepository repository;
  late FixedModelStore store;
  late FakeDeviceInfo device;
  late InMemoryPreferencesStore prefs;

  /// Every engine the app made, in order.
  final engines = <FakeEngine>[];
}

/// The app's parts replaced by ones that stay in memory.
///
/// [chosen] is the model picked earlier (null: first launch). [states] says
/// which models are on the phone. [engine] makes the engine for each load.
List<Override> overridesFor(
  TestWorld world, {
  String? chosen = smallModelId,
  Map<String, ModelState>? states,
  List<Conversation> conversations = const [],
  FakeEngine Function()? engine,
  FakeDeviceInfo? device,
}) {
  world.prefs = InMemoryPreferencesStore();
  if (chosen != null) world.prefs.values['assist_model'] = chosen;
  world.store = FixedModelStore(states ?? {smallModelId: readySmall});
  world.device = device ?? FakeDeviceInfo();
  return [
    ztAppConfigProvider.overrideWithValue(assistAppConfig),
    ztPreferencesStoreProvider.overrideWithValue(world.prefs),
    modelStoreProvider.overrideWithValue(world.store),
    deviceInfoProvider.overrideWithValue(world.device),
    assistantProvider.overrideWith(
      (ref) => Assistant(
        createEngine: () {
          final made = (engine ?? FakeEngine.new)();
          world.engines.add(made);
          return made;
        },
      ),
    ),
    chatRepositoryProvider.overrideWith(
      (ref) => world.repository = MemoryChatRepository(
        ref,
        conversations: conversations,
      ),
    ),
    conversationsProvider.overrideWith(
      (ref) =>
          (ref.watch(chatRepositoryProvider) as MemoryChatRepository).watch(),
    ),
  ];
}

/// [home] inside the suite's real theme, in [locale].
Widget app(
  Widget home,
  TestWorld world, {
  Locale locale = ZtLanguages.english,
  String? chosen = smallModelId,
  Map<String, ModelState>? states,
  List<Conversation> conversations = const [],
  FakeEngine Function()? engine,
  FakeDeviceInfo? device,
}) {
  return ProviderScope(
    overrides: [
      ...overridesFor(
        world,
        chosen: chosen,
        states: states,
        conversations: conversations,
        engine: engine,
        device: device,
      ),
    ],
    child: MaterialApp(
      // The suite's real theme: its full-width buttons break rows that a
      // plain theme lets through.
      theme: ZtTheme.light(accent: assistAppConfig.accent),
      locale: locale,
      supportedLocales: ZtLanguages.supported,
      localizationsDelegates: const [
        AppL10n.delegate,
        ...ZtLanguages.delegates,
      ],
      // Makes the repository right away, so `world.repository` is this
      // test's own from the first frame.
      home: Consumer(
        builder: (context, ref, _) {
          ref.watch(chatRepositoryProvider);
          return home;
        },
      ),
    ),
  );
}

/// A small phone, so anything that does not fit shows up as an overflow.
void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360 * 3, 740 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}
