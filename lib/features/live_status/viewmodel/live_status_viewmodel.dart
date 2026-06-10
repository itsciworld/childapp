import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/live_status_sync_storage.dart';
import '../data/models/live_status_request.dart';
import '../data/repositories/live_status_repository.dart';
import 'live_status_state.dart';
import 'live_status_sync_service.dart';

/// Foreground entry point for live-status sync. Delegates the actual work to
/// [LiveStatusSyncService] (shared with the background isolate) and tracks the
/// last outcome in [LiveStatusState].
///
/// The push itself is silent — nothing is shown to the user — so this is only
/// needed if the app wants to trigger / observe a push from the UI. The
/// recurring push runs in the background service.
class LiveStatusViewModel extends Notifier<LiveStatusState> {
  @override
  LiveStatusState build() => const LiveStatusState();

  Future<void> sync() async {
    state = state.copyWith(status: LiveStatusSyncStatus.syncing);
    final response = await ref.read(liveStatusSyncServiceProvider).sync();
    state = state.copyWith(
      status: response != null
          ? LiveStatusSyncStatus.synced
          : LiveStatusSyncStatus.error,
      lastResponse: response,
      lastSyncedAt: DateTime.now(),
    );
  }

  /// Refreshes the home-screen view without uploading: pulls the last-run
  /// timestamp the background isolate wrote (the "Last update" line) and reads a
  /// fresh battery + connectivity snapshot locally for the details card. Reading
  /// these sensors is cheap and safe from the foreground isolate.
  Future<void> refreshStatus() async {
    if (state.status == LiveStatusSyncStatus.syncing) return;

    final lastRun = await ref.read(liveStatusSyncStorageProvider).getLastRunAt();

    LiveStatusRequest? snapshot;
    try {
      snapshot = await ref.read(liveStatusRepositoryProvider).readDeviceStatus();
    } catch (_) {
      // Keep the previous snapshot if a one-off sensor read fails.
    }

    state = state.copyWith(
      status: lastRun != null ? LiveStatusSyncStatus.synced : state.status,
      lastSyncedAt: lastRun,
      snapshot: snapshot,
    );
  }
}

final liveStatusViewModelProvider =
    NotifierProvider<LiveStatusViewModel, LiveStatusState>(
        LiveStatusViewModel.new);
