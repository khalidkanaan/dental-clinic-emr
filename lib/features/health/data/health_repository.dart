import 'package:dental_clinic/core/api/api_client.dart';
import 'package:dental_clinic/core/error/api_exception.dart';

/// Result of verifying the stored API token against `/auth/verify`.
enum TokenStatus {
  valid,
  invalid,
  unknown,
}

/// Outcome of a connection test.
class HealthStatus {
  const HealthStatus({
    required this.workerLive,
    required this.databaseReady,
    required this.tokenStatus,
    this.checkedAt,
    this.errorCode,
  });

  final bool workerLive;
  final bool databaseReady;
  final TokenStatus tokenStatus;
  final DateTime? checkedAt;
  final String? errorCode;

  bool get allHealthy => workerLive && databaseReady;
}

class HealthRepository {
  HealthRepository(this._api);

  final ApiClient _api;

  /// Checks Worker liveness (`/health/live`) and full readiness
  /// (`/health/ready`, which validates the Patients and Visits containers),
  /// and verifies the stored API token (`/auth/verify`).
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

    // Runs alongside the health checks, independently of their outcome.
    final tokenStatus = await _verifyToken();

    return HealthStatus(
      workerLive: live,
      databaseReady: ready,
      tokenStatus: tokenStatus,
      checkedAt: DateTime.now(),
      errorCode: errorCode,
    );
  }

  /// Verifies the API token via `/auth/verify`.
  ///
  /// - 200 -> [TokenStatus.valid]
  /// - 401 / [ApiErrorCode.unauthorized] -> [TokenStatus.invalid]
  /// - network / server errors -> [TokenStatus.unknown]
  Future<TokenStatus> _verifyToken() async {
    try {
      await _api.get('/auth/verify');
      return TokenStatus.valid;
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.code == ApiErrorCode.unauthorized) {
        return TokenStatus.invalid;
      }
      return TokenStatus.unknown;
    } catch (_) {
      return TokenStatus.unknown;
    }
  }
}
