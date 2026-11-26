import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/assist_settings.dart';
import '../chat/assistant.dart';
import '../chat/chat_controller.dart';
import '../lab/model_store.dart';
import '../models/assist_models.dart';
import 'chat_home_page.dart';
import 'model_setup_page.dart';

/// The app once unlocked: the chat, or the model choice while the chosen
/// model is not on the phone (first launch, or after deleting it).
class AssistHome extends ConsumerStatefulWidget {
  const AssistHome({super.key, this.unloadWhenHiddenFor = _hiddenFor});

  static const _hiddenFor = Duration(minutes: 1);

  /// How long the app may be off screen before the chat's model is taken
  /// out of memory. While the app is hidden another Zero-Trust app may ask
  /// ZT Assist for a summary, which loads the model a second time in the
  /// part that answers other apps; two copies are more than a phone with
  /// 8 GB has room for. Coming back loads it again with the next message.
  final Duration unloadWhenHiddenFor;

  @override
  ConsumerState<AssistHome> createState() => _AssistHomeState();
}

class _AssistHomeState extends ConsumerState<AssistHome> {
  /// Looks on the phone once for models downloaded earlier.
  late final Future<void> _found = ref.read(modelStoreProvider).refresh();

  late final AppLifecycleListener _lifecycle;
  Timer? _hidden;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () {
        _hidden?.cancel();
        _hidden = Timer.periodic(widget.unloadWhenHiddenFor, (timer) {
          // An answer still being written keeps its model; look again later.
          if (ref.read(chatControllerProvider).busy) return;
          timer.cancel();
          unawaited(ref.read(assistantProvider).unload());
        });
      },
      onShow: () => _hidden?.cancel(),
      onResume: () => _hidden?.cancel(),
    );
  }

  @override
  void dispose() {
    _hidden?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chosen = ref.watch(chosenModelProvider);
    final store = ref.watch(modelStoreProvider);
    return FutureBuilder<void>(
      future: _found,
      builder: (context, found) {
        if (found.connectionState != ConnectionState.done || chosen.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final model = chatModelById(chosen.value);
            final ready =
                model != null && store.stateOf(model).stage == ModelStage.ready;
            return ready ? const ChatHomePage() : const ModelSetupPage();
          },
        );
      },
    );
  }
}
