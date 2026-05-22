import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/token_storage.dart';
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
  /// This endpoint does not return a token (that comes after OTP verification),
  /// but if the backend ever includes one it is persisted here.
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
      final token = result.token;
      if (token != null && token.isNotEmpty) {
        await _tokenStorage.saveToken(token);
      }
      return result;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on FormatException catch (e) {
      throw ApiException(e.message);
    }
  }

  Future<void> logout() => _tokenStorage.clearToken();
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(dioProvider),
    ref.watch(tokenStorageProvider),
  );
});
