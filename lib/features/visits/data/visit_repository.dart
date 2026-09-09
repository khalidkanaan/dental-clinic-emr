import 'package:uuid/uuid.dart';

import 'package:dental_clinic/core/api/api_client.dart';
import 'package:dental_clinic/core/api/paginated.dart';
import 'package:dental_clinic/features/visits/data/visit.dart';

class VisitRepository {
  VisitRepository(this._api);

  final ApiClient _api;
  static const _uuid = Uuid();

  /// Lists a patient's visits, newest first.
  ///
  /// When [owedOnly] is true the server returns only visits with a remaining
  /// balance (`amountOwed > 0`). This is used by the "owed only" filter so it
  /// reflects every owed visit, not just the pages already loaded.
  Future<Paginated<Visit>> list(
    String patientId, {
    int limit = 30,
    String? cursor,
    bool owedOnly = false,
  }) async {
    final json = await _api.get('/patients/$patientId/visits', query: {
      'limit': limit,
      if (owedOnly) 'owedOnly': 'true',
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
  
  /// Marks a visit's balance as collected (or reverses it). The `amountOwed`
  /// value is preserved; settling only removes it from the outstanding total.
  /// Sends `If-Match` for the same optimistic-concurrency guarantee as
  /// [update] / [delete].
  Future<Visit> setSettled(
    String patientId,
    String visitId, {
    required String version,
    required bool settled,
  }) async {
    final action = settled ? 'settle' : 'unsettle';
    final json = await _api.post(
      '/patients/$patientId/visits/$visitId/$action',
      headers: {'If-Match': version},
    );
    return Visit.fromJson((json['visit'] as Map).cast<String, dynamic>());
  }

  String newIdempotencyKey() => _uuid.v4();
}
