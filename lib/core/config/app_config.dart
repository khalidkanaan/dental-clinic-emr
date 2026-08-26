/// Centralized application configuration.
///
/// The API base URL is provided at build time and can be overridden with:
///   flutter run --dart-define=API_BASE_URL=https://your-worker.dev/v1
///
/// The base URL includes the `/v1` API-version prefix so that feature code can
/// use short paths such as `/patients` and `/health/live`.
class AppConfig {
  const AppConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://khalo-cosmos-api.khalid-kanaan-ca.workers.dev/v1',
  );

  /// Default page size for patient search and visit history.
  static const int pageSize = 30;

  /// Debounce applied to the patient search field.
  static const Duration searchDebounce = Duration(milliseconds: 300);

  /// Networking timeouts.
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);
  static const Duration sendTimeout = Duration(seconds: 20);
}
