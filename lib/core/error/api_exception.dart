/// A normalized error raised by the data layer.
///
/// The Cloudflare Worker always responds with a JSON body of the shape
/// `{ "error": <code>, "message": <string>, "details"?: <object> }`. This type
/// captures the machine-readable [code] plus transport metadata so the UI can
/// translate it into a friendly, localized message. Raw API JSON is never shown
/// to the user.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    this.serverMessage,
    this.statusCode,
    this.retryAfterSeconds,
    this.requestId,
    this.details,
  });

  /// Machine-readable error code (see [ApiErrorCode]).
  final String code;

  /// The Worker's human message. Kept for diagnostics only; the UI localizes
  /// based on [code] rather than displaying this directly.
  final String? serverMessage;

  final int? statusCode;

  /// Seconds to wait before retrying, parsed from the `Retry-After` header.
  final int? retryAfterSeconds;

  /// The `X-Request-Id` header, surfaced under "Technical details".
  final String? requestId;

  /// Optional structured details (e.g. `{ patientId: ... }` on duplicates).
  final Map<String, dynamic>? details;

  bool get isVersionConflict => code == ApiErrorCode.versionConflict;
  bool get isUnauthorized => code == ApiErrorCode.unauthorized;

  /// The conflicting patient id returned with duplicate errors, if any.
  String? get conflictPatientId => details?['patientId'] as String?;

  @override
  String toString() => 'ApiException($code, status: $statusCode)';
}

/// Known error codes emitted by the Worker plus a few client-side codes.
class ApiErrorCode {
  const ApiErrorCode._();

  // Client-side.
  static const network = 'network_unavailable';
  static const timeout = 'timeout';
  static const unknown = 'unknown_error';

  // Auth / config.
  static const unauthorized = 'unauthorized';
  static const serverConfig = 'server_configuration_error';
  static const notReady = 'not_ready';

  // Patients.
  static const patientNotFound = 'patient_not_found';
  static const patientExists = 'patient_exists';
  static const patientArchived = 'patient_archived';
  static const archiveFirst = 'archive_first';
  static const patientHasVisits = 'patient_has_visits';

  // Visits.
  static const visitNotFound = 'visit_not_found';

  // Concurrency / idempotency.
  static const versionConflict = 'version_conflict';
  static const versionRequired = 'version_required';
  static const idempotencyConflict = 'idempotency_conflict';
  static const idempotencyKeyRequired = 'idempotency_key_required';

  // Validation / input.
  static const validationError = 'validation_error';
  static const noChanges = 'no_changes';
  static const invalidLimit = 'invalid_limit';
  static const invalidCursor = 'invalid_cursor';

  // Throttling / availability.
  static const rateLimited = 'rate_limited';
  static const databaseThrottled = 'database_throttled';
  static const databaseFailed = 'database_operation_failed';
  static const serviceUnavailable = 'service_unavailable';
}
