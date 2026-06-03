import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/device/device_info_service.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/identity_storage.dart';
import '../../../../core/storage/token_storage.dart';
import '../models/device_info_request.dart';
import '../models/device_info_response.dart';

/// Owns the device-info upload. The UI never talks to Dio directly — it goes
/// UI → ViewModel → Repository.
class DeviceRepository {
  DeviceRepository(
    this._dio,
    this._tokenStorage,
    this._identityStorage,
    this._deviceInfoService,
  );

  final Dio _dio;
  final TokenStorage _tokenStorage;
  final IdentityStorage _identityStorage;
  final DeviceInfoService _deviceInfoService;

  /// Reads this device's hardware / OS / app details and sends them to
  /// `PUT /api/children/{childId}/device-info`.
  ///
  /// The stored `childId` is used in the path and the stored auth token is sent
  /// in the `Authorization: Bearer` header.
  ///
  /// Throws [ApiException] on a missing child id or any network / server
  /// failure.
  Future<DeviceInfoResponse> uploadDeviceInfo() async {
    final identity = await _identityStorage.read();
    final childId = identity.childId;
    if (childId == null || childId.isEmpty) {
      throw const ApiException('Device is not paired yet.');
    }

    final info = await _deviceInfoService.readDeviceInfo();
    final body = DeviceInfoRequest.fromDeviceInfo(info).toJson();
    debugPrint('[DeviceRepository] PUT /api/children/$childId/device-info '
        'body=$body');

    try {
      final token = await _tokenStorage.getToken();
      // This route lives under the same `/api/children/{childId}/...` sub-resource
      // as permissions, which is served by PUT — POST returns 404 (route not
      // registered).
      final response = await _dio.put<dynamic>(
        '/api/children/$childId/device-info',
        data: body,
        options: Options(
          headers: {
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
        ),
      );

      debugPrint('[DeviceRepository] response '
          '(${response.statusCode}): ${response.data}');

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const ApiException('Unexpected response from the server.');
      }
      return DeviceInfoResponse.fromJson(data);
    } on DioException catch (e) {
      debugPrint('[DeviceRepository] request failed: '
          '${e.response?.statusCode} ${e.response?.data ?? e.message}');
      throw ApiException.fromDio(e);
    } on FormatException catch (e) {
      throw ApiException(e.message);
    }
  }
}

final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  return DeviceRepository(
    ref.watch(dioProvider),
    ref.watch(tokenStorageProvider),
    ref.watch(identityStorageProvider),
    ref.watch(deviceInfoServiceProvider),
  );
});
