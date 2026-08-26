import 'package:material_ui/material_ui.dart';

import 'package:dental_clinic/core/formatting/currency_formatter.dart';
import 'package:dental_clinic/core/formatting/date_formatter.dart';
import 'package:dental_clinic/features/visits/data/visit.dart';
import 'package:dental_clinic/l10n/app_localizations.dart';

class VisitCard extends StatelessWidget {
  const VisitCard({
    super.key,
    required this.visit,
    required this.onEdit,
    required this.onDelete,
    this.canEdit = true,
  });

  final Visit visit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// When false (archived patient) the Edit action is hidden; Delete remains,
  /// so visits can still be removed to make the patient eligible for purge.
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_rounded,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  VisitDate.formatForDisplay(visit.visitDate, locale: locale),
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                _VisitMenu(
                  onEdit: onEdit,
                  onDelete: onDelete,
                  canEdit: canEdit,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              visit.treatmentWorkDone,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _AmountPill(
                  label: l10n.paidLabel,
                  value: JodMoney.format(visit.amountPaid, locale: locale),
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                _AmountPill(
                  label: l10n.owedLabel,
                  value: JodMoney.format(visit.amountOwed, locale: locale),
                  color: visit.amountOwed > 0
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VisitMenu extends StatelessWidget {
  const _VisitMenu({
    required this.onEdit,
    required this.onDelete,
    this.canEdit = true,
  });
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<int>(
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (value) => value == 0 ? onEdit() : onDelete(),
      itemBuilder: (context) => [
        if (canEdit)
          PopupMenuItem(
            value: 0,
            child: Row(
              children: [
                const Icon(Icons.edit_outlined, size: 20),
                const SizedBox(width: 12),
                Text(l10n.actionEdit),
              ],
            ),
          ),
        PopupMenuItem(
          value: 1,
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, size: 20, color: scheme.error),
              const SizedBox(width: 12),
              Text(l10n.actionDelete, style: TextStyle(color: scheme.error)),
            ],
          ),
        ),
      ],
    );
  }
}

class _AmountPill extends StatelessWidget {
  const _AmountPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
