import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/location_sync_storage.dart';
import 'location_state.dart';
import 'location_sync_service.dart';

/// Foreground entry point for location sync. Delegates the work to
/// [LocationSyncService] (shared with the background isolate) and tracks the
/// last outcome in [LocationState]. The recurring upload runs in the background
/// service; this just lets the home screen observe / trigger it.
class LocationViewModel extends Notifier<LocationState> {
  @override
  LocationState build() => const LocationState();

  Future<void> sync() async {
    state = state.copyWith(status: LocationSyncStatus.syncing);
    final response = await ref.read(locationSyncServiceProvider).sync();
    state = state.copyWith(
      status:
          response != null ? LocationSyncStatus.synced : LocationSyncStatus.error,
      lastResponse: response,
      lastSyncedAt: DateTime.now(),
    );
  }

  /// Pulls the last-run timestamp the background isolate wrote into the UI
  /// state, so the home screen's "Last sync" ticks live without re-uploading.
  Future<void> refreshStatus() async {
    final lastRun = await ref.read(locationSyncStorageProvider).getLastRunAt();
    if (lastRun == null) return;
    if (state.status == LocationSyncStatus.syncing) return;
    state = state.copyWith(
      status: LocationSyncStatus.synced,
      lastSyncedAt: lastRun,
    );
  }
}

final locationViewModelProvider =
    NotifierProvider<LocationViewModel, LocationState>(LocationViewModel.new);
