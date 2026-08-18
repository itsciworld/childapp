import 'auth_tokens.dart';

/// Parsed result of `POST /api/children/login-and-send-otp`.
///
/// This endpoint only sends an OTP to the user's email — it returns a `msg`
/// and no token. The tokens are issued later, after OTP verification.
class LoginResponse {
  const LoginResponse({this.message, this.tokens = const AuthTokens()});

  /// Server message, e.g. "OTP sent to email".
  final String? message;

  /// Auth tokens — usually empty here; present only if the backend returns them.
  final AuthTokens tokens;

  /// Access token, when the backend returns one at this step.
  String? get token => tokens.accessToken;

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      message: json['msg'] as String? ?? json['message'] as String?,
      tokens: AuthTokens.fromJson(json),
    );
  }
}
