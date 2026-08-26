import 'package:dental_clinic/core/api/api_client.dart';
import 'package:dental_clinic/core/error/api_exception.dart';

/// Outcome of a connection test.
class HealthStatus {
  const HealthStatus({
    required this.workerLive,
    required this.databaseReady,
    this.checkedAt,
    this.errorCode,
  });

  final bool workerLive;
  final bool databaseReady;
  final DateTime? checkedAt;
  final String? errorCode;

  bool get allHealthy => workerLive && databaseReady;
}

class HealthRepository {
  HealthRepository(this._api);

  final ApiClient _api;

  /// Checks Worker liveness (`/health/live`) and full readiness
  /// (`/health/ready`, which validates the Patients and Visits containers).
  Future<HealthStatus> check() async {
    var live = false;
    var ready = false;
    String? errorCode;

    try {
      await _api.get('/health/live');
      live = true;
    } on ApiException catch (e) {
      errorCode = e.code;
    }

    if (live) {
      try {
        await _api.get('/health/ready');
        ready = true;
      } on ApiException catch (e) {
        errorCode = e.code;
      }
    }

    return HealthStatus(
      workerLive: live,
      databaseReady: ready,
      checkedAt: DateTime.now(),
      errorCode: errorCode,
    );
  }
}
