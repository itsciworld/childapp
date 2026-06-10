/// Parsed result of `POST /api/locations/store_location`.
///
/// Example body: `{ "status": 200, "message": "Location saved." }`.
class StoreLocationResponse {
  const StoreLocationResponse({this.status, this.message});

  final int? status;
  final String? message;

  factory StoreLocationResponse.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status'];
    return StoreLocationResponse(
      status: rawStatus is int ? rawStatus : int.tryParse('${rawStatus ?? ''}'),
      message: json['message'] as String? ?? json['msg'] as String?,
    );
  }

  @override
  String toString() =>
      'StoreLocationResponse(status: $status, message: $message)';
}
