/// Parsed result of `POST /api/children/{childId}/device-info`.
///
/// Example body:
/// ```json
/// {
///   "status": 200,
///   "msg": "Device info updated",
///   "deviceInfo": { ... }
/// }
/// ```
class DeviceInfoResponse {
  const DeviceInfoResponse({this.status, this.message});

  final int? status;

  /// Server message shown to the user as a toast, e.g. "Device info updated".
  final String? message;

  factory DeviceInfoResponse.fromJson(Map<String, dynamic> json) {
    final status = json['status'];
    return DeviceInfoResponse(
      status: status is int ? status : int.tryParse('${status ?? ''}'),
      message: json['msg'] as String? ?? json['message'] as String?,
    );
  }
}
