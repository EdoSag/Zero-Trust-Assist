import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../app/assist_settings.dart';
import '../chat/assistant.dart';
import '../l10n/l10n.dart';
import '../lab/result_store.dart';
import '../lab/ui/lab_home_page.dart';
import '../models/assist_models.dart';
import 'models_page.dart';

/// Where the phone test keeps its results. `main` puts the real one in.
final resultStoreProvider = Provider<ResultStore>(
  (ref) => throw UnimplementedError('resultStoreProvider is set in main()'),
);

/// The shared Zero-Trust settings screen, with Assist's own rows.
class AssistSettingsPage extends ConsumerWidget {
  const AssistSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ZtSettingsPage(
      showSyncStatus: true,
      onSignedOut: () => Navigator.of(context).popUntil((r) => r.isFirst),
      onOpenUrl: (url) => launchUrl(url, mode: LaunchMode.externalApplication),
      privacyPolicyUrl: Uri.parse('https://zerotrust.bz/privacy'),
      termsUrl: Uri.parse('https://zerotrust.bz/terms'),
      supportUrl: Uri.parse('https://zerotrust.bz/support'),
      // "Export my data": every conversation as readable files, after a
      // warning and the fingerprint or password.
      onDataExported: (file, _) => ref
          .read(vaultControllerProvider.notifier)
          .whileShowingSystemUi(
            () => SharePlus.instance.share(
              ShareParams(files: [XFile(file.path)]),
            ),
          ),
      appSection: const [AppSettingsRows()],
    );
  }
}

/// Assist's own rows: which model answers, and the phone test.
class AppSettingsRows extends ConsumerWidget {
  const AppSettingsRows({super.key});

  Future<void> _openPhoneTest(BuildContext context, WidgetRef ref) async {
    // The test loads a model of its own; two in memory at once is more than
    // most phones have.
    await ref.read(assistantProvider).unload();
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LabHomePage(
          models: ref.read(modelStoreProvider),
          results: ref.read(resultStoreProvider),
          deviceInfo: ref.read(deviceInfoProvider),
          // A full test runs for many minutes with nobody touching the
          // screen; it must not be cut short by the app locking itself.
          onActivity: ref.read(vaultControllerProvider.notifier).touch,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final chosen = ref.watch(chosenModelProvider).value;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          key: const Key('setting-model'),
          leading: const Icon(Icons.memory_outlined),
          title: Text(l.settingsModel),
          subtitle: Text(switch (chosen) {
            smallModelId => l.modelSmall,
            largeModelId => l.modelLarge,
            _ => l.settingsModelNone,
          }),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const ModelsPage())),
        ),
        ListTile(
          key: const Key('setting-phone-test'),
          leading: const Icon(Icons.speed_outlined),
          title: Text(l.settingsPhoneTest),
          subtitle: Text(l.settingsPhoneTestHint),
          onTap: () => _openPhoneTest(context, ref),
        ),
      ],
    );
  }
}
