/// Parsed result of `POST /api/children/login-and-send-otp`.
///
/// This endpoint only sends an OTP to the user's email — it returns a `msg`
/// and no token. The token is issued later, after OTP verification.
class LoginResponse {
  const LoginResponse({this.message, this.token});

  /// Server message, e.g. "OTP sent to email".
  final String? message;

  /// Auth token — usually null here; present only if the backend returns one.
  final String? token;

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      message: json['msg'] as String? ?? json['message'] as String?,
      token: json['token'] as String?,
    );
  }
}
