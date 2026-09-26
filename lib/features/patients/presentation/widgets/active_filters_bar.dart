import 'package:material_ui/material_ui.dart';

import 'package:dental_clinic/features/patients/domain/patient_filters.dart';
import 'package:dental_clinic/features/patients/presentation/widgets/patient_filter_labels.dart';
import 'package:dental_clinic/l10n/app_localizations.dart';

/// A tinted banner under the search field listing every filter in effect.
///
/// Filters are saved between launches, so this makes it obvious on opening
/// the app that the list is filtered. Each chip can be removed on its own,
/// tapped to edit, or everything cleared at once.
class ActiveFiltersBar extends StatelessWidget {
  const ActiveFiltersBar({
    super.key,
    required this.filters,
    required this.onRemove,
    required this.onClearAll,
    required this.onEdit,
  });

  final PatientFilters filters;
  final ValueChanged<PatientFilterKind> onRemove;
  final VoidCallback onClearAll;
  final VoidCallback onEdit;

  static IconData _iconFor(PatientFilterKind kind) => switch (kind) {
        PatientFilterKind.lastVisit => Icons.event_repeat_rounded,
        PatientFilterKind.owesMoney => Icons.receipt_long_rounded,
        PatientFilterKind.hasCredit => Icons.savings_outlined,
        PatientFilterKind.includeArchived => Icons.inventory_2_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final kinds = filters.activeKinds;

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 4, 10),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.filter_alt_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.filtersActiveCount(kinds.length),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onClearAll,
                icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                label: Text(l10n.filtersClearAll),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final kind in kinds)
                  InputChip(
                    avatar: Icon(_iconFor(kind), size: 16),
                    label: Text(
                      PatientFilterLabels.chip(l10n, filters, kind, locale),
                    ),
                    onPressed: onEdit,
                    onDeleted: () => onRemove(kind),
                    deleteIcon: const Icon(Icons.close_rounded, size: 16),
                    deleteButtonTooltipMessage: l10n.filterRemove,
                    backgroundColor: scheme.surface,
                    side: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.8),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
