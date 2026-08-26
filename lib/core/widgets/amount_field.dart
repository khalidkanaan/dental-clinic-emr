import 'package:material_ui/material_ui.dart';

import 'package:dental_clinic/core/formatting/currency_formatter.dart';
import 'package:dental_clinic/l10n/app_localizations.dart';

/// A text field for entering a JOD amount. Validates that the input parses to a
/// non-negative integer number of hundredths (at most two decimal places).
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    required this.label,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextFormField(
      controller: controller,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'JOD',
      ),
      validator: (value) {
        final raw = (value ?? '').trim();
        if (raw.isEmpty) return null; // empty is treated as 0 on submit
        if (JodMoney.tryParseToHundredths(raw) == null) {
          return l10n.validationAmountInvalid;
        }
        return null;
      },
    );
  }
}
