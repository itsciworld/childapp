/// Payload sent to `POST /api/children/verify-otp-and-pair-device`.
///
/// Verifies the OTP that was emailed to the parent and, in the same call,
/// creates the child profile and pairs this device.
class VerifyOtpRequest {
  const VerifyOtpRequest({
    required this.email,
    required this.otp,
    required this.name,
    required this.age,
    required this.deviceId,
  });

  /// Parent's email — carried over from the login screen.
  final String email;

  /// One-time code the parent received by email.
  final String otp;

  /// Child's display name.
  final String name;

  /// Child's age in years.
  final int age;

  /// This phone's stable identifier (from `device_info_plus`, the same value
  /// persisted as the local `deviceId`). Sent so the backend pairs the OTP to
  /// this exact device.
  final String deviceId;

  Map<String, dynamic> toJson() => {
        'email': email,
        'otp': otp,
        'name': name,
        'age': age,
        'deviceId': deviceId,
      };
}
