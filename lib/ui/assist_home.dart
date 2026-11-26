import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/assist_settings.dart';
import '../lab/model_store.dart';
import '../models/assist_models.dart';
import 'chat_home_page.dart';
import 'model_setup_page.dart';

/// The app once unlocked: the chat, or the model choice while the chosen
/// model is not on the phone (first launch, or after deleting it).
class AssistHome extends ConsumerStatefulWidget {
  const AssistHome({super.key});

  @override
  ConsumerState<AssistHome> createState() => _AssistHomeState();
}

class _AssistHomeState extends ConsumerState<AssistHome> {
  /// Looks on the phone once for models downloaded earlier.
  late final Future<void> _found = ref.read(modelStoreProvider).refresh();

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
