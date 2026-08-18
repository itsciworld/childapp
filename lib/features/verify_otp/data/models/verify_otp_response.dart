import '../../../auth/data/models/auth_tokens.dart';

/// Parsed result of `POST /api/children/verify-otp-and-pair-device`.
///
/// On success the backend returns the newly created `child` object and may
/// also issue an auth `token` for the paired device.
class VerifyOtpResponse {
  const VerifyOtpResponse({
    this.message,
    this.childId,
    this.parentId,
    this.tokens = const AuthTokens(),
    this.deviceKey,
  });

  /// Server message, e.g. "Device paired successfully".
  final String? message;

  /// Id of the created child profile — needed by the permissions flow.
  final String? childId;

  /// Id of the parent the child is paired to — needed when uploading SMS.
  final String? parentId;

  /// Auth tokens for the paired device. The refresh token is what lets a
  /// returning child skip the OTP flow on the next launch.
  final AuthTokens tokens;

  /// Access token for the paired device, when the backend returns one.
  String? get token => tokens.accessToken;

  /// Long-lived refresh token, when the backend returns one.
  String? get refreshToken => tokens.refreshToken;

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
      tokens: AuthTokens.fromJson(json),
      deviceKey: json['deviceKey'] as String? ?? json['device_key'] as String?,
    );
  }
}
