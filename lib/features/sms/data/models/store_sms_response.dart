/// Parsed result of `POST /api/sms/store_sms`.
///
/// Example body:
/// ```json
/// { "status": 200, "message": "Processed 2 SMS. Stored 0 new, skipped 2
///   duplicates.", "saved": 0, "duplicates": 2, "total": 2 }
/// ```
class StoreSmsResponse {
  const StoreSmsResponse({
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

  factory StoreSmsResponse.fromJson(Map<String, dynamic> json) {
    int? asInt(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}');
    return StoreSmsResponse(
      status: asInt(json['status']),
      message: json['message'] as String? ?? json['msg'] as String?,
      saved: asInt(json['saved']),
      duplicates: asInt(json['duplicates']),
      total: asInt(json['total']),
    );
  }

  @override
  String toString() =>
      'StoreSmsResponse(status: $status, saved: $saved, '
      'duplicates: $duplicates, total: $total, message: $message)';
}
