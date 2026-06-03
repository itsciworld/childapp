/// Parsed result of `POST /api/contacts/store_contacts`.
///
/// Example body:
/// ```json
/// { "status": 200, "message": "Contacts processed.", "total": 2,
///   "saved": 2, "duplicates": 0 }
/// ```
class StoreContactsResponse {
  const StoreContactsResponse({
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

  factory StoreContactsResponse.fromJson(Map<String, dynamic> json) {
    int? asInt(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}');
    return StoreContactsResponse(
      status: asInt(json['status']),
      message: json['message'] as String? ?? json['msg'] as String?,
      saved: asInt(json['saved']),
      duplicates: asInt(json['duplicates']),
      total: asInt(json['total']),
    );
  }

  @override
  String toString() =>
      'StoreContactsResponse(status: $status, saved: $saved, '
      'duplicates: $duplicates, total: $total, message: $message)';
}
