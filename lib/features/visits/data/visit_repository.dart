import 'package:uuid/uuid.dart';

import 'package:dental_clinic/core/api/api_client.dart';
import 'package:dental_clinic/core/api/paginated.dart';
import 'package:dental_clinic/features/visits/data/visit.dart';

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

  Future<Visit> add(
    String patientId,
    VisitInput input, {
    required String idempotencyKey,
  }) async {
    final json = await _api.post(
      '/patients/$patientId/visits',
      body: input.toJson(),
      headers: {'Idempotency-Key': idempotencyKey},
    );
    return Visit.fromJson((json['visit'] as Map).cast<String, dynamic>());
  }

  Future<Visit> update(
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
    return Visit.fromJson((json['visit'] as Map).cast<String, dynamic>());
  }

  Future<void> delete(
    String patientId,
    String visitId, {
    required String version,
  }) async {
    await _api.delete(
      '/patients/$patientId/visits/$visitId',
      headers: {'If-Match': version},
    );
  }

  String newIdempotencyKey() => _uuid.v4();
}
