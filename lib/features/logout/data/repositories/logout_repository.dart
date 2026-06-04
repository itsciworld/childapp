import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../models/logout_response.dart';

/// Owns the logout network call. The UI never talks to Dio directly —
/// it goes UI → ViewModel → Repository.
class LogoutRepository {
  LogoutRepository(this._dio, this._tokenStorage);

  final Dio _dio;
  final TokenStorage _tokenStorage;

  /// Tells the backend to log this device out via `POST /api/children/logout`.
  ///
  /// The stored auth token is sent in the `Authorization: Bearer` header (the
  /// device key is attached automatically by the Dio interceptor). On success
  /// the backend returns a `msg` instructing the client to clear its token —
  /// the caller does the actual local cleanup.
  ///
  /// Throws [ApiException] on any network / server failure.
  Future<LogoutResponse> logout() async {
    try {
      final token = await _tokenStorage.getToken();
      final response = await _dio.post<dynamic>(
        '/api/children/logout',
        options: Options(
          headers: {
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
        ),
      );

      debugPrint('[LogoutRepository] response '
          '(${response.statusCode}): ${response.data}');

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const ApiException('Unexpected response from the server.');
      }
      return LogoutResponse.fromJson(data);
    } on DioException catch (e) {
      debugPrint('[LogoutRepository] request failed: '
          '${e.response?.statusCode} ${e.response?.data ?? e.message}');
      throw ApiException.fromDio(e);
    } on FormatException catch (e) {
      throw ApiException(e.message);
    }
  }
}

final logoutRepositoryProvider = Provider<LogoutRepository>((ref) {
  return LogoutRepository(
    ref.watch(dioProvider),
    ref.watch(tokenStorageProvider),
  );
});
