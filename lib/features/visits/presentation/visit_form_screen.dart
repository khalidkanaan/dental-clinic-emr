import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:dental_clinic/core/error/api_exception.dart';
import 'package:dental_clinic/core/error/error_messages.dart';
import 'package:dental_clinic/core/formatting/currency_formatter.dart';
import 'package:dental_clinic/core/formatting/date_formatter.dart';
import 'package:dental_clinic/core/providers.dart';
import 'package:dental_clinic/core/widgets/amount_field.dart';
import 'package:dental_clinic/core/widgets/app_dialogs.dart';
import 'package:dental_clinic/core/widgets/max_width.dart';
import 'package:dental_clinic/features/patients/application/patient_details_controller.dart';
import 'package:dental_clinic/features/visits/data/visit.dart';
import 'package:dental_clinic/l10n/app_localizations.dart';

class VisitFormScreen extends ConsumerStatefulWidget {
  const VisitFormScreen({super.key, required this.patientId, this.visit});

  final String patientId;

  /// Non-null when editing an existing visit.
  final Visit? visit;

  bool get isEditing => visit != null;

  @override
  ConsumerState<VisitFormScreen> createState() => _VisitFormScreenState();
}

class _VisitFormScreenState extends ConsumerState<VisitFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _treatmentController;
  late final TextEditingController _paidController;
  late final TextEditingController _owedController;
  late DateTime _date;

  /// Stable across retries so a timed-out create is not duplicated.
  late final String _idempotencyKey;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final v = widget.visit;
    _treatmentController = TextEditingController(text: v?.treatmentWorkDone ?? '');
    _paidController = TextEditingController(
        text: v == null ? '' : JodMoney.toEditString(v.amountPaid));
    _owedController = TextEditingController(
        text: v == null ? '' : JodMoney.toEditString(v.amountOwed));
    _date = v != null
        ? (VisitDate.tryParseApi(v.visitDate) ?? DateTime.now())
        : DateTime.now();
    _idempotencyKey =
        ref.read(visitRepositoryProvider).newIdempotencyKey();
  }

  @override
  void dispose() {
    _treatmentController.dispose();
    _paidController.dispose();
    _owedController.dispose();
    super.dispose();
  }

  int _amount(TextEditingController controller) {
    final raw = controller.text.trim();
    if (raw.isEmpty) return 0;
    return JodMoney.tryParseToHundredths(raw) ?? 0;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final l10n = AppLocalizations.of(context);
    final controller =
        ref.read(patientDetailsControllerProvider(widget.patientId).notifier);
    final input = VisitInput(
      visitDate: VisitDate.toApiString(_date),
      treatmentWorkDone: _treatmentController.text.trim(),
      amountPaid: _amount(_paidController),
      amountOwed: _amount(_owedController),
    );

    try {
      if (widget.isEditing) {
        await controller.editVisit(
          widget.visit!.id,
          version: widget.visit!.version,
          input: input,
        );
      } else {
        await controller.addVisit(input, idempotencyKey: _idempotencyKey);
      }
      if (!mounted) return;
      showAppSnackBar(
          context, widget.isEditing ? l10n.visitUpdated : l10n.visitAdded);
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      if (e.isVersionConflict) {
        final reload = await showVersionConflictDialog(context);
        if (reload && mounted) {
          await controller.reload();
          if (mounted) context.pop();
        }
        return;
      }
      showAppSnackBar(context, localizedError(l10n, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? l10n.editVisitTitle : l10n.addVisitTitle),
      ),
      body: SafeArea(
        child: MaxWidth(
          maxWidth: 600,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _DateField(
                  label: l10n.fieldVisitDate,
                  valueText:
                      VisitDate.formatForDisplay(VisitDate.toApiString(_date),
                          locale: locale),
                  onTap: _pickDate,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _treatmentController,
                  minLines: 3,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l10n.fieldTreatment,
                    alignLabelWithHint: true,
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? l10n.validationTreatmentRequired
                      : null,
                ),
                const SizedBox(height: 16),
                AmountField(
                  controller: _paidController,
                  label: l10n.fieldAmountPaid,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                AmountField(
                  controller: _owedController,
                  label: l10n.fieldAmountOwed,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : Text(l10n.actionSave),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.valueText,
    required this.onTap,
  });

  final String label;
  final String valueText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_rounded, size: 20),
        ),
        child: Text(valueText),
      ),
    );
  }
}
