import 'package:material_ui/material_ui.dart';

import 'package:dental_clinic/core/error/api_exception.dart';
import 'package:dental_clinic/core/error/error_messages.dart';
import 'package:dental_clinic/l10n/app_localizations.dart';

/// A centered error message with a Retry action and an optional collapsible
/// "Technical details" section exposing the request id for troubleshooting.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final ApiException error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 40, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              localizedError(l10n, error),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.actionRetry),
              ),
            ],
            if (error.requestId != null) ...[
              const SizedBox(height: 12),
              TechnicalDetails(requestId: error.requestId!),
            ],
          ],
        ),
      ),
    );
  }
}

/// Collapsible request-id disclosure shown after an error.
class TechnicalDetails extends StatelessWidget {
  const TechnicalDetails({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ExpansionTile(
      dense: true,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: Text(l10n.technicalDetails, style: theme.textTheme.labelMedium),
      children: [
        SelectableText(
          '${l10n.requestId}: $requestId',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
