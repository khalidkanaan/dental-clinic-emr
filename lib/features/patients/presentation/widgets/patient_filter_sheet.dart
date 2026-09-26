import 'package:material_ui/material_ui.dart';

import 'package:dental_clinic/features/patients/domain/patient_filters.dart';
import 'package:dental_clinic/features/patients/presentation/widgets/custom_dates_dialog.dart';
import 'package:dental_clinic/features/patients/presentation/widgets/patient_filter_labels.dart';
import 'package:dental_clinic/l10n/app_localizations.dart';

/// Screens at least this wide get a centered dialog instead of a bottom sheet
/// (same breakpoint as the patient credit panel).
const double _dialogBreakpoint = 600;

/// Opens the patient filter panel: a bottom sheet on phones and a compact
/// centered dialog on wider screens.
///
/// Resolves to the filters the user applied, or null if they dismissed the
/// panel without applying (in which case nothing should change).
Future<PatientFilters?> showPatientFilterSheet(
  BuildContext context, {
  required PatientFilters initial,
}) {
  if (MediaQuery.sizeOf(context).width >= _dialogBreakpoint) {
    return showDialog<PatientFilters>(
      context: context,
      builder: (_) => Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: PatientFilterPanel(initial: initial, asDialog: true),
        ),
      ),
    );
  }

  return showModalBottomSheet<PatientFilters>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => PatientFilterPanel(initial: initial),
  );
}

/// Edits a draft copy of the filters. Nothing is applied until the user taps
/// "Show results", so trying options never triggers a reload.
class PatientFilterPanel extends StatefulWidget {
  const PatientFilterPanel({
    super.key,
    required this.initial,
    this.asDialog = false,
  });

  final PatientFilters initial;

  /// True when shown in a centered dialog (wide screens); adds a close
  /// button in place of the sheet's drag handle.
  final bool asDialog;

  @override
  State<PatientFilterPanel> createState() => _PatientFilterPanelState();
}

class _PatientFilterPanelState extends State<PatientFilterPanel> {
  late PatientFilters _draft = widget.initial;

  static const _presets = [
    LastVisitPreset.any,
    LastVisitPreset.pastMonth,
    LastVisitPreset.past3Months,
    LastVisitPreset.past6Months,
    LastVisitPreset.over6MonthsAgo,
    LastVisitPreset.over1YearAgo,
    LastVisitPreset.custom,
  ];

  void _update(PatientFilters next) => setState(() => _draft = next);

  Future<void> _selectPreset(LastVisitPreset preset) async {
    if (preset != LastVisitPreset.custom) {
      _update(_draft.withLastVisit(preset));
      return;
    }
    // Choosing "Custom dates" goes straight to the dates dialog. If dates
    // were picked before, reuse them instead of asking again.
    if (_draft.customFrom != null && _draft.customTo != null) {
      _update(_draft.withLastVisit(LastVisitPreset.custom));
      return;
    }
    await _pickCustomDates();
  }

  /// Opens the compact From / To (or single day) dialog.
  Future<void> _pickCustomDates() async {
    final picked = await showCustomDatesDialog(
      context,
      initialFrom: _draft.customFrom,
      initialTo: _draft.customTo,
    );
    // Cancelled: keep whatever was selected before.
    if (picked == null || !mounted) return;

    _update(_draft.withLastVisit(
      LastVisitPreset.custom,
      customFrom: picked.from,
      customTo: picked.to,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context).languageCode;
    final media = MediaQuery.of(context);
    final asDialog = widget.asDialog;
    final horizontal = asDialog ? 24.0 : 20.0;

    final showCustomField = _draft.lastVisit == LastVisitPreset.custom;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: media.size.height * (asDialog ? 0.85 : 0.9),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              horizontal,
              asDialog ? 20 : 0,
              asDialog ? 12 : horizontal - 8,
              8,
            ),
            child: _PanelHeader(
              canReset: _draft.isActive,
              onReset: () => _update(PatientFilters.none),
              onClose:
                  asDialog ? () => Navigator.of(context).maybePop() : null,
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(horizontal, 4, horizontal, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SectionHeader(
                    icon: Icons.event_repeat_rounded,
                    title: l10n.filterLastVisitSection,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final preset in _presets)
                        ChoiceChip(
                          label: Text(PatientFilterLabels.preset(l10n, preset)),
                          selected: _draft.lastVisit == preset,
                          showCheckmark: false,
                          avatar: preset == LastVisitPreset.custom
                              ? const Icon(Icons.date_range_rounded, size: 18)
                              : null,
                          onSelected: (_) => _selectPreset(preset),
                        ),
                    ],
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: showCustomField
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: _DateRangeField(
                              text: _draft.customFrom != null &&
                                      _draft.customTo != null
                                  ? PatientFilterLabels.dateRange(
                                      l10n,
                                      _draft.customFrom!,
                                      _draft.customTo!,
                                      locale,
                                    )
                                  : l10n.filterChooseDates,
                              onTap: _pickCustomDates,
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  const _SectionDivider(),
                  _SectionHeader(
                    icon: Icons.account_balance_wallet_outlined,
                    title: l10n.filterBalanceSection,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: Text(l10n.filterOwesMoney),
                        avatar: const Icon(Icons.receipt_long_rounded, size: 18),
                        selected: _draft.owesMoney,
                        showCheckmark: false,
                        onSelected: (value) =>
                            _update(_draft.copyWith(owesMoney: value)),
                      ),
                      FilterChip(
                        label: Text(l10n.filterHasCredit),
                        avatar: const Icon(Icons.payment_outlined, size: 18),
                        selected: _draft.hasCredit,
                        showCheckmark: false,
                        onSelected: (value) =>
                            _update(_draft.copyWith(hasCredit: value)),
                      ),
                    ],
                  ),
                  const _SectionDivider(),
                  _SectionHeader(
                    icon: Icons.inventory_2_outlined,
                    title: l10n.filterStatusSection,
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.showArchived),
                    value: _draft.includeArchived,
                    onChanged: (value) =>
                        _update(_draft.copyWith(includeArchived: value)),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.6)),
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontal,
              12,
              horizontal,
              asDialog ? 20 : 16,
            ),
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(_draft),
              icon: const Icon(Icons.check_rounded),
              label: Text(l10n.filterShowResults),
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.canReset,
    required this.onReset,
    this.onClose,
  });

  final bool canReset;
  final VoidCallback onReset;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.tune_rounded, color: scheme.onPrimaryContainer),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            l10n.filtersTitle,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        TextButton(
          onPressed: canReset ? onReset : null,
          child: Text(l10n.filterReset),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        Icon(icon, size: 20, color: scheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Divider(
        height: 1,
        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6),
      ),
    );
  }
}

/// Tappable field showing the chosen custom range; opens the range picker.
class _DateRangeField extends StatelessWidget {
  const _DateRangeField({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.filterCustomRange,
          prefixIcon: const Icon(Icons.calendar_month_rounded, size: 20),
          suffixIcon: const Icon(Icons.edit_calendar_outlined, size: 20),
        ),
        child: Text(text),
      ),
    );
  }
}
