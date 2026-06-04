/// Parsed result of `POST /api/children/logout`.
class LogoutResponse {
  const LogoutResponse({this.message});

  /// Server message, e.g. "Logged out successfully. Clear the stored token on
  /// the device." — shown to the child in a snackbar on logout.
  final String? message;

  factory LogoutResponse.fromJson(Map<String, dynamic> json) {
    return LogoutResponse(
      message: json['msg'] as String? ?? json['message'] as String?,
    );
  }
}
