import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/screen_capture_sync_storage.dart';
import 'screen_capture_status_state.dart';

/// Foreground status mirror for on-screen chat capture (FEATURE B). The
/// recurring drain + upload runs in the background isolate via
/// [ScreenCaptureSyncService]; this just lets the home screen observe the
/// last-run watermark and show an Active / Last-sync indicator.
class ScreenCaptureStatusViewModel
    extends Notifier<ScreenCaptureStatusState> {
  @override
  ScreenCaptureStatusState build() => const ScreenCaptureStatusState();

  /// Pulls the last-run timestamp the background isolate wrote into the UI
  /// state, so the home screen's "Last sync" ticks live without re-uploading.
  Future<void> refreshStatus() async {
    final lastRun =
        await ref.read(screenCaptureSyncStorageProvider).getLastRunAt();
    if (lastRun == null) return;
    state = state.copyWith(
      status: ScreenCaptureStatus.synced,
      lastSyncedAt: lastRun,
    );
  }
}

final screenCaptureStatusViewModelProvider =
    NotifierProvider<ScreenCaptureStatusViewModel, ScreenCaptureStatusState>(
        ScreenCaptureStatusViewModel.new);
