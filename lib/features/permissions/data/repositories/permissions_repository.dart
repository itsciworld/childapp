import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../models/permissions_request.dart';
import '../models/permissions_response.dart';

/// Owns the permissions-update network call. The UI never talks to Dio
/// directly — it goes UI → ViewModel → Repository.
class PermissionsRepository {
  PermissionsRepository(this._dio, this._tokenStorage);

  final Dio _dio;
  final TokenStorage _tokenStorage;

  /// Sends the child's permission selections to
  /// `PUT /api/children/{childId}/permissions`.
  ///
  /// The stored auth token is sent in the `Authorization: Bearer` header.
  ///
  /// Throws [ApiException] on any network / server failure.
  Future<PermissionsResponse> updatePermissions(
    String childId,
    PermissionsRequest request,
  ) async {
    final body = request.toJson();
    debugPrint('[PermissionsRepository] PUT /api/children/$childId/permissions '
        'body=$body');
    try {
      final token = await _tokenStorage.getToken();
      final response = await _dio.put<dynamic>(
        '/api/children/$childId/permissions',
        data: body,
        options: Options(
          headers: {
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
        ),
      );

      debugPrint('[PermissionsRepository] response '
          '(${response.statusCode}): ${response.data}');

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const ApiException('Unexpected response from the server.');
      }
      return PermissionsResponse.fromJson(data);
    } on DioException catch (e) {
      debugPrint('[PermissionsRepository] request failed: '
          '${e.response?.statusCode} ${e.response?.data ?? e.message}');
      throw ApiException.fromDio(e);
    } on FormatException catch (e) {
      throw ApiException(e.message);
    }
  }
}

final permissionsRepositoryProvider = Provider<PermissionsRepository>((ref) {
  return PermissionsRepository(
    ref.watch(dioProvider),
    ref.watch(tokenStorageProvider),
  );
});
