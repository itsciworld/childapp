/// Parsed result of `POST /api/apps/save_apps`.
///
/// Example body: `{ "status": 200, "message": "Apps processed.", "total": 3,
/// "new": 1, "updated": 2 }`.
class SaveAppsResponse {
  const SaveAppsResponse({
    this.status,
    this.message,
    this.total,
    this.newCount,
    this.updated,
  });

  final int? status;
  final String? message;
  final int? total;

  /// `new` in the JSON (a Dart reserved word, so renamed here).
  final int? newCount;
  final int? updated;

  factory SaveAppsResponse.fromJson(Map<String, dynamic> json) {
    int? asInt(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}');
    return SaveAppsResponse(
      status: asInt(json['status']),
      message: json['message'] as String? ?? json['msg'] as String?,
      total: asInt(json['total']),
      newCount: asInt(json['new']),
      updated: asInt(json['updated']),
    );
  }

  @override
  String toString() => 'SaveAppsResponse(status: $status, total: $total, '
      'new: $newCount, updated: $updated, message: $message)';
}
