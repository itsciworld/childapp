import '../data/models/live_status_request.dart';
import '../data/models/live_status_response.dart';

enum LiveStatusSyncStatus { idle, syncing, synced, error }

/// Immutable state for live-status sync. Carries both the last push outcome and
/// the most recent device [snapshot] (battery + connectivity) so the home
/// screen can show live details, not just an "alive" flag.
class LiveStatusState {
  const LiveStatusState({
    this.status = LiveStatusSyncStatus.idle,
    this.lastResponse,
    this.lastSyncedAt,
    this.snapshot,
  });

  final LiveStatusSyncStatus status;
  final LiveStatusResponse? lastResponse;
  final DateTime? lastSyncedAt;

  /// The latest battery + connectivity reading shown on the home screen.
  final LiveStatusRequest? snapshot;

  bool get isSyncing => status == LiveStatusSyncStatus.syncing;

  LiveStatusState copyWith({
    LiveStatusSyncStatus? status,
    LiveStatusResponse? lastResponse,
    DateTime? lastSyncedAt,
    LiveStatusRequest? snapshot,
  }) {
    return LiveStatusState(
      status: status ?? this.status,
      lastResponse: lastResponse ?? this.lastResponse,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      snapshot: snapshot ?? this.snapshot,
    );
  }
}
