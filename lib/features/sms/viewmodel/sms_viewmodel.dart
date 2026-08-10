import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sms_sync_storage.dart';
import 'sms_state.dart';
import 'sms_sync_service.dart';

/// Foreground entry point for SMS sync. Delegates the actual work to
/// [SmsSyncService] (shared with the background isolate) and tracks the last
/// outcome in [SmsState].
///
/// The sync itself is silent — nothing is shown to the user — so this is only
/// needed if the app ever wants to trigger / observe a sync from the UI. The
/// recurring upload runs in the background service.
class SmsViewModel extends Notifier<SmsState> {
  @override
  SmsState build() => const SmsState();

  Future<void> sync() async {
    state = state.copyWith(status: SmsSyncStatus.syncing);
    final response = await ref.read(smsSyncServiceProvider).sync();
    // A null response is NOT a failure — it just means the pass had nothing to
    // upload, which is the steady state. Read the recorded error instead, so a
    // quiet inbox no longer shows up as an error.
    final error = await ref.read(smsSyncStorageProvider).getLastError();
    state = state.copyWith(
      status: error == null ? SmsSyncStatus.synced : SmsSyncStatus.error,
      lastResponse: response,
      lastSyncedAt: DateTime.now(),
    );
  }

  /// Pulls the last-run timestamp written by the background isolate (every
  /// 5s) into the UI state, so the home screen's "Last sync" ticks live while
  /// the user stays on the page — without triggering another upload.
  Future<void> refreshStatus() async {
    final storage = ref.read(smsSyncStorageProvider);
    final lastRun = await storage.getLastRunAt();
    if (lastRun == null) return;
    // Don't clobber an in-flight foreground sync.
    if (state.status == SmsSyncStatus.syncing) return;
    // Surface a failing background pass as "Retrying" instead of reporting
    // every pass as a success.
    final error = await storage.getLastError();
    state = state.copyWith(
      status: error == null ? SmsSyncStatus.synced : SmsSyncStatus.error,
      lastSyncedAt: lastRun,
    );
  }
}

final smsViewModelProvider =
    NotifierProvider<SmsViewModel, SmsState>(SmsViewModel.new);
