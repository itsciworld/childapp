/// Parsed result of `PUT /api/children/{childId}/permissions`.
class PermissionsResponse {
  const PermissionsResponse({this.message});

  /// Server message, e.g. "Permissions updated".
  final String? message;

  factory PermissionsResponse.fromJson(Map<String, dynamic> json) {
    return PermissionsResponse(
      message: json['msg'] as String? ?? json['message'] as String?,
    );
  }
}
