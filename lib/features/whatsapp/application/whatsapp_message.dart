import 'package:intl/intl.dart' show DateFormat;

import 'package:dental_clinic/core/formatting/currency_formatter.dart';
import 'package:dental_clinic/core/formatting/date_formatter.dart';
import 'package:dental_clinic/features/patients/data/patient.dart';
import 'package:dental_clinic/features/visits/data/visit.dart';
import 'package:dental_clinic/features/whatsapp/domain/message_template.dart';
import 'package:dental_clinic/l10n/app_localizations.dart';

/// Builds the WhatsApp message text for a patient.
class WhatsAppMessage {
  const WhatsAppMessage._();

  /// The built-in message for the app's current language. Uses placeholder
  /// names in the same language so the text reads naturally when edited.
  static String defaultTemplate(AppLocalizations l10n, String languageCode) {
    return l10n.whatsappDefaultTemplate(
      MessagePlaceholder.patient.tokenFor(languageCode),
      MessagePlaceholder.clinic.tokenFor(languageCode),
    );
  }

  /// The real values for [patient]. [visits] may be only the loaded page;
  /// the most recent visit is picked by date.
  static Map<MessagePlaceholder, String> valuesFor({
    required Patient patient,
    required List<Visit> visits,
    required String clinicName,
    required String locale,
    DateTime? now,
  }) {
    Visit? last;
    for (final visit in visits) {
      // `YYYY-MM-DD` strings sort correctly as text.
      if (last == null || visit.visitDate.compareTo(last.visitDate) > 0) {
        last = visit;
      }
    }

    return _values(
      name: patient.name,
      phone: patient.phoneNumber,
      clinicName: clinicName,
      locale: locale,
      now: now ?? DateTime.now(),
      lastVisitDate: last?.visitDate,
      lastTreatment: last?.treatmentWorkDone,
      lastPaid: last?.amountPaid,
      lastOwed: last?.amountOwed,
      credit: patient.credit,
    );
  }

  /// Example values used for the live preview and the placeholder help.
  static Map<MessagePlaceholder, String> sampleValues({
    required AppLocalizations l10n,
    required String clinicName,
    required String locale,
  }) {
    final now = DateTime.now();
    return _values(
      name: l10n.whatsappSampleName,
      phone: '0791234567',
      clinicName: clinicName,
      locale: locale,
      now: now,
      lastVisitDate:
          VisitDate.toApiString(now.subtract(const Duration(days: 14))),
      lastTreatment: l10n.whatsappSampleTreatment,
      lastPaid: 2500,
      lastOwed: 1000,
      credit: 500,
    );
  }

  static Map<MessagePlaceholder, String> _values({
    required String name,
    required String phone,
    required String clinicName,
    required String locale,
    required DateTime now,
    String? lastVisitDate,
    String? lastTreatment,
    int? lastPaid,
    int? lastOwed,
    required int credit,
  }) {
    final trimmedName = name.trim();
    final firstName = trimmedName.isEmpty
        ? ''
        : trimmedName.split(RegExp(r'\s+')).first;

    return {
      MessagePlaceholder.patient: trimmedName,
      MessagePlaceholder.firstName: firstName,
      MessagePlaceholder.phone: phone,
      MessagePlaceholder.clinic: clinicName,
      MessagePlaceholder.today: DateFormat.yMMMd(locale).format(now),
      MessagePlaceholder.lastVisit: lastVisitDate == null
          ? ''
          : VisitDate.formatForDisplay(lastVisitDate, locale: locale),
      MessagePlaceholder.lastTreatment: lastTreatment ?? '',
      MessagePlaceholder.lastPaid:
          lastPaid == null ? '' : JodMoney.format(lastPaid, locale: locale),
      MessagePlaceholder.lastOwed:
          lastOwed == null ? '' : JodMoney.format(lastOwed, locale: locale),
      MessagePlaceholder.credit: JodMoney.format(credit, locale: locale),
    };
  }
}
