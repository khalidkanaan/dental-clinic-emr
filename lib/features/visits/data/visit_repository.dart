import 'package:uuid/uuid.dart';

import 'package:dental_clinic/core/api/api_client.dart';
import 'package:dental_clinic/core/api/paginated.dart';
import 'package:dental_clinic/features/patients/data/patient.dart';
import 'package:dental_clinic/features/visits/data/visit.dart';

/// Result of adding or editing a visit.
///
/// Visit changes update the patient on the server (last visit date, amount
/// owed and version), so the API returns the refreshed patient alongside the
/// visit. [patient] is null only when talking to an older API that does not
/// send it.
class VisitMutationResult {
  const VisitMutationResult({required this.visit, this.patient});

  final Visit visit;
  final Patient? patient;
}

class VisitRepository {
  VisitRepository(this._api);

  final ApiClient _api;
  static const _uuid = Uuid();

  /// Lists a patient's visits, newest first.
  Future<Paginated<Visit>> list(
    String patientId, {
    int limit = 30,
    String? cursor,
  }) async {
    final json = await _api.get('/patients/$patientId/visits', query: {
      'limit': limit,
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    });
    final items = (json['visits'] as List? ?? [])
        .map((e) => Visit.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return Paginated(items: items, nextCursor: json['nextCursor'] as String?);
  }

  Future<VisitMutationResult> add(
    String patientId,
    VisitInput input, {
    required String idempotencyKey,
  }) async {
    final json = await _api.post(
      '/patients/$patientId/visits',
      body: input.toJson(),
      headers: {'Idempotency-Key': idempotencyKey},
    );
    return VisitMutationResult(
      visit: Visit.fromJson((json['visit'] as Map).cast<String, dynamic>()),
      patient: _patientFrom(json),
    );
  }

  Future<VisitMutationResult> update(
    String patientId,
    String visitId, {
    required String version,
    required VisitInput input,
  }) async {
    final json = await _api.patch(
      '/patients/$patientId/visits/$visitId',
      headers: {'If-Match': version},
      body: input.toJson(),
    );
    return VisitMutationResult(
      visit: Visit.fromJson((json['visit'] as Map).cast<String, dynamic>()),
      patient: _patientFrom(json),
    );
  }

  /// Deletes a visit and returns the refreshed patient (null with an older
  /// API).
  Future<Patient?> delete(
    String patientId,
    String visitId, {
    required String version,
  }) async {
    final json = await _api.delete(
      '/patients/$patientId/visits/$visitId',
      headers: {'If-Match': version},
    );
    return _patientFrom(json);
  }

  static Patient? _patientFrom(JsonMap json) {
    final raw = json['patient'];
    return raw is Map ? Patient.fromJson(raw.cast<String, dynamic>()) : null;
  }

  String newIdempotencyKey() => _uuid.v4();
}
