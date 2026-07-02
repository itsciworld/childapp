enum ScreenCaptureStatus { idle, syncing, synced, error }

/// Immutable status for on-screen chat capture (FEATURE B), so the home screen
/// can show an Active / Last-sync indicator like the other monitored streams.
/// The actual draining + upload runs in the background isolate; this only
/// mirrors the last-run watermark for the UI.
class ScreenCaptureStatusState {
  const ScreenCaptureStatusState({
    this.status = ScreenCaptureStatus.idle,
    this.lastSyncedAt,
  });

  final ScreenCaptureStatus status;
  final DateTime? lastSyncedAt;

  ScreenCaptureStatusState copyWith({
    ScreenCaptureStatus? status,
    DateTime? lastSyncedAt,
  }) {
    return ScreenCaptureStatusState(
      status: status ?? this.status,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}
