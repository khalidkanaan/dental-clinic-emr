import 'package:dental_clinic/core/error/api_exception.dart';
import 'package:dental_clinic/l10n/app_localizations.dart';

/// Translates a normalized [ApiException] into a friendly, localized string.
/// Raw API JSON is never surfaced to the user.
String localizedError(AppLocalizations l10n, ApiException e) {
  switch (e.code) {
    case ApiErrorCode.unauthorized:
      return l10n.errUnauthorized;
    case ApiErrorCode.patientNotFound:
      return l10n.errPatientNotFound;
    case ApiErrorCode.visitNotFound:
      return l10n.errVisitNotFound;
    case ApiErrorCode.patientExists:
      return l10n.errPatientExists;
    case ApiErrorCode.patientArchived:
      return l10n.errPatientArchived;
    case ApiErrorCode.archiveFirst:
      return l10n.errArchiveFirst;
    case ApiErrorCode.patientHasVisits:
      return l10n.errPatientHasVisits;
    case ApiErrorCode.versionConflict:
    case ApiErrorCode.versionRequired:
      return l10n.versionConflictTitle;
    case ApiErrorCode.idempotencyConflict:
      return l10n.errIdempotencyConflict;
    case ApiErrorCode.rateLimited:
    case ApiErrorCode.databaseThrottled:
      final secs = e.retryAfterSeconds;
      return secs != null ? l10n.retryAfterSeconds(secs) : l10n.errRateLimited;
    case ApiErrorCode.serviceUnavailable:
    case ApiErrorCode.databaseFailed:
      return l10n.errServiceUnavailable;
    case ApiErrorCode.notReady:
      return l10n.errNotReady;
    case ApiErrorCode.network:
      return l10n.errNetwork;
    case ApiErrorCode.timeout:
      return l10n.errTimeout;
    case ApiErrorCode.validationError:
    case ApiErrorCode.noChanges:
    case ApiErrorCode.invalidLimit:
    case ApiErrorCode.invalidCursor:
      return l10n.errValidation;
    case ApiErrorCode.serverConfig:
      return l10n.errServerConfig;
    default:
      return l10n.errUnknown;
  }
}
