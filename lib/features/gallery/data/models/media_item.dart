import 'dart:typed_data';

/// A single gallery photo/video.
///
/// This drives the gallery's two-step upload:
///  1. [uploadBytes] (a downscaled JPEG, named [uploadFileName]) is sent to
///     `POST /api/files/upload-multiple`, which returns a hosted URL. The bytes
///     are resized client-side so each request stays under the server's body
///     size limit.
///  2. That URL is stored back as [fileUrl] (see [copyWithUrl]) and this item is
///     serialised via [toJson] into the `media` array of
///     `POST /api/files/store_files`.
///
/// `child_id` / `parent_id` are NOT part of a media item — they are sent once at
/// the top level of each request body (see [GalleryRepository]). [id],
/// [uploadBytes] and [uploadFileName] are used locally only (de-dup + multipart)
/// and are not serialised.
class MediaItem {
  const MediaItem({
    required this.id,
    required this.title,
    required this.type,
    required this.mimeType,
    required this.width,
    required this.height,
    required this.sizeBytes,
    required this.durationSeconds,
    required this.orientation,
    required this.isFavorite,
    required this.createdAt,
    required this.modifiedAt,
    required this.uploadBytes,
    required this.uploadFileName,
    this.albumName,
    this.relativePath,
    this.latitude,
    this.longitude,
    this.fileUrl,
  });

  /// Device-local asset id (photo_manager) — used only for de-duplication; it is
  /// NOT sent in the body.
  final String id;

  /// Original file name, e.g. `IMG_20260602_103045.jpg`. Doubles as the
  /// multipart filename during upload.
  final String title;

  /// `image` or `video`.
  final String type;
  final String mimeType;
  final int width;
  final int height;
  final int sizeBytes;

  /// Seconds for videos; `0` for images.
  final int durationSeconds;
  final int orientation;
  final bool isFavorite;
  final String? albumName;
  final String? relativePath;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final double? latitude;
  final double? longitude;

  /// Downscaled JPEG bytes sent to `upload-multiple`; NOT sent to `store_files`.
  final Uint8List uploadBytes;

  /// Filename used for the multipart part (e.g. `IMG_123.jpg`); NOT serialised.
  final String uploadFileName;

  /// Hosted URL returned by `upload-multiple`; null until the file is uploaded.
  final String? fileUrl;

  /// Returns a copy with the hosted [fileUrl] filled in after upload.
  MediaItem copyWithUrl(String url) => MediaItem(
        id: id,
        title: title,
        type: type,
        mimeType: mimeType,
        width: width,
        height: height,
        sizeBytes: sizeBytes,
        durationSeconds: durationSeconds,
        orientation: orientation,
        isFavorite: isFavorite,
        createdAt: createdAt,
        modifiedAt: modifiedAt,
        uploadBytes: uploadBytes,
        uploadFileName: uploadFileName,
        albumName: albumName,
        relativePath: relativePath,
        latitude: latitude,
        longitude: longitude,
        fileUrl: url,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type,
        'mime_type': mimeType,
        'width': width,
        'height': height,
        'size_bytes': sizeBytes,
        'duration_seconds': durationSeconds,
        'orientation': orientation,
        'is_favorite': isFavorite,
        'album_name': albumName,
        'relative_path': relativePath,
        // ISO-8601 in UTC, e.g. `2026-06-02T10:30:45.000Z`.
        'created_at': createdAt.toUtc().toIso8601String(),
        'modified_at': modifiedAt.toUtc().toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'file_url': fileUrl,
      };
}
