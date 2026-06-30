/// Parsed result of a social-capture upload (notifications / on-screen text).
///
/// Shared by both [FEATURE A] and [FEATURE B] repositories. When the backend is
/// ready, adjust [fromJson] to match the real response shape — that's the only
/// place the response contract is decoded.
class SocialUploadResponse {
  const SocialUploadResponse({
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

  factory SocialUploadResponse.fromJson(Map<String, dynamic> json) {
    int? asInt(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}');
    return SocialUploadResponse(
      status: asInt(json['status']),
      message: json['message'] as String? ?? json['msg'] as String?,
      saved: asInt(json['saved']),
      duplicates: asInt(json['duplicates']),
      total: asInt(json['total']),
    );
  }

  /// Synthetic response returned while the backend is disabled (debug-only mode)
  /// so the sync flow has something to log and advance with.
  factory SocialUploadResponse.debug(int count) => SocialUploadResponse(
        status: 0,
        message: 'debug-only (upload disabled)',
        saved: count,
        duplicates: 0,
        total: count,
      );

  @override
  String toString() => 'SocialUploadResponse(status: $status, saved: $saved, '
      'duplicates: $duplicates, total: $total, message: $message)';
}
