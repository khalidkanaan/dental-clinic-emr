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
import 'package:dental_clinic/features/patients/application/patient_search_controller.dart';
import 'package:dental_clinic/features/patients/data/patient.dart';
import 'package:dental_clinic/features/visits/data/visit.dart';
import 'package:dental_clinic/l10n/app_localizations.dart';

class PatientFormScreen extends ConsumerStatefulWidget {
  const PatientFormScreen({super.key, this.patient});

  /// Non-null when editing an existing patient.
  final Patient? patient;

  bool get isEditing => patient != null;

  @override
  ConsumerState<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends ConsumerState<PatientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  final _treatmentController = TextEditingController();
  final _paidController = TextEditingController();
  final _owedController = TextEditingController();

  bool _addFirstVisit = false;
  DateTime _visitDate = DateTime.now();
  bool _saving = false;
  late final String _idempotencyKey;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.patient?.name ?? '');
    _phoneController =
        TextEditingController(text: widget.patient?.phoneNumber ?? '');
    _idempotencyKey = ref.read(patientRepositoryProvider).newIdempotencyKey();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _treatmentController.dispose();
    _paidController.dispose();
    _owedController.dispose();
    super.dispose();
  }

  int _amount(TextEditingController c) {
    final raw = c.text.trim();
    if (raw.isEmpty) return 0;
    return JodMoney.tryParseToHundredths(raw) ?? 0;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _visitDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _visitDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    if (widget.isEditing) {
      await _saveEdit();
    } else {
      await _saveCreate();
    }
    if (mounted && _saving) setState(() => _saving = false);
  }

  Future<void> _saveEdit() async {
    final l10n = AppLocalizations.of(context);
    final patient = widget.patient!;
    final controller =
        ref.read(patientDetailsControllerProvider(patient.id).notifier);
    try {
      final updated = await controller.editPatient(
        name: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
      );
      ref.read(patientSearchControllerProvider.notifier).applyPatientChange(updated);
      if (!mounted) return;
      showAppSnackBar(context, l10n.patientSaved);
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      if (e.isVersionConflict) {
        final reload = await showVersionConflictDialog(context);
        if (reload) {
          await controller.reload();
          if (mounted) context.pop();
        }
        return;
      }
      if (e.code == ApiErrorCode.patientExists ||
          e.code == ApiErrorCode.patientArchived) {
        await _showDuplicateDialog(e);
        return;
      }
      showAppSnackBar(context, localizedError(l10n, e));
    }
  }

  Future<void> _saveCreate() async {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(patientRepositoryProvider);
    VisitInput? initialVisit;
    if (_addFirstVisit) {
      initialVisit = VisitInput(
        visitDate: VisitDate.toApiString(_visitDate),
        treatmentWorkDone: _treatmentController.text.trim(),
        amountPaid: _amount(_paidController),
        amountOwed: _amount(_owedController),
      );
    }
    try {
      final result = await repo.create(
        name: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        initialVisit: initialVisit,
        idempotencyKey: _idempotencyKey,
      );
      ref
          .read(patientSearchControllerProvider.notifier)
          .applyPatientChange(result.patient);
      if (!mounted) return;
      showAppSnackBar(context, l10n.patientSaved);
      // Replace the form with the new patient's details.
      context.pushReplacement('/patient/${result.patient.id}');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      if (e.code == ApiErrorCode.patientExists ||
          e.code == ApiErrorCode.patientArchived) {
        await _showDuplicateDialog(e);
        return;
      }
      showAppSnackBar(context, localizedError(l10n, e));
    }
  }

  Future<void> _showDuplicateDialog(ApiException e) async {
    final l10n = AppLocalizations.of(context);
    final id = e.conflictPatientId;
    final archived = e.code == ApiErrorCode.patientArchived;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            archived ? l10n.duplicateArchivedTitle : l10n.duplicateActiveTitle),
        content: Text(
            archived ? l10n.duplicateArchivedBody : l10n.duplicateActiveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.actionCancel),
          ),
          if (id != null && archived) ...[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.pushReplacement('/patient/$id');
              },
              child: Text(l10n.actionViewPatient),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.pushReplacement('/patient/$id', extra: _restoreExtra);
              },
              child: Text(l10n.actionRestorePatient),
            ),
          ],
          if (id != null && !archived)
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.pushReplacement('/patient/$id');
              },
              child: Text(l10n.actionOpenPatient),
            ),
        ],
      ),
    );
  }

  static const _restoreExtra = {'autoRestore': true};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.isEditing ? l10n.editPatientTitle : l10n.createPatientTitle),
      ),
      body: SafeArea(
        child: MaxWidth(
          maxWidth: 600,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                TextFormField(
                  controller: _nameController,
                  autofocus: !widget.isEditing,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: l10n.fieldName,
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? l10n.validationNameRequired
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: l10n.fieldPhone,
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? l10n.validationPhoneRequired
                      : null,
                ),
                if (!widget.isEditing) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.addFirstVisit),
                    value: _addFirstVisit,
                    onChanged: (v) => setState(() => _addFirstVisit = v),
                  ),
                  if (_addFirstVisit) _buildVisitFields(l10n, locale),
                ],
                const SizedBox(height: 24),
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

  Widget _buildVisitFields(AppLocalizations l10n, String locale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _pickDate,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: l10n.fieldVisitDate,
              prefixIcon: const Icon(Icons.calendar_today_rounded, size: 20),
            ),
            child: Text(
              VisitDate.formatForDisplay(VisitDate.toApiString(_visitDate),
                  locale: locale),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _treatmentController,
          minLines: 2,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: l10n.fieldTreatment,
            alignLabelWithHint: true,
          ),
          validator: (value) {
            if (!_addFirstVisit) return null;
            return (value ?? '').trim().isEmpty
                ? l10n.validationTreatmentRequired
                : null;
          },
        ),
        const SizedBox(height: 16),
        AmountField(controller: _paidController, label: l10n.fieldAmountPaid),
        const SizedBox(height: 16),
        AmountField(controller: _owedController, label: l10n.fieldAmountOwed),
      ],
    );
  }
}
