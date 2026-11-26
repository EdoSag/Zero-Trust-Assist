import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import 'app/app_gate.dart';
import 'app/assist_config.dart';
import 'app/incoming_links.dart';
import 'l10n/l10n.dart';
import 'lab/model_store.dart';
import 'lab/result_store.dart';
import 'models/assist_models.dart';
import 'ui/settings_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  unawaited(IncomingLinks.listen());
  // English or Hebrew, as picked in Settings, from the first frame.
  await ZtLanguageController.preload();
  // Models go in the app's data folder, not its cache: Android may empty the
  // cache whenever it is short of space, and these files are gigabytes.
  final support = await getApplicationSupportDirectory();
  final documents = await getApplicationDocumentsDirectory();
  runApp(
    ProviderScope(
      overrides: [
        ztAppConfigProvider.overrideWithValue(assistAppConfig),
        modelStoreProvider.overrideWithValue(
          ModelStore('${support.path}/models'),
        ),
        resultStoreProvider.overrideWithValue(
          ResultStore(Directory('${documents.path}/results')),
        ),
      ],
      child: const ZeroTrustAssistApp(),
    ),
  );
}

class ZeroTrustAssistApp extends ConsumerWidget {
  const ZeroTrustAssistApp({super.key, this.home = const AppGate()});

  final Widget home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ZtThemeBuilder(
      builder: (context, theme, darkTheme, mode) => MaterialApp(
        // On-device task switcher label; the store name is Zero-Trust Assist.
        title: 'ZT Assist',
        theme: theme,
        darkTheme: darkTheme,
        themeMode: mode,
        // English (default) or Hebrew, from Settings → Appearance → Language.
        locale: ref.watch(ztLanguageProvider),
        supportedLocales: ZtLanguages.supported,
        localizationsDelegates: const [
          AppL10n.delegate,
          ...ZtLanguages.delegates,
        ],
        home: ZtSignInHandoffScope(child: home),
        // Any touch on any screen counts as activity for auto-lock.
        builder: (BuildContext context, Widget? child) => Listener(
          onPointerDown: (_) =>
              ref.read(vaultControllerProvider.notifier).touch(),
          child: child,
        ),
      ),
    );
  }
}
