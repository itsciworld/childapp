import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/device_storage.dart';
import '../models/media_item.dart';
import '../models/store_files_response.dart';
import '../models/upload_files_response.dart';

/// Owns all gallery data access: reading photos from the device via
/// `photo_manager`, uploading the binaries to Cloudinary, and recording their
/// metadata. The UI / background loop never touches `photo_manager` or Dio
/// directly — it goes through here.
///
/// The upload is two requests:
///  1. [uploadFiles] → `POST /api/files/upload-multiple` (multipart) returns the
///     hosted URLs.
///  2. [storeFiles] → `POST /api/files/store_files` saves each item's metadata
///     with its URL.
class GalleryRepository {
  GalleryRepository(this._dio, this._deviceStorage);

  final Dio _dio;
  final DeviceStorage _deviceStorage;

  static const String _tag = '[GalleryRepo]';

  /// How many assets to scan per page when walking the device gallery.
  static const int _pageSize = 100;

  /// Longest edge (px) of the downscaled JPEG we upload. Originals are often
  /// several MB — too big for the server's body-size limit — so we send a
  /// resized preview that stays comfortably small.
  static const int _maxEdge = 1080;

  /// JPEG quality (0–100) for the resized upload.
  static const int _jpegQuality = 80;

  /// Whether gallery access is granted.
  ///
  /// Checked read-only via `permission_handler` instead of
  /// `PhotoManager.requestPermissionExtend()`: the latter *requests* the
  /// permission, which needs an Activity and crashes in the background isolate.
  /// The permission is already obtained up front in the permissions UI, so here
  /// we only need to verify it. Android 13+ uses READ_MEDIA_IMAGES
  /// ([Permission.photos]); older versions use storage. `limited` (partial
  /// access) counts as granted.
  Future<bool> hasPermission() async {
    final photos = await Permission.photos.status;
    if (photos.isGranted || photos.isLimited) return true;
    final storage = await Permission.storage.status;
    return storage.isGranted || storage.isLimited;
  }

  /// Walks the device gallery (newest first) and returns up to [limit]
  /// upload-ready [MediaItem]s whose id is NOT in [alreadySynced]. Stops as soon
  /// as [limit] new items are found, so a huge gallery is drained in batches
  /// across passes instead of read all at once.
  ///
  /// Returns an empty list when there is nothing new or permission isn't
  /// granted (the sync just skips that pass — no API call).
  Future<List<MediaItem>> readNewMedia({
    required Set<String> alreadySynced,
    required int limit,
  }) async {
    try {
      if (!await hasPermission()) {
        debugPrint('$_tag gallery permission not granted — skipping.');
        return const [];
      }

      // We've verified the OS grant above via permission_handler, so tell
      // photo_manager to skip its OWN permission check — its internal
      // requestPermissionExtend() needs an Activity and crashes in the
      // background isolate.
      await PhotoManager.setIgnorePermissionCheck(true);

      // Single "all" album, newest first, so paging order is stable.
      final albums = await PhotoManager.getAssetPathList(
        onlyAll: true,
        type: RequestType.image,
        filterOption: FilterOptionGroup(
          orders: [
            const OrderOption(type: OrderOptionType.createDate, asc: false),
          ],
        ),
      );
      if (albums.isEmpty) return const [];

      final all = albums.first;
      final total = await all.assetCountAsync;
      if (total == 0) return const [];

      final items = <MediaItem>[];
      for (var page = 0; items.length < limit && page * _pageSize < total;
          page++) {
        final assets =
            await all.getAssetListPaged(page: page, size: _pageSize);
        if (assets.isEmpty) break;
        for (final asset in assets) {
          if (alreadySynced.contains(asset.id)) continue;
          final item = await _toMediaItem(asset);
          if (item == null) continue;
          items.add(item);
          if (items.length >= limit) break;
        }
      }
      return items;
    } catch (e, st) {
      debugPrint('$_tag failed to read gallery: $e\n$st');
      return const [];
    }
  }

  /// Resolves a single asset into a [MediaItem], generating a downscaled JPEG
  /// for upload plus its metadata. Returns null when the resized bytes can't be
  /// produced (so it's skipped this pass and retried later).
  ///
  /// The uploaded binary is a resized JPEG preview (so it fits the server's body
  /// limit); the metadata still describes the original photo's dimensions, and
  /// `size_bytes` reflects the bytes actually uploaded.
  Future<MediaItem?> _toMediaItem(AssetEntity asset) async {
    try {
      final bytes = await asset.thumbnailDataWithSize(
        const ThumbnailSize.square(_maxEdge),
        quality: _jpegQuality,
      );
      if (bytes == null || bytes.isEmpty) return null;

      final latlng = await asset.latlngAsync();
      final title = await asset.titleAsync;
      final baseName = title.isNotEmpty ? title : asset.id;

      return MediaItem(
        id: asset.id,
        title: title.isNotEmpty ? title : '${asset.id}.jpg',
        // The uploaded preview is always JPEG, regardless of the source format.
        type: 'image',
        mimeType: 'image/jpeg',
        width: asset.width,
        height: asset.height,
        sizeBytes: bytes.length,
        durationSeconds: 0,
        orientation: asset.orientation,
        isFavorite: asset.isFavorite,
        albumName: _albumFromPath(asset.relativePath),
        relativePath: asset.relativePath,
        createdAt: asset.createDateTime,
        modifiedAt: asset.modifiedDateTime,
        latitude: latlng?.latitude,
        longitude: latlng?.longitude,
        uploadBytes: bytes,
        uploadFileName: _jpgName(baseName),
      );
    } catch (e) {
      debugPrint('$_tag skipped asset ${asset.id}: $e');
      return null;
    }
  }

  /// Step 1 — uploads the binaries of [media] to
  /// `POST /api/files/upload-multiple` as multipart form-data, returning the
  /// hosted URLs (same order as [media]).
  ///
  /// [childId] / [parentId] are sent as text fields alongside the files. The
  /// server response is printed so success can be confirmed from the debug log.
  ///
  /// Throws [ApiException] on any network / server failure.
  Future<UploadFilesResponse> uploadFiles(
    List<MediaItem> media, {
    required String childId,
    required String parentId,
  }) async {
    try {
      final deviceKey = await _deviceStorage.getDeviceKey();
      final formData = FormData();
      formData.fields
        ..add(MapEntry('child_id', childId))
        ..add(MapEntry('parent_id', parentId));
      for (final m in media) {
        formData.files.add(
          MapEntry(
            'files',
            MultipartFile.fromBytes(
              m.uploadBytes,
              filename: m.uploadFileName,
              contentType: DioMediaType('image', 'jpeg'),
            ),
          ),
        );
      }

      final response = await _dio.post<dynamic>(
        '/api/files/upload-multiple',
        data: formData,
        options: Options(
          headers: {
            if (deviceKey != null && deviceKey.isNotEmpty)
              'x-device-key': deviceKey,
          },
        ),
      );

      debugPrint('$_tag upload-multiple response '
          '(${response.statusCode}): ${response.data}');

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const ApiException('Unexpected response from the server.');
      }
      return UploadFilesResponse.fromJson(data);
    } on DioException catch (e) {
      debugPrint('$_tag upload-multiple failed: '
          '${e.response?.statusCode} ${e.response?.data ?? e.message}');
      throw ApiException.fromDio(e);
    } on FormatException catch (e) {
      throw ApiException(e.message);
    }
  }

  /// Step 2 — saves the metadata of [media] (each carrying its uploaded
  /// `file_url`) to `POST /api/files/store_files`.
  ///
  /// [childId] / [parentId] are sent once at the top level of the body. The
  /// server response is printed so success can be confirmed from the debug log.
  ///
  /// Throws [ApiException] on any network / server failure.
  Future<StoreFilesResponse> storeFiles(
    List<MediaItem> media, {
    required String childId,
    required String parentId,
  }) async {
    try {
      final deviceKey = await _deviceStorage.getDeviceKey();
      final response = await _dio.post<dynamic>(
        '/api/files/store_files',
        data: {
          'child_id': childId,
          'parent_id': parentId,
          'media': media.map((e) => e.toJson()).toList(),
        },
        options: Options(
          headers: {
            if (deviceKey != null && deviceKey.isNotEmpty)
              'x-device-key': deviceKey,
          },
        ),
      );

      debugPrint('$_tag store_files response '
          '(${response.statusCode}): ${response.data}');

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const ApiException('Unexpected response from the server.');
      }
      return StoreFilesResponse.fromJson(data);
    } on DioException catch (e) {
      debugPrint('$_tag store_files failed: '
          '${e.response?.statusCode} ${e.response?.data ?? e.message}');
      throw ApiException.fromDio(e);
    } on FormatException catch (e) {
      throw ApiException(e.message);
    }
  }

  /// Best-effort album name from a relative path, e.g. `DCIM/Camera/` → `Camera`.
  String? _albumFromPath(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) return null;
    final parts =
        relativePath.split('/').where((p) => p.isNotEmpty).toList();
    return parts.isEmpty ? null : parts.last;
  }

  /// Builds a `.jpg` filename for the uploaded preview, since the binary is
  /// always re-encoded as JPEG regardless of the original format.
  String _jpgName(String base) {
    final dot = base.lastIndexOf('.');
    final stem = dot > 0 ? base.substring(0, dot) : base;
    return '$stem.jpg';
  }
}

final galleryRepositoryProvider = Provider<GalleryRepository>((ref) {
  return GalleryRepository(
    ref.watch(dioProvider),
    ref.watch(deviceStorageProvider),
  );
});
