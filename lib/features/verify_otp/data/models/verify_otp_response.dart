/// Parsed result of `POST /api/children/verify-otp-and-pair-device`.
///
/// On success the backend returns the newly created `child` object and may
/// also issue an auth `token` for the paired device.
class VerifyOtpResponse {
  const VerifyOtpResponse({
    this.message,
    this.childId,
    this.parentId,
    this.token,
    this.deviceKey,
  });

  /// Server message, e.g. "Device paired successfully".
  final String? message;

  /// Id of the created child profile — needed by the permissions flow.
  final String? childId;

  /// Id of the parent the child is paired to — needed when uploading SMS.
  final String? parentId;

  /// Auth token for the paired device, when the backend returns one.
  final String? token;

  /// Backend-issued device key — must be sent back in the `x-device-key`
  /// header on authenticated uploads (e.g. SMS sync).
  final String? deviceKey;

  factory VerifyOtpResponse.fromJson(Map<String, dynamic> json) {
    final child = json['child'];
    final childMap = child is Map ? child : const {};
    return VerifyOtpResponse(
      message: json['msg'] as String? ?? json['message'] as String?,
      childId: childMap['_id'] as String? ?? json['childId'] as String?,
      // The parent id may arrive on the child object or at the top level.
      parentId: (childMap['parentId'] ??
              childMap['parent_id'] ??
              childMap['parent'] ??
              json['parentId'] ??
              json['parent_id'])
          ?.toString(),
      token: json['token'] as String?,
      deviceKey: json['deviceKey'] as String? ?? json['device_key'] as String?,
    );
  }
}
