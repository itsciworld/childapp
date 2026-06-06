/// Parsed result of `POST /api/children/logout`.
class LogoutResponse {
  const LogoutResponse({this.message, this.status});

  /// Server message, e.g. "Logged out successfully. Clear the stored token on
  /// the device." — shown to the child in a snackbar on logout.
  final String? message;

  /// Status field carried *in the body* (e.g. `401` for an unpaired device),
  /// which can differ from the HTTP status when the server returns 200 with an
  /// error payload.
  final int? status;

  factory LogoutResponse.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status'];
    return LogoutResponse(
      message: json['msg'] as String? ?? json['message'] as String?,
      status: rawStatus is int ? rawStatus : int.tryParse('${rawStatus ?? ''}'),
    );
  }
}
