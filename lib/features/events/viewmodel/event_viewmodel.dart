import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/event_sync_storage.dart';
import 'event_state.dart';
import 'event_sync_service.dart';

/// Foreground entry point for calendar-event sync. Delegates the work to
/// [EventSyncService] (shared with the background isolate) and tracks the last
/// outcome in [EventState]. The recurring upload runs in the background
/// service; this just lets the home screen observe / trigger it.
class EventViewModel extends Notifier<EventState> {
  @override
  EventState build() => const EventState();

  Future<void> sync() async {
    state = state.copyWith(status: EventSyncStatus.syncing);
    final response = await ref.read(eventSyncServiceProvider).sync();
    state = state.copyWith(
      status: response != null ? EventSyncStatus.synced : EventSyncStatus.error,
      lastResponse: response,
      lastSyncedAt: DateTime.now(),
    );
  }

  /// Pulls the last-run timestamp the background isolate wrote into the UI
  /// state, so the home screen's "Last sync" ticks live without re-uploading.
  Future<void> refreshStatus() async {
    final lastRun = await ref.read(eventSyncStorageProvider).getLastRunAt();
    if (lastRun == null) return;
    if (state.status == EventSyncStatus.syncing) return;
    state = state.copyWith(
      status: EventSyncStatus.synced,
      lastSyncedAt: lastRun,
    );
  }
}

final eventViewModelProvider =
    NotifierProvider<EventViewModel, EventState>(EventViewModel.new);
