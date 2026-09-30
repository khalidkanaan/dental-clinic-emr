import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:dental_clinic/core/formatting/date_formatter.dart';
import 'package:dental_clinic/core/widgets/patient_avatar.dart';
import 'package:dental_clinic/features/patients/data/patient.dart';
import 'package:dental_clinic/features/settings/application/settings_controllers.dart';
import 'package:dental_clinic/l10n/app_localizations.dart';

class PatientListTile extends ConsumerWidget {
  const PatientListTile({super.key, required this.patient, required this.onTap});

  final Patient patient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final lastVisit = ref.watch(showLastVisitInListProvider) ? patient.lastVisitDate : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                PatientAvatar(
                  initials: patient.initials,
                  seedText: patient.name,
                  muted: patient.isArchived,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              patient.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (patient.isArchived) ...[
                            const SizedBox(width: 8),
                            _ArchivedChip(label: l10n.archivedChip),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        patient.phoneNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textDirection: TextDirection.ltr,
                      ),
                    ],
                  ),
                ),
                // On the opposite side from the name: the right in English,
                // the left in Arabic (the Row mirrors for right-to-left).
                if (lastVisit != null) ...[
                  const SizedBox(width: 12),
                  _LastVisit(
                    date: VisitDate.formatForDisplay(lastVisit, locale: locale),
                  ),
                ],
                const SizedBox(width: 4),
                Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  color: theme.colorScheme.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact "Last visit / `<date>`" block at the trailing edge of a patient row.
class _LastVisit extends StatelessWidget {
  const _LastVisit({required this.date});

  final String date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    // Read as one phrase by screen readers ("Last visit Sep 29, 2026").
    return Semantics(
      label: l10n.lastVisitLabel(date),
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        // `end` follows the text direction, so this hugs the outer edge in
        // both English and Arabic.
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            l10n.patientLastVisit,
            maxLines: 1,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            date,
            maxLines: 1,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchivedChip extends StatelessWidget {
  const _ArchivedChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
