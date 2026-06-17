import '../data/models/store_files_response.dart';

enum GallerySyncStatus { idle, syncing, synced, error }

/// Immutable state for gallery sync. Lets the home screen show an Active /
/// Last-sync indicator like the other monitored streams.
class GalleryState {
  const GalleryState({
    this.status = GallerySyncStatus.idle,
    this.lastResponse,
    this.lastSyncedAt,
  });

  final GallerySyncStatus status;
  final StoreFilesResponse? lastResponse;
  final DateTime? lastSyncedAt;

  bool get isSyncing => status == GallerySyncStatus.syncing;

  GalleryState copyWith({
    GallerySyncStatus? status,
    StoreFilesResponse? lastResponse,
    DateTime? lastSyncedAt,
  }) {
    return GalleryState(
      status: status ?? this.status,
      lastResponse: lastResponse ?? this.lastResponse,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}
