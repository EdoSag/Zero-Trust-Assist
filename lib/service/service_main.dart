import 'dart:async';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import '../chat/assistant.dart';
import '../engine/llamadart_engine.dart';
import '../lab/model_store.dart';
import 'engine_host.dart';
import 'model_choice.dart';

/// The channel between the Android service (`AssistService.java`) and the
/// code here.
const MethodChannel assistServiceChannel = MethodChannel('zt_assist/service');

/// Runs inside the Android service that answers other Zero-Trust apps.
///
/// No screen, no account, no sync: only the model. The service starts this
/// instead of `main` in a process of its own, hands over each request and
/// passes the answer back to the app that asked. `main.dart` exports the
/// entry point that calls it.
Future<void> runAssistService() async {
  WidgetsFlutterBinding.ensureInitialized();
  // An entry point other than `main` has to bring up the plugins' Dart
  // halves itself; the folder lookup below is one of them.
  DartPluginRegistrant.ensureInitialized();
  final support = await getApplicationSupportDirectory();
  final modelsDirectory = '${support.path}/models';
  final store = ModelStore(modelsDirectory);
  final choice = ModelChoiceFile.inDirectory(modelsDirectory);

  final host = EngineHost(
    assistant: Assistant(createEngine: LlamadartEngine.new),
    modelPath: () async {
      final model = await modelForOtherApps(store, choice);
      return model == null ? null : store.stateOf(model).path;
    },
    emit: (method, arguments) =>
        unawaited(assistServiceChannel.invokeMethod<void>(method, arguments)),
  );

  assistServiceChannel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'status':
        return host.status();
      case 'ask':
        host.ask(call.arguments as Map<Object?, Object?>);
        return null;
      case 'cancel':
        host.cancel(call.arguments as String);
        return null;
      case 'shutdown':
        await host.shutdown();
        return null;
    }
    throw MissingPluginException();
  });
  await assistServiceChannel.invokeMethod<void>('ready');
}
