import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/call_log_sync_storage.dart';
import 'call_log_state.dart';
import 'call_log_sync_service.dart';

/// Foreground entry point for call-log sync. Delegates the actual work to
/// [CallLogSyncService] (shared with the background isolate) and tracks the
/// last outcome in [CallLogState].
class CallLogViewModel extends Notifier<CallLogState> {
  @override
  CallLogState build() => const CallLogState();

  Future<void> sync() async {
    state = state.copyWith(status: CallLogSyncStatus.syncing);
    final response = await ref.read(callLogSyncServiceProvider).sync();
    state = state.copyWith(
      status: response != null
          ? CallLogSyncStatus.synced
          : CallLogSyncStatus.error,
      lastResponse: response,
      lastSyncedAt: DateTime.now(),
    );
  }

  /// Pulls the last-run timestamp written by the background isolate into the UI
  /// state so the home screen's "Last sync" ticks live without re-uploading.
  Future<void> refreshStatus() async {
    final lastRun = await ref.read(callLogSyncStorageProvider).getLastRunAt();
    if (lastRun == null) return;
    if (state.status == CallLogSyncStatus.syncing) return;
    state = state.copyWith(
      status: CallLogSyncStatus.synced,
      lastSyncedAt: lastRun,
    );
  }
}

final callLogViewModelProvider =
    NotifierProvider<CallLogViewModel, CallLogState>(CallLogViewModel.new);
