import 'package:dio/dio.dart';

import 'package:dental_clinic/core/storage/secure_storage.dart';

/// Adds `Authorization: Bearer <token>` to every request when a token is
/// available. Health endpoints work without it, so a missing token is not an
/// error here — protected endpoints will simply return 401 and be surfaced.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._store);

  final SecureStore _store;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _store.readToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

/// Minimal request logger. Deliberately never logs headers or bodies, since
/// requests carry the bearer token and patient data.
class SafeLogInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // ignore: avoid_print
    print(
      'API ${response.requestOptions.method} '
      '${response.requestOptions.path} -> ${response.statusCode}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // ignore: avoid_print
    print(
      'API ${err.requestOptions.method} '
      '${err.requestOptions.path} -> ${err.response?.statusCode ?? err.type}',
    );
    handler.next(err);
  }
}
