/// Parsed result of `PUT /api/children/:childId/live-status`.
///
/// The endpoint's success body is not strictly specified, so this stays
/// tolerant: it pulls a `status` and a human `message` when present.
class LiveStatusResponse {
  const LiveStatusResponse({this.status, this.message});

  final int? status;
  final String? message;

  factory LiveStatusResponse.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status'];
    return LiveStatusResponse(
      status: rawStatus is int ? rawStatus : int.tryParse('${rawStatus ?? ''}'),
      message: json['message'] as String? ?? json['msg'] as String?,
    );
  }

  @override
  String toString() =>
      'LiveStatusResponse(status: $status, message: $message)';
}
