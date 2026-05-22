import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../models/pairing_request.dart';
import '../models/pairing_response.dart';

/// Owns the pairing-code verification network call. The UI never talks to Dio
/// directly — it goes UI → ViewModel → Repository.
class PairingRepository {
  PairingRepository(this._dio);

  final Dio _dio;

  /// Verifies the pairing code generated on the parent's Vigil app.
  ///
  /// Throws [ApiException] on any network / server failure.
  Future<PairingResponse> verifyPairingCode(PairingRequest request) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/children/verify-pairing-code',
        data: request.toJson(),
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const ApiException('Unexpected response from the server.');
      }

      return PairingResponse.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on FormatException catch (e) {
      throw ApiException(e.message);
    }
  }
}

final pairingRepositoryProvider = Provider<PairingRepository>((ref) {
  return PairingRepository(ref.watch(dioProvider));
});
