import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notification_sync_storage.dart';
import 'notification_status_state.dart';

/// Foreground status mirror for notification capture (FEATURE A). The recurring
/// drain + upload runs in the background isolate via [NotificationSyncService];
/// this just lets the home screen observe the last-run watermark and show an
/// Active / Last-sync indicator, exactly like [AppUsageViewModel].
class NotificationStatusViewModel extends Notifier<NotificationStatusState> {
  @override
  NotificationStatusState build() => const NotificationStatusState();

  /// Pulls the last-run timestamp the background isolate wrote into the UI
  /// state, so the home screen's "Last sync" ticks live without re-uploading.
  Future<void> refreshStatus() async {
    final lastRun =
        await ref.read(notificationSyncStorageProvider).getLastRunAt();
    if (lastRun == null) return;
    state = state.copyWith(
      status: NotificationCaptureStatus.synced,
      lastSyncedAt: lastRun,
    );
  }
}

final notificationStatusViewModelProvider =
    NotifierProvider<NotificationStatusViewModel, NotificationStatusState>(
        NotificationStatusViewModel.new);
