import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/gallery_sync_storage.dart';
import 'gallery_state.dart';
import 'gallery_sync_service.dart';

/// Foreground entry point for gallery sync. Delegates the work to
/// [GallerySyncService] (shared with the background isolate) and tracks the last
/// outcome in [GalleryState]. The recurring upload runs in the background
/// service; this just lets the home screen observe / trigger it.
class GalleryViewModel extends Notifier<GalleryState> {
  @override
  GalleryState build() => const GalleryState();

  Future<void> sync() async {
    state = state.copyWith(status: GallerySyncStatus.syncing);
    final response = await ref.read(gallerySyncServiceProvider).sync();
    state = state.copyWith(
      status:
          response != null ? GallerySyncStatus.synced : GallerySyncStatus.error,
      lastResponse: response,
      lastSyncedAt: DateTime.now(),
    );
  }

  /// Pulls the last-run timestamp the background isolate wrote into the UI
  /// state, so the home screen's "Last sync" ticks live without re-uploading.
  Future<void> refreshStatus() async {
    final lastRun = await ref.read(gallerySyncStorageProvider).getLastRunAt();
    if (lastRun == null) return;
    if (state.status == GallerySyncStatus.syncing) return;
    state = state.copyWith(
      status: GallerySyncStatus.synced,
      lastSyncedAt: lastRun,
    );
  }
}

final galleryViewModelProvider =
    NotifierProvider<GalleryViewModel, GalleryState>(GalleryViewModel.new);
