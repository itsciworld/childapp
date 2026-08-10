import 'package:dio/dio.dart';

/// What kind of failure an [ApiException] represents.
///
/// Callers that retry need this to tell "the request was too much for the
/// server" apart from "there is no network right now" — the two look identical
/// through [ApiException.statusCode] (both `null`) but call for opposite
/// responses: shrink the payload versus leave it alone and wait.
enum ApiErrorKind {
  /// The server answered, with an error status.
  badResponse,

  /// The request went out but no complete response arrived in time — typically
  /// a payload the server is too slow to process.
  timeout,

  /// The server could not be reached at all.
  offline,

  /// Anything else.
  unknown,
}

/// A user-friendly error thrown by repositories instead of raw [DioException]s.
class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.kind = ApiErrorKind.unknown,
  });

  final String message;
  final int? statusCode;
  final ApiErrorKind kind;

  /// Translates a low-level [DioException] into a readable [ApiException].
  factory ApiException.fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          'The connection timed out. Please check your internet and try again.',
          kind: ApiErrorKind.timeout,
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          'Could not reach the server. Please check your internet connection.',
          kind: ApiErrorKind.offline,
        );
      case DioExceptionType.badResponse:
        return ApiException(
          _messageFromBody(error.response?.data) ??
              'Request failed (${error.response?.statusCode}).',
          statusCode: error.response?.statusCode,
          kind: ApiErrorKind.badResponse,
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
