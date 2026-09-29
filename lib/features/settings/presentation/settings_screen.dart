import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'package:dental_clinic/core/config/app_config.dart';
import 'package:dental_clinic/core/widgets/app_dialogs.dart';
import 'package:dental_clinic/core/widgets/max_width.dart';
import 'package:dental_clinic/features/health/application/health_controller.dart';
import 'package:dental_clinic/features/health/data/health_repository.dart';
import 'package:dental_clinic/features/settings/application/package_info_provider.dart';
import 'package:dental_clinic/features/settings/application/settings_controllers.dart';
import 'package:dental_clinic/features/setup/application/auth_controller.dart';
import 'package:dental_clinic/features/whatsapp/presentation/whatsapp_settings_card.dart';
import 'package:dental_clinic/l10n/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeModeControllerProvider);
    final locale = ref.watch(localeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        child: MaxWidth(
          maxWidth: 720,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              _SectionCard(
                title: l10n.appearance,
                child: SegmentedButton<ThemeMode>(
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text(l10n.appearanceLight),
                      icon: const Icon(Icons.light_mode_outlined),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text(l10n.appearanceDark),
                      icon: const Icon(Icons.dark_mode_outlined),
                    ),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (selection) => ref
                      .read(themeModeControllerProvider.notifier)
                      .set(selection.first),
                ),
              ),
              _SectionCard(
                title: l10n.language,
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'en',
                      label: Text(l10n.languageEnglish),
                    ),
                    ButtonSegment(
                      value: 'ar',
                      label: Text(l10n.languageArabic),
                    ),
                  ],
                  selected: {locale.languageCode},
                  onSelectionChanged: (selection) => ref
                      .read(localeControllerProvider.notifier)
                      .set(Locale(selection.first)),
                ),
              ),
              const WhatsAppSettingsCard(),
              _ConnectionCard(),
              _AppInfoCard(),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  final ok = await showConfirmDialog(
                    context,
                    title: l10n.resetToken,
                    message: l10n.resetTokenBody,
                    confirmLabel: l10n.resetToken,
                    destructive: true,
                  );
                  if (ok) {
                    await ref.read(authControllerProvider.notifier).signOut();
                  }
                },
                icon: const Icon(Icons.logout_rounded),
                label: Text(l10n.resetToken),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _ConnectionCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final health = ref.watch(healthControllerProvider);

    final bool checking = health.isLoading;
    final HealthStatus? status = health.value;

    String apiValue;
    String dbValue;
    if (checking) {
      apiValue = l10n.statusChecking;
      dbValue = l10n.statusChecking;
    } else if (status != null) {
      apiValue = status.workerLive ? l10n.statusOnline : l10n.statusOffline;
      dbValue = status.databaseReady ? l10n.statusReady : l10n.statusNotReady;
    } else {
      apiValue = l10n.statusOffline;
      dbValue = l10n.statusNotReady;
    }

    String tokenValue;
    bool? tokenGood;
    if (checking || status == null) {
      tokenValue = l10n.statusChecking;
      tokenGood = null;
    } else {
      switch (status.tokenStatus) {
        case TokenStatus.valid:
          tokenValue = l10n.statusValid;
          tokenGood = true;
          break;
        case TokenStatus.invalid:
          tokenValue = l10n.statusInvalid;
          tokenGood = false;
          break;
        case TokenStatus.unknown:
          tokenValue = l10n.statusUnknown;
          tokenGood = null;
          break;
      }
    }

    final lastConnection = (status != null && status.allHealthy)
        ? DateFormat.yMMMd(locale).add_jm().format(status.checkedAt!)
        : l10n.statusNever;

    return _SectionCard(
      title: l10n.connection,
      child: Column(
        children: [
          _StatusRow(
            label: l10n.apiStatus,
            value: apiValue,
            good: !checking && (status?.workerLive ?? false),
            checking: checking,
          ),
          const Divider(height: 20),
          _StatusRow(
            label: l10n.databaseReadiness,
            value: dbValue,
            good: !checking && (status?.databaseReady ?? false),
            checking: checking,
          ),
          const Divider(height: 20),
          _StatusRow(
            label: l10n.apiTokenStatus,
            value: tokenValue,
            good: tokenGood,
            checking: checking,
          ),
          const Divider(height: 20),
          _StatusRow(label: l10n.lastConnection, value: lastConnection),
          const SizedBox(height: 14),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.tonalIcon(
              onPressed: checking
                  ? null
                  : () => ref.read(healthControllerProvider.notifier).retest(),
              icon: const Icon(Icons.wifi_tethering_rounded),
              label: Text(l10n.testConnection),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    this.good,
    this.checking = false,
  });

  final String label;
  final String value;
  final bool? good;
  final bool checking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget? indicator;
    if (checking) {
      indicator = const SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (good != null) {
      indicator = Icon(
        good! ? Icons.check_circle_rounded : Icons.error_rounded,
        size: 16,
        color: good! ? Colors.green : theme.colorScheme.error,
      );
    }

    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
        if (indicator != null) ...[indicator, const SizedBox(width: 8)],
        Text(value,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _AppInfoCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final info = ref.watch(packageInfoProvider);

    return _SectionCard(
      title: l10n.application,
      child: info.when(
        loading: () => const SizedBox(
          height: 24,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (_, __) => Text('—', style: theme.textTheme.bodyMedium),
        data: (data) => Column(
          children: [
            _StatusRow(label: l10n.version, value: data.version),
            const Divider(height: 20),
            _StatusRow(label: l10n.buildNumber, value: data.buildNumber),
            const Divider(height: 20),
            _StatusRow(label: l10n.developer, value: AppConfig.developer),
          ],
        ),
      ),
    );
  }
}
