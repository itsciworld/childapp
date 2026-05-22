/// Parsed result of `POST /api/children/verify-otp-and-pair-device`.
///
/// On success the backend returns the newly created `child` object and may
/// also issue an auth `token` for the paired device.
class VerifyOtpResponse {
  const VerifyOtpResponse({this.message, this.childId, this.token});

  /// Server message, e.g. "Device paired successfully".
  final String? message;

  /// Id of the created child profile — needed by the permissions flow.
  final String? childId;

  /// Auth token for the paired device, when the backend returns one.
  final String? token;

  factory VerifyOtpResponse.fromJson(Map<String, dynamic> json) {
    final child = json['child'];
    return VerifyOtpResponse(
      message: json['msg'] as String? ?? json['message'] as String?,
      childId: child is Map
          ? child['_id'] as String?
          : json['childId'] as String?,
      token: json['token'] as String?,
    );
  }
}
