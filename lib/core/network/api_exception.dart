import 'package:dio/dio.dart';

/// A user-friendly error thrown by repositories instead of raw [DioException]s.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  /// Translates a low-level [DioException] into a readable [ApiException].
  factory ApiException.fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          'The connection timed out. Please check your internet and try again.',
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          'Could not reach the server. Please check your internet connection.',
        );
      case DioExceptionType.badResponse:
        return ApiException(
          _messageFromBody(error.response?.data) ??
              'Request failed (${error.response?.statusCode}).',
          statusCode: error.response?.statusCode,
        );
      case DioExceptionType.cancel:
        return const ApiException('The request was cancelled.');
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const ApiException(
          'Something went wrong. Please try again.',
        );
    }
  }

  /// Extracts a `msg` / `message` / `error` field from a JSON error body.
  static String? _messageFromBody(dynamic body) {
    if (body is Map) {
      final value = body['msg'] ?? body['message'] ?? body['error'];
      if (value is String && value.isNotEmpty) return value;
    }
    if (body is String && body.isNotEmpty) return body;
    return null;
  }

  @override
  String toString() => message;
}
