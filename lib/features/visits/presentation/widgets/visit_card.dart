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
    required this.onSettle,
    required this.onUnsettle,
    this.canEdit = true,
  });

  final Visit visit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSettle;
  final VoidCallback onUnsettle;

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
            // Header: date on the left; the balance action + overflow menu on
            // the right. The settle/undo control lives here (not below the
            // pills) so it reuses the row height the menu already occupies and
            // never makes the card taller.
            Row(
              children: [
                Icon(Icons.event_rounded,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    VisitDate.formatForDisplay(visit.visitDate, locale: locale),
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (visit.amountOwed > 0)
                  _buildBalanceControl(context, theme, l10n),
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
                  // A settled balance shows the owed amount struck through in
                  // the normal color — that is the "paid" status indicator, so
                  // the header control can be a plain Undo action.
                  label: l10n.owedLabel,
                  value: JodMoney.format(visit.amountOwed, locale: locale),
                  color: (visit.amountOwed > 0 && !visit.settled)
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                  strikethrough: visit.settled && visit.amountOwed > 0,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Header control shown when the visit carries a balance. Compact so it fits
  /// beside the overflow menu without adding height.
  Widget _buildBalanceControl(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    const density = VisualDensity.compact;
    const padding = EdgeInsets.symmetric(horizontal: 10);
    const minimumSize = Size(0, 36);
    const tapTarget = MaterialTapTargetSize.shrinkWrap;

    if (!visit.settled) {
      // Owed and unsettled: one tap marks the balance as paid.
      return TextButton.icon(
        onPressed: onSettle,
        style: TextButton.styleFrom(
          visualDensity: density,
          padding: padding,
          minimumSize: minimumSize,
          tapTargetSize: tapTarget,
        ),
        icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
        label: Text(l10n.markPaid),
      );
    }

    // Settled: an outlined Undo button so it clearly reads as a tappable action
    // (the struck-through Owed amount already conveys the paid status).
    return OutlinedButton.icon(
      onPressed: onUnsettle,
      style: OutlinedButton.styleFrom(
        visualDensity: density,
        padding: padding,
        minimumSize: minimumSize,
        tapTargetSize: tapTarget,
        foregroundColor: theme.colorScheme.primary,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      icon: const Icon(Icons.undo_rounded, size: 18),
      label: Text(l10n.actionUndo),
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
    this.strikethrough = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool strikethrough;

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
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
                decoration:
                    strikethrough ? TextDecoration.lineThrough : null,
                decorationColor: color,
                decorationThickness: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
