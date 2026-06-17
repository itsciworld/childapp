import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/identity_storage.dart';
import '../data/gallery_sync_storage.dart';
import '../data/models/media_item.dart';
import '../data/models/store_files_response.dart';
import '../data/repositories/gallery_repository.dart';

/// Reads device gallery photos and uploads any new ones to the backend in two
/// steps: first the binaries (→ hosted URLs), then their metadata.
///
/// Shared by the UI [GalleryViewModel] and the background isolate. Runs silently
/// but logs every step with [debugPrint]. Crucially, when there are no new
/// photos it does NOT call the API — it just records liveness and returns.
class GallerySyncService {
  GallerySyncService(
      this._repository, this._identityStorage, this._syncStorage);

  final GalleryRepository _repository;
  final IdentityStorage _identityStorage;
  final GallerySyncStorage _syncStorage;

  static const String _tag = '[GallerySync]';

  /// Photos sent per upload request. The backend accepts up to 30 files / 50 MB
  /// per `upload-multiple` call; each resized JPEG is only a few hundred KB, so
  /// 20 stays comfortably under both the file-count and total-size caps while
  /// cutting round trips ~20× versus one-at-a-time.
  static const int _batchSize = 20;

  /// Most photos a single pass will drain before yielding to the next timer
  /// tick. Without this a pass uploads ONE batch and then waits a full interval
  /// — slow for a large gallery. With it, a pass keeps uploading batches
  /// back-to-back (up to this many photos) so a backlog clears in a few passes.
  /// Bounded so one pass never runs unbounded / holds the background leader
  /// lease too long.
  static const int _maxPerPass = 100;

  /// Runs one sync pass. Drains up to [_maxPerPass] new photos back-to-back.
  /// Returns the last `store_files` response when anything was uploaded, or
  /// `null` when the pass was skipped (no identity / no new photos) or failed
  /// before uploading anything.
  Future<StoreFilesResponse?> sync() async {
    try {
      final identity = await _identityStorage.read();
      if (!identity.isComplete) {
        debugPrint('$_tag skipped — childId/parentId not set yet.');
        return null;
      }

      // Local copy of the already-synced set, grown as we upload so each loop
      // iteration reads the NEXT new photos (it's also persisted each batch).
      final synced = await _syncStorage.getSyncedKeys();
      var totalUploaded = 0;
      StoreFilesResponse? lastResponse;

      while (totalUploaded < _maxPerPass) {
        final batch = await _repository.readNewMedia(
          alreadySynced: synced,
          limit: _batchSize,
        );
        if (batch.isEmpty) break; // nothing left to upload

        final response = await _uploadBatch(
          batch,
          childId: identity.childId!,
          parentId: identity.parentId!,
          synced: synced,
        );
        if (response == null) break; // upload produced no usable URLs → stop
        lastResponse = response;
        totalUploaded += batch.length;
      }

      await _syncStorage.setLastRunAt(DateTime.now());

      if (totalUploaded == 0) {
        debugPrint(
            '$_tag no new photossssssssssssssssssss. ss(${synced.length} already synced).');
        return null;
      }
      debugPrint(
          '$_tag pass complete — uploadeddddddddddddddddddddddd $totalUploaded photo(s).');
      return lastResponse;
    } on ApiException catch (e) {
      // Network / server failure mid-drain: whatever already uploaded this pass
      // is marked synced; the rest resume next pass.
      debugPrint('$_tag upload failed (will resume next pass): ${e.message}');
      await _syncStorage.setLastRunAt(DateTime.now());
      return null;
    } catch (e, st) {
      debugPrint('$_tag unexpected error: $e\n$st');
      return null;
    }
  }

  /// Uploads one [batch] (step 1: binaries → URLs, step 2: store metadata),
  /// marks the stored photos as synced (in [synced] and persisted), and returns
  /// the `store_files` response. Returns `null` when the upload yielded no
  /// usable URLs. Throws [ApiException] on a network / server failure.
  Future<StoreFilesResponse?> _uploadBatch(
    List<MediaItem> batch, {
    required String childId,
    required String parentId,
    required Set<String> synced,
  }) async {
    // Step 1: upload the binaries → hosted URLs (same order as the batch).
    final uploaded = await _repository.uploadFiles(
      batch,
      childId: childId,
      parentId: parentId,
    );

    // Zip each returned URL back onto its source photo by index. If the server
    // returned fewer URLs than we sent, only the matched ones proceed; the rest
    // stay unsynced and are retried next pass.
    final withUrls = <MediaItem>[];
    final count = batch.length < uploaded.files.length
        ? batch.length
        : uploaded.files.length;
    for (var i = 0; i < count; i++) {
      final url = uploaded.files[i].url;
      if (url.isEmpty) continue;
      withUrls.add(batch[i].copyWithUrl(url));
    }
    if (withUrls.isEmpty) {
      debugPrint('$_tag upload returned no usable URLs — will retry.');
      return null;
    }

    // Step 2: store the metadata of the uploaded photos.
    final response = await _repository.storeFiles(
      withUrls,
      childId: childId,
      parentId: parentId,
    );

    // Mark only the photos we actually stored as synced — both in our local set
    // (so the next loop iteration skips them) and persisted (survives restart).
    final ids = withUrls.map((e) => e.id);
    synced.addAll(ids);
    await _syncStorage.addSyncedKeys(ids);

    debugPrint(
      '$_tag uploaded ${withUrls.length} photo(s) → '
      'saved ${response.saved}, duplicates ${response.duplicates}, '
      'total ${response.total} ("${response.message}")',
    );
    return response;
  }
}

final gallerySyncServiceProvider = Provider<GallerySyncService>((ref) {
  return GallerySyncService(
    ref.watch(galleryRepositoryProvider),
    ref.watch(identityStorageProvider),
    ref.watch(gallerySyncStorageProvider),
  );
});
