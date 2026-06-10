/// Parsed result of `POST /api/events/store_events`.
///
/// Example body: `{ "status": 200, "message": "All events are already up to
/// date.", "total": 1, "saved": 0, "duplicates": 1 }`.
class StoreEventsResponse {
  const StoreEventsResponse({
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

  factory StoreEventsResponse.fromJson(Map<String, dynamic> json) {
    int? asInt(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}');
    return StoreEventsResponse(
      status: asInt(json['status']),
      message: json['message'] as String? ?? json['msg'] as String?,
      saved: asInt(json['saved']),
      duplicates: asInt(json['duplicates']),
      total: asInt(json['total']),
    );
  }

  @override
  String toString() =>
      'StoreEventsResponse(status: $status, saved: $saved, '
      'duplicates: $duplicates, total: $total, message: $message)';
}
