import 'package:dio/dio.dart';

import 'package:dental_clinic/core/error/api_exception.dart';

/// Converts a low-level [DioException] into a normalized [ApiException].
ApiException mapDioException(DioException error) {
  final response = error.response;

  // No HTTP response => transport-level problem.
  if (response == null) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(code: ApiErrorCode.timeout);

      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return const ApiException(code: ApiErrorCode.network);

      case DioExceptionType.cancel:
        return const ApiException(code: ApiErrorCode.unknown);

      case DioExceptionType.badCertificate:
      case DioExceptionType.badResponse:
        return const ApiException(code: ApiErrorCode.unknown);
    }
  }

  final status = response.statusCode;
  final requestId = response.headers.value('x-request-id');
  final retryAfter = _parseRetryAfter(
    response.headers.value('retry-after'),
  );

  String code = ApiErrorCode.unknown;
  String? serverMessage;
  Map<String, dynamic>? details;

  final data = response.data;

  if (data is Map) {
    final map = data.cast<String, dynamic>();

    if (map['error'] is String) {
      code = map['error'] as String;
    }

    if (map['message'] is String) {
      serverMessage = map['message'] as String;
    }

    if (map['details'] is Map) {
      details = (map['details'] as Map).cast<String, dynamic>();
    }
  }

  // Fall back to a status-derived code when the body lacked one.
  if (code == ApiErrorCode.unknown && status != null) {
    if (status == 401) {
      code = ApiErrorCode.unauthorized;
    }

    if (status == 429) {
      code = ApiErrorCode.rateLimited;
    }

    if (status == 503) {
      code = ApiErrorCode.serviceUnavailable;
    }
  }

  return ApiException(
    code: code,
    serverMessage: serverMessage,
    statusCode: status,
    retryAfterSeconds: retryAfter,
    requestId: requestId,
    details: details,
  );
}

int? _parseRetryAfter(String? value) {
  if (value == null) return null;

  final seconds = int.tryParse(value.trim());

  return (seconds != null && seconds >= 0) ? seconds : null;
}