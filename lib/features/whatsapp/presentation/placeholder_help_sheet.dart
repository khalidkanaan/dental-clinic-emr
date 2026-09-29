import 'package:material_ui/material_ui.dart';

import 'package:dental_clinic/features/whatsapp/application/whatsapp_message.dart';
import 'package:dental_clinic/features/whatsapp/domain/message_template.dart';
import 'package:dental_clinic/features/whatsapp/presentation/whatsapp_brand.dart';
import 'package:dental_clinic/l10n/app_localizations.dart';

/// Screens at least this wide get a centered dialog instead of a bottom sheet.
const double _dialogBreakpoint = 600;

/// Shows every placeholder with what it means and an example value.
///
/// When [onInsert] is given, tapping a placeholder passes its token back
/// (e.g. `{Patient}`) and closes the help.
Future<void> showPlaceholderHelp(
  BuildContext context, {
  required Map<MessagePlaceholder, String> sampleValues,
  ValueChanged<String>? onInsert,
}) async {
  if (MediaQuery.sizeOf(context).width >= _dialogBreakpoint) {
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: PlaceholderHelp(
            sampleValues: sampleValues,
            onInsert: onInsert,
            asDialog: true,
          ),
        ),
      ),
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => PlaceholderHelp(
      sampleValues: sampleValues,
      onInsert: onInsert,
    ),
  );
}

/// Localized description of what a placeholder is replaced with.
String placeholderDescription(AppLocalizations l10n, MessagePlaceholder p) {
  return switch (p) {
    MessagePlaceholder.patient => l10n.placeholderPatient,
    MessagePlaceholder.firstName => l10n.placeholderFirstName,
    MessagePlaceholder.phone => l10n.placeholderPhone,
    MessagePlaceholder.clinic => l10n.placeholderClinic,
    MessagePlaceholder.today => l10n.placeholderToday,
    MessagePlaceholder.lastVisit => l10n.placeholderLastVisit,
    MessagePlaceholder.lastTreatment => l10n.placeholderLastTreatment,
    MessagePlaceholder.lastPaid => l10n.placeholderLastPaid,
    MessagePlaceholder.lastOwed => l10n.placeholderLastOwed,
    MessagePlaceholder.credit => l10n.placeholderCredit,
  };
}

class PlaceholderHelp extends StatelessWidget {
  const PlaceholderHelp({
    super.key,
    required this.sampleValues,
    this.onInsert,
    this.asDialog = false,
  });

  final Map<MessagePlaceholder, String> sampleValues;
  final ValueChanged<String>? onInsert;
  final bool asDialog;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = Localizations.localeOf(context).languageCode;
    final media = MediaQuery.of(context);

    // "Hello {Patient}," -> "Hello Sara Ahmad," as a quick example.
    final exampleTemplate =
        WhatsAppMessage.defaultTemplate(l10n, language).split('\n').first;
    final exampleResult =
        MessageTemplate.render(exampleTemplate, sampleValues);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: media.size.height * (asDialog ? 0.85 : 0.9),
      ),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(
          asDialog ? 24 : 20,
          asDialog ? 24 : 0,
          asDialog ? 24 : 20,
          24,
        ),
        children: [
          _Header(
            onClose: asDialog ? () => Navigator.of(context).maybePop() : null,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.placeholdersIntro,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 16),
          _ExampleCard(template: exampleTemplate, result: exampleResult),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (index, placeholder)
                    in MessagePlaceholder.values.indexed) ...[
                  if (index > 0)
                    Divider(
                      height: 1,
                      color: scheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  _PlaceholderRow(
                    token: placeholder.tokenFor(language),
                    description: placeholderDescription(l10n, placeholder),
                    example: sampleValues[placeholder] ?? '',
                    onTap: onInsert == null
                        ? null
                        : () {
                            onInsert!(placeholder.tokenFor(language));
                            Navigator.of(context).maybePop();
                          },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_outline_rounded,
                  size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.placeholdersTip(
                    MessagePlaceholder.patient.englishToken,
                    MessagePlaceholder.patient.arabicToken,
                  ),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.data_object_rounded,
              color: scheme.onPrimaryContainer),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            l10n.placeholdersTitle,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (onClose != null)
          IconButton(
            tooltip: l10n.actionClose,
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
      ],
    );
  }
}

/// Shows a template line and what it turns into, as a WhatsApp bubble.
class _ExampleCard extends StatelessWidget {
  const _ExampleCard({required this.template, required this.result});

  final String template;
  final String result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.placeholdersExample,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            template,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Icon(Icons.arrow_downward_rounded,
                size: 18, color: scheme.onSurfaceVariant),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: WhatsAppColors.bubble(scheme),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              result,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: WhatsAppColors.onBubble(scheme)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderRow extends StatelessWidget {
  const _PlaceholderRow({
    required this.token,
    required this.description,
    required this.example,
    this.onTap,
  });

  final String token;
  final String description;
  final String example;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      token,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(description, style: theme.textTheme.bodyMedium),
                  if (example.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      l10n.placeholdersExampleValue(example),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 12),
              Tooltip(
                message: l10n.placeholdersTapToInsert,
                child: Icon(Icons.add_circle_outline_rounded,
                    color: scheme.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
