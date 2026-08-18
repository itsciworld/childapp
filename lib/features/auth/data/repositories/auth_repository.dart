import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../models/auth_tokens.dart';
import '../models/login_request.dart';
import '../models/login_response.dart';

/// Owns every auth-related network call. The UI never talks to Dio directly —
/// it goes UI → ViewModel → Repository.
class AuthRepository {
  AuthRepository(this._dio, this._tokenStorage);

  final Dio _dio;
  final TokenStorage _tokenStorage;

  /// Verifies credentials and triggers an OTP email.
  ///
  /// This endpoint does not return tokens (those come after OTP verification),
  /// but if the backend ever includes them they are persisted here.
  ///
  /// Throws [ApiException] on any network / server failure.
  Future<LoginResponse> login(LoginRequest request) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/children/login-and-send-otp',
        data: request.toJson(),
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const ApiException('Unexpected response from the server.');
      }

      final result = LoginResponse.fromJson(data);
      await _tokenStorage.saveTokens(
        accessToken: result.tokens.accessToken,
        refreshToken: result.tokens.refreshToken,
      );
      return result;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on FormatException catch (e) {
      throw ApiException(e.message);
    }
  }

  /// Exchanges the stored refresh token for a fresh access token via
  /// `POST /api/auth/refresh-token`.
  ///
  /// This is what lets a returning child land straight on the dashboard: the
  /// splash calls it at launch and, on success, skips the OTP flow entirely.
  /// The new tokens are persisted before returning (a rotated refresh token is
  /// stored too; if the backend returns none, the existing one is kept).
  ///
  /// Throws [ApiException] — a 401/403 means the refresh token is expired or
  /// revoked and the child has to sign in again.
  Future<AuthTokens> refreshSession() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const ApiException(
        'No refresh token stored.',
        statusCode: 401,
        kind: ApiErrorKind.badResponse,
      );
    }

    const endpoint = '/api/auth/refresh-token';
    try {
      final response = await _dio.post<dynamic>(
        endpoint,
        data: {'refreshToken': refreshToken},
      );

      final data = response.data;
      if (data is! Map) {
        throw const ApiException('Unexpected response from the server.');
      }

      final tokens = AuthTokens.fromJson(data);
      if (!tokens.hasAccessToken) {
        // No new access token means the session was not restored — treat it as
        // an auth failure so the caller falls back to the OTP flow.
        throw const ApiException(
          'The session could not be restored. Please sign in again.',
          statusCode: 401,
          kind: ApiErrorKind.badResponse,
        );
      }

      await _tokenStorage.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      debugPrint('[AuthRepository] session refreshed '
          '(rotated refresh token: ${tokens.hasRefreshToken})');
      return tokens;
    } on DioException catch (e) {
      debugPrint('[AuthRepository] $endpoint failed: '
          '${e.response?.statusCode} ${e.response?.data ?? e.message}');
      throw ApiException.fromDio(e);
    } on FormatException catch (e) {
      throw ApiException(e.message);
    }
  }

  Future<void> logout() => _tokenStorage.clearTokens();
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(dioProvider),
    ref.watch(tokenStorageProvider),
  );
});
