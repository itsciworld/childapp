import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../models/verify_otp_request.dart';
import '../models/verify_otp_response.dart';

/// Owns the OTP-verification / device-pairing network call. The UI never
/// talks to Dio directly — it goes UI → ViewModel → Repository.
class VerifyOtpRepository {
  VerifyOtpRepository(this._dio, this._tokenStorage);

  final Dio _dio;
  final TokenStorage _tokenStorage;

  /// Verifies the emailed OTP, creates the child profile and pairs the device.
  ///
  /// If the backend returns a token it is persisted for later authenticated
  /// requests.
  ///
  /// Throws [ApiException] on any network / server failure.
  Future<VerifyOtpResponse> verifyOtpAndPairDevice(
      VerifyOtpRequest request) async {
    const endpoint = '/api/children/verify-otp-and-pair-device';
    try {
      final payload = request.toJson();
      debugPrint('[VerifyOtpRepository] POST $endpoint → '
          'deviceId="${payload['deviceId']}", body=$payload');

      final response = await _dio.post<dynamic>(
        endpoint,
        data: payload,
      );
      debugPrint('[VerifyOtpRepository] response '
          '(${response.statusCode}): ${response.data}');

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const ApiException('Unexpected response from the server.');
      }

      final result = VerifyOtpResponse.fromJson(data);
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
}

final verifyOtpRepositoryProvider = Provider<VerifyOtpRepository>((ref) {
  return VerifyOtpRepository(
    ref.watch(dioProvider),
    ref.watch(tokenStorageProvider),
  );
});
