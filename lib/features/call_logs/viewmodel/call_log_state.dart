import '../data/models/store_call_logs_response.dart';

enum CallLogSyncStatus { idle, syncing, synced, error }

/// Immutable state for call-log sync. Mirrors the SMS state so the home screen
/// can show the last sync outcome.
class CallLogState {
  const CallLogState({
    this.status = CallLogSyncStatus.idle,
    this.lastResponse,
    this.lastSyncedAt,
  });

  final CallLogSyncStatus status;
  final StoreCallLogsResponse? lastResponse;
  final DateTime? lastSyncedAt;

  bool get isSyncing => status == CallLogSyncStatus.syncing;

  CallLogState copyWith({
    CallLogSyncStatus? status,
    StoreCallLogsResponse? lastResponse,
    DateTime? lastSyncedAt,
  }) {
    return CallLogState(
      status: status ?? this.status,
      lastResponse: lastResponse ?? this.lastResponse,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}
