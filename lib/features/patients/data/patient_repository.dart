import 'package:uuid/uuid.dart';

import 'package:dental_clinic/core/api/api_client.dart';
import 'package:dental_clinic/core/api/paginated.dart';
import 'package:dental_clinic/features/patients/data/patient.dart';
import 'package:dental_clinic/features/patients/domain/patient_filters.dart';
import 'package:dental_clinic/features/visits/data/visit.dart';

/// Result of loading a patient with the first page of visits in one request.
class PatientWithVisits {
  const PatientWithVisits({
    required this.patient,
    required this.visits,
    this.nextVisitsCursor,
  });

  final Patient patient;
  final List<Visit> visits;
  final String? nextVisitsCursor;
}

/// Result of creating a patient (optionally with an initial visit).
class CreatePatientResult {
  const CreatePatientResult({required this.patient, this.initialVisit});

  final Patient patient;
  final Visit? initialVisit;
}

class PatientRepository {
  PatientRepository(this._api);

  final ApiClient _api;
  static const _uuid = Uuid();

  /// Search / list patients. Prefix mode by default.
  ///
  /// [filters] are combined (AND) with the text [query]. Relative date
  /// filters such as "past month" are resolved against [today], which
  /// defaults to now; pass the same value for every page of one search so
  /// pagination stays consistent across midnight.
  Future<Paginated<Patient>> search({
    String query = '',
    PatientFilters filters = PatientFilters.none,
    bool contains = false,
    int limit = 30,
    String? cursor,
    DateTime? today,
  }) async {
    final json = await _api.get('/patients', query: {
      if (query.isNotEmpty) 'q': query,
      if (contains) 'mode': 'contains',
      ...filters.toQueryParameters(today ?? DateTime.now()),
      'limit': limit,
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    });

    final items = (json['patients'] as List? ?? [])
        .map((e) => Patient.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return Paginated(items: items, nextCursor: json['nextCursor'] as String?);
  }

  /// Load just the patient record (no visits).
  Future<Patient> get(String id) async {
    final json = await _api.get('/patients/$id');
    return Patient.fromJson((json['patient'] as Map).cast<String, dynamic>());
  }

  /// Load a patient plus the first page of visits.
  Future<PatientWithVisits> getWithVisits(String id, {int visitLimit = 30}) async {
    final json = await _api.get('/patients/$id', query: {
      'includeVisits': 'true',
      'visitLimit': visitLimit,
    });
    final patient =
        Patient.fromJson((json['patient'] as Map).cast<String, dynamic>());
    final visits = (json['visits'] as List? ?? [])
        .map((e) => Visit.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return PatientWithVisits(
      patient: patient,
      visits: visits,
      nextVisitsCursor: json['nextVisitsCursor'] as String?,
    );
  }

  /// Create a patient, optionally with an initial visit in the same request.
  ///
  /// [idempotencyKey] must be reused verbatim if a create is retried after a
  /// timeout or unknown network result; pass [newIdempotencyKey] for a genuinely
  /// new create.
  Future<CreatePatientResult> create({
    required String name,
    required String phoneNumber,
    VisitInput? initialVisit,
    required String idempotencyKey,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'phoneNumber': phoneNumber,
      if (initialVisit != null) ...initialVisit.toJson(),
    };
    final json = await _api.post(
      '/patients',
      body: body,
      headers: {'Idempotency-Key': idempotencyKey},
    );
    final patient =
        Patient.fromJson((json['patient'] as Map).cast<String, dynamic>());
    final visitJson = json['initialVisit'];
    return CreatePatientResult(
      patient: patient,
      initialVisit: visitJson is Map
          ? Visit.fromJson(visitJson.cast<String, dynamic>())
          : null,
    );
  }

  /// Updates name, phone number and/or credit. [credit] is in integer
  /// hundredths of JOD and must be non-negative (the server rejects negatives).
  Future<Patient> update({
    required String id,
    required String version,
    String? name,
    String? phoneNumber,
    int? credit,
  }) async {
    assert(credit == null || credit >= 0, 'credit must be non-negative');
    final json = await _api.patch(
      '/patients/$id',
      headers: {'If-Match': version},
      body: {
        if (name != null) 'name': name,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        if (credit != null) 'credit': credit,
      },
    );
    return Patient.fromJson((json['patient'] as Map).cast<String, dynamic>());
  }

  Future<Patient> archive({required String id, required String version}) async {
    final json = await _api.delete('/patients/$id', headers: {'If-Match': version});
    return Patient.fromJson((json['patient'] as Map).cast<String, dynamic>());
  }

  Future<Patient> restore({required String id, required String version}) async {
    final json = await _api.post(
      '/patients/$id/restore',
      headers: {'If-Match': version},
    );
    return Patient.fromJson((json['patient'] as Map).cast<String, dynamic>());
  }

  /// Permanently delete an already-archived patient with no remaining visits.
  Future<void> purge({required String id, required String version}) async {
    await _api.delete(
      '/patients/$id',
      query: {'purge': 'true'},
      headers: {'If-Match': version},
    );
  }

  String newIdempotencyKey() => _uuid.v4();
}
