import '../../../../core/device/device_info_service.dart';

/// Request body for `POST /api/children/{childId}/device-info`.
///
/// Example:
/// ```json
/// {
///   "deviceId": "AND-123456",
///   "model": "Samsung Galaxy A52",
///   "manufacturer": "Samsung",
///   "osVersion": "Android 13",
///   "appVersion": "1.0.0",
///   "sdkVersion": "33"
/// }
/// ```
class DeviceInfoRequest {
  const DeviceInfoRequest({
    required this.deviceId,
    required this.model,
    required this.manufacturer,
    required this.osVersion,
    required this.appVersion,
    required this.sdkVersion,
  });

  final String deviceId;
  final String model;
  final String manufacturer;
  final String osVersion;
  final String appVersion;
  final String sdkVersion;

  /// Builds the request from the device info read off the platform.
  factory DeviceInfoRequest.fromDeviceInfo(DeviceInfoData info) {
    return DeviceInfoRequest(
      deviceId: info.deviceId,
      model: info.model,
      manufacturer: info.manufacturer,
      osVersion: info.osVersion,
      appVersion: info.appVersion,
      sdkVersion: info.sdkVersion,
    );
  }

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'model': model,
        'manufacturer': manufacturer,
        'osVersion': osVersion,
        'appVersion': appVersion,
        'sdkVersion': sdkVersion,
      };
}
