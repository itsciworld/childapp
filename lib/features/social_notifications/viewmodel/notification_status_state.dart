enum NotificationCaptureStatus { idle, syncing, synced, error }

/// Immutable status for notification capture (FEATURE A), so the home screen can
/// show an Active / Last-sync indicator like the other monitored streams. The
/// actual draining + upload runs in the background isolate; this only mirrors
/// the last-run watermark for the UI.
class NotificationStatusState {
  const NotificationStatusState({
    this.status = NotificationCaptureStatus.idle,
    this.lastSyncedAt,
  });

  final NotificationCaptureStatus status;
  final DateTime? lastSyncedAt;

  NotificationStatusState copyWith({
    NotificationCaptureStatus? status,
    DateTime? lastSyncedAt,
  }) {
    return NotificationStatusState(
      status: status ?? this.status,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}
