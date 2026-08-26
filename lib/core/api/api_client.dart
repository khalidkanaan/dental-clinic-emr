import 'package:dio/dio.dart';

import 'package:dental_clinic/core/api/api_error_mapper.dart';
import 'package:dental_clinic/core/api/api_interceptors.dart';
import 'package:dental_clinic/core/config/app_config.dart';
import 'package:dental_clinic/core/error/api_exception.dart';
import 'package:dental_clinic/core/storage/secure_storage.dart';

/// Thin wrapper over Dio that centralizes base URL, timeouts, auth, JSON
/// decoding and error handling. Repositories talk to this; widgets never do.
class ApiClient {
  ApiClient({required SecureStore store, Dio? dio})
      : _dio = dio ?? _buildDio(store);

  final Dio _dio;

  static Dio _buildDio(SecureStore store) {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        sendTimeout: AppConfig.sendTimeout,
        responseType: ResponseType.json,
        contentType: Headers.jsonContentType,
        // We validate status codes ourselves so that 4xx/5xx bodies are parsed.
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    dio.interceptors.add(AuthInterceptor(store));
    dio.interceptors.add(SafeLogInterceptor());
    return dio;
  }

  Future<JsonMap> get(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) {
    return _send(
      () => _dio.get<dynamic>(
        path,
        queryParameters: query,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<JsonMap> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) {
    return _send(
      () => _dio.post<dynamic>(
        path,
        data: body,
        options: Options(headers: headers),
      ),
    );
  }

  Future<JsonMap> patch(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) {
    return _send(
      () => _dio.patch<dynamic>(
        path,
        data: body,
        options: Options(headers: headers),
      ),
    );
  }

  Future<JsonMap> delete(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) {
    return _send(
      () => _dio.delete<dynamic>(
        path,
        queryParameters: query,
        options: Options(headers: headers),
      ),
    );
  }

  /// Runs [request], returning the decoded JSON object on success (2xx) and
  /// throwing a normalized [ApiException] otherwise.
  Future<JsonMap> _send(Future<Response<dynamic>> Function() request) async {
    late final Response<dynamic> response;
    try {
      response = await request();
    } on DioException catch (error) {
      throw mapDioException(error);
    }

    final status = response.statusCode ?? 0;
    if (status >= 200 && status < 300) {
      final data = response.data;
      if (data is Map) return data.cast<String, dynamic>();
      return const <String, dynamic>{};
    }

    // 4xx with a parsed body: reuse the mapper by wrapping in a DioException.
    throw mapDioException(
      DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      ),
    );
  }
}

typedef JsonMap = Map<String, dynamic>;
