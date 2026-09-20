import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:material_ui/material_ui.dart';

import 'package:dental_clinic/core/error/api_exception.dart';
import 'package:dental_clinic/core/error/error_messages.dart';
import 'package:dental_clinic/core/formatting/currency_formatter.dart';
import 'package:dental_clinic/features/patients/application/patient_details_controller.dart';
import 'package:dental_clinic/features/patients/application/patient_search_controller.dart';
import 'package:dental_clinic/features/patients/data/patient.dart';
import 'package:dental_clinic/l10n/app_localizations.dart';

/// Opens the credit sheet for [patientId]. Resolves to `true` when the credit
/// was changed and saved.
Future<bool> showPatientCreditSheet(
  BuildContext context, {
  required String patientId,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => PatientCreditSheet(patientId: patientId),
  );
  return saved ?? false;
}

/// Colors for increases/deductions that read well in both themes.
class _CreditColors {
  const _CreditColors._();

  static Color increase(ColorScheme scheme) =>
      scheme.brightness == Brightness.dark
          ? const Color(0xFF6FD88E)
          : const Color(0xFF1B873F);

  static Color increaseContainer(ColorScheme scheme) =>
      increase(scheme).withValues(alpha: 0.14);

  static Color deduction(ColorScheme scheme) => scheme.error;

  static Color deductionContainer(ColorScheme scheme) =>
      scheme.error.withValues(alpha: 0.12);
}

String _signedAmount(int delta) {
  final sign = delta > 0 ? '+' : (delta < 0 ? '−' : '');
  return '$sign${JodMoney.format(delta.abs())}';
}

String _formatTimestamp(DateTime? at, String locale) {
  if (at == null) return '—';
  return DateFormat.yMMMd(locale).add_jm().format(at.toLocal());
}

class PatientCreditSheet extends ConsumerStatefulWidget {
  const PatientCreditSheet({super.key, required this.patientId});

  final String patientId;

  @override
  ConsumerState<PatientCreditSheet> createState() => _PatientCreditSheetState();
}

class _PatientCreditSheetState extends ConsumerState<PatientCreditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final patient = _patient;
    _amountController = TextEditingController(
      text: patient == null ? '' : JodMoney.toEditString(patient.credit),
    );
    _amountController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    super.dispose();
  }

  Patient? get _patient => ref
      .read(patientDetailsControllerProvider(widget.patientId))
      .value
      ?.patient;

  void _onAmountChanged() {
    // Rebuild for the live "adds / deducts" preview and the save button state.
    setState(() => _errorMessage = null);
  }

  /// The entered amount in hundredths, or null if empty/invalid.
  int? get _enteredAmount {
    final raw = _amountController.text.trim();
    if (raw.isEmpty || raw.contains('-')) return null;
    return JodMoney.tryParseToHundredths(raw);
  }

  String? _validate(String? value, AppLocalizations l10n) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return l10n.creditRequired;
    if (raw.contains('-') || raw.contains('−')) return l10n.creditNegative;
    final parsed = JodMoney.tryParseToHundredths(raw);
    if (parsed == null) return l10n.validationAmountInvalid;
    if (parsed < 0) return l10n.creditNegative;
    return null;
  }

  Future<void> _save(Patient patient) async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    final amount = _enteredAmount;
    if (amount == null || amount < 0 || amount == patient.credit) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    // Grab both notifiers before the await: if the sheet is swiped away while
    // saving, `ref` can no longer be used once the request completes.
    final details =
        ref.read(patientDetailsControllerProvider(widget.patientId).notifier);
    final directory = ref.read(patientSearchControllerProvider.notifier);

    try {
      final updated = await details.updateCredit(amount);
      directory.applyPatientChange(updated);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = e.isVersionConflict
            ? l10n.creditChangedElsewhere
            : localizedError(l10n, e);
      });
    } catch (_) {
      // Anything unexpected must not leave the button spinning forever.
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = l10n.errUnknown;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context).languageCode;

    final patient = ref
        .watch(patientDetailsControllerProvider(widget.patientId))
        .value
        ?.patient;

    if (patient == null) {
      return const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final timeline = patient.creditTimeline;
    final media = MediaQuery.of(context);
    final entered = _enteredAmount;
    final delta = entered == null ? 0 : entered - patient.credit;
    final canSave = !_saving && entered != null && delta != 0;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: (media.size.height - media.viewInsets.bottom) * 0.9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SheetHeader(patient: patient),
              const SizedBox(height: 16),
              _BalanceCard(patient: patient, locale: locale),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    l10n.creditHistoryTitle,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  if (timeline.isNotEmpty)
                    Text(
                      '${timeline.length}',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // The history scrolls on its own so the input stays reachable.
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: _HistoryList(timeline: timeline, locale: locale),
              ),
              const SizedBox(height: 20),
              if (patient.isArchived)
                _InfoBanner(
                  icon: Icons.inventory_2_outlined,
                  message: l10n.creditArchivedNote,
                )
              else
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _amountController,
                        enabled: !_saving,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: false,
                        ),
                        inputFormatters: [
                          // Negative values can't be typed or pasted.
                          FilteringTextInputFormatter.deny(RegExp(r'[-−–+\s]')),
                          LengthLimitingTextInputFormatter(12),
                        ],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (canSave) _save(patient);
                        },
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (value) => _validate(value, l10n),
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          labelText: l10n.creditNewBalanceLabel,
                          prefixIcon:
                              const Icon(Icons.account_balance_wallet_outlined),
                          suffixText: 'JOD',
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        alignment: Alignment.topCenter,
                        child: delta == 0
                            ? const SizedBox(width: double.infinity)
                            : Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: _DeltaPreview(delta: delta),
                                ),
                              ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        _InfoBanner(
                          icon: Icons.error_outline_rounded,
                          message: _errorMessage!,
                          isError: true,
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: canSave ? () => _save(patient) : null,
                        child: _saving
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2.5),
                              )
                            : Text(l10n.creditSave),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.patient});

  final Patient patient;

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
          child: Icon(
            Icons.account_balance_wallet_rounded,
            color: scheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.creditSheetTitle,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                patient.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.patient, required this.locale});

  final Patient patient;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final updatedAt = patient.creditUpdatedAt == null
        ? null
        : DateTime.tryParse(patient.creditUpdatedAt!);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            scheme.primaryContainer,
            scheme.primaryContainer.withValues(alpha: 0.55),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.creditCurrentBalance,
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            JodMoney.format(patient.credit, locale: locale),
            textDirection: TextDirection.ltr,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.onPrimaryContainer,
              letterSpacing: -0.5,
            ),
          ),
          if (updatedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              l10n.creditLastUpdated(_formatTimestamp(updatedAt, locale)),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onPrimaryContainer.withValues(alpha: 0.75),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.timeline, required this.locale});

  final List<CreditChange> timeline;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    if (timeline.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, color: scheme.onSurfaceVariant),
            const SizedBox(height: 6),
            Text(
              l10n.creditHistoryEmpty,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: timeline.length,
        separatorBuilder: (_, _) => Divider(
          height: 1,
          indent: 64,
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
        itemBuilder: (context, index) =>
            _HistoryRow(change: timeline[index], locale: locale),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.change, required this.locale});

  final CreditChange change;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    final IconData icon;
    final Color fg;
    final Color bg;
    final String title;
    final String amountText;

    if (change.isIncrease) {
      icon = Icons.arrow_upward_rounded;
      fg = _CreditColors.increase(scheme);
      bg = _CreditColors.increaseContainer(scheme);
      title = l10n.creditIncrease;
      amountText = _signedAmount(change.delta);
    } else if (change.isDeduction) {
      icon = Icons.arrow_downward_rounded;
      fg = _CreditColors.deduction(scheme);
      bg = _CreditColors.deductionContainer(scheme);
      title = l10n.creditDeduction;
      amountText = _signedAmount(change.delta);
    } else {
      icon = Icons.flag_rounded;
      fg = scheme.primary;
      bg = scheme.primary.withValues(alpha: 0.12);
      title = l10n.creditStartingBalance;
      amountText = JodMoney.format(change.balance);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: fg),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  _formatTimestamp(change.at, locale),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amountText,
                textDirection: TextDirection.ltr,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: change.isStartingBalance ? scheme.onSurface : fg,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (!change.isStartingBalance)
                Text(
                  l10n.creditBalanceAfter(JodMoney.format(change.balance)),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeltaPreview extends StatelessWidget {
  const _DeltaPreview({required this.delta});

  final int delta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final increase = delta > 0;
    final fg = increase
        ? _CreditColors.increase(scheme)
        : _CreditColors.deduction(scheme);
    final bg = increase
        ? _CreditColors.increaseContainer(scheme)
        : _CreditColors.deductionContainer(scheme);
    final amount = JodMoney.format(delta.abs());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            increase ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 16,
            color: fg,
          ),
          const SizedBox(width: 6),
          Text(
            increase
                ? l10n.creditPreviewIncrease(amount)
                : l10n.creditPreviewDeduction(amount),
            style: theme.textTheme.labelLarge
                ?.copyWith(color: fg, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.message,
    this.isError = false,
  });

  final IconData icon;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = isError ? scheme.onErrorContainer : scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError
            ? scheme.errorContainer
            : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}
