import 'package:dental_clinic/core/api/api_client.dart';

/// A single patient visit. `amountPaid` and `amountOwed` are kept as integer
/// hundredths of JOD throughout the domain layer and only formatted for display.
class Visit {
  const Visit({
    required this.id,
    required this.patientId,
    required this.visitDate,
    required this.treatmentWorkDone,
    required this.amountPaid,
    required this.amountOwed,
    required this.version,
    this.settledAt,
    this.settled = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String patientId;

  /// `YYYY-MM-DD`.
  final String visitDate;
  final String treatmentWorkDone;

  /// Integer hundredths of JOD.
  final int amountPaid;
  final int amountOwed;

  /// Optimistic-concurrency token; sent as `If-Match` on edit/delete.
  final String version;

  /// When non-null, this visit's balance has been marked as collected. The
  /// `amountOwed` value is kept for the record but no longer counts toward the
  /// patient's outstanding total.
  final String? settledAt;
  final bool settled;

  final String? createdAt;
  final String? updatedAt;

  factory Visit.fromJson(JsonMap json) {
    final settledAt = json['settledAt'] as String?;
    return Visit(
      id: json['id'] as String,
      patientId: (json['patientId'] as String?) ?? '',
      visitDate: (json['visitDate'] as String?) ?? '',
      treatmentWorkDone: (json['treatmentWorkDone'] as String?) ?? '',
      amountPaid: (json['amountPaid'] as num?)?.toInt() ?? 0,
      amountOwed: (json['amountOwed'] as num?)?.toInt() ?? 0,
      version: (json['version'] as String?) ?? '',
      settledAt: settledAt,
      settled: (json['settled'] as bool?) ?? (settledAt != null),
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }
}

/// Input payload for creating or editing a visit.
class VisitInput {
  const VisitInput({
    required this.visitDate,
    required this.treatmentWorkDone,
    required this.amountPaid,
    required this.amountOwed,
  });

  final String visitDate;
  final String treatmentWorkDone;
  final int amountPaid;
  final int amountOwed;

  JsonMap toJson() => {
        'visitDate': visitDate,
        'treatmentWorkDone': treatmentWorkDone,
        'amountPaid': amountPaid,
        'amountOwed': amountOwed,
      };
}
