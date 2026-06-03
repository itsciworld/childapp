/// Parsed result of `POST /api/logs/store_calllogs`.
///
/// Mirrors the SMS store response shape: a status, a human message, and
/// saved / duplicates / total counts.
class StoreCallLogsResponse {
  const StoreCallLogsResponse({
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

  factory StoreCallLogsResponse.fromJson(Map<String, dynamic> json) {
    int? asInt(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}');
    return StoreCallLogsResponse(
      status: asInt(json['status']),
      message: json['message'] as String? ?? json['msg'] as String?,
      saved: asInt(json['saved']),
      duplicates: asInt(json['duplicates']),
      total: asInt(json['total']),
    );
  }

  @override
  String toString() =>
      'StoreCallLogsResponse(status: $status, saved: $saved, '
      'duplicates: $duplicates, total: $total, message: $message)';
}
