/// Parsed result of `POST /api/files/upload-multiple`.
///
/// Example body: `{ "status": 200, "message": "Files uploaded.", "count": 3,
/// "files": [ { "url": "...", "public_id": "...", "file_type": "image/png" } ] }`.
///
/// The [files] are returned in the same order the binaries were sent, so the
/// caller zips each [UploadedFile.url] back onto its source media by index.
class UploadFilesResponse {
  const UploadFilesResponse({
    this.status,
    this.message,
    this.count,
    this.files = const [],
  });

  final int? status;
  final String? message;
  final int? count;
  final List<UploadedFile> files;

  factory UploadFilesResponse.fromJson(Map<String, dynamic> json) {
    int? asInt(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}');
    final rawFiles = json['files'];
    return UploadFilesResponse(
      status: asInt(json['status']),
      message: json['message'] as String? ?? json['msg'] as String?,
      count: asInt(json['count']),
      files: rawFiles is List
          ? rawFiles
              .whereType<Map<String, dynamic>>()
              .map(UploadedFile.fromJson)
              .toList()
          : const [],
    );
  }

  @override
  String toString() => 'UploadFilesResponse(status: $status, count: $count, '
      'files: ${files.length}, message: $message)';
}

/// One uploaded binary inside [UploadFilesResponse.files].
class UploadedFile {
  const UploadedFile({
    required this.url,
    this.publicId,
    this.fileType,
  });

  final String url;
  final String? publicId;
  final String? fileType;

  factory UploadedFile.fromJson(Map<String, dynamic> json) => UploadedFile(
        url: (json['url'] as String?) ?? '',
        publicId: json['public_id'] as String?,
        fileType: json['file_type'] as String?,
      );
}
