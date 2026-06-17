/// Parsed result of `POST /api/files/store_files`.
///
/// Example body: `{ "status": 200, "message": "Files processed.", "saved": 2,
/// "duplicates": 0, "total": 2 }`.
class StoreFilesResponse {
  const StoreFilesResponse({
    this.status,
    this.message,
    this.saved,
    this.duplicates,
    this.total,
  });

  final int? status;
  final String? message;
  final int? saved;
  final int? duplicates;
  final int? total;

  factory StoreFilesResponse.fromJson(Map<String, dynamic> json) {
    int? asInt(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}');
    return StoreFilesResponse(
      status: asInt(json['status']),
      message: json['message'] as String? ?? json['msg'] as String?,
      saved: asInt(json['saved']),
      duplicates: asInt(json['duplicates']),
      total: asInt(json['total']),
    );
  }

  @override
  String toString() => 'StoreFilesResponse(status: $status, saved: $saved, '
      'duplicates: $duplicates, total: $total, message: $message)';
}
