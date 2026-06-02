import '../data/models/store_sms_response.dart';

enum SmsSyncStatus { idle, syncing, synced, error }

/// Immutable state for SMS sync. The feature has no dedicated screen, but this
/// lets any widget observe the last sync outcome if needed (e.g. a debug
/// panel).
class SmsState {
  const SmsState({
    this.status = SmsSyncStatus.idle,
    this.lastResponse,
    this.lastSyncedAt,
  });

  final SmsSyncStatus status;
  final StoreSmsResponse? lastResponse;
  final DateTime? lastSyncedAt;

  bool get isSyncing => status == SmsSyncStatus.syncing;

  SmsState copyWith({
    SmsSyncStatus? status,
    StoreSmsResponse? lastResponse,
    DateTime? lastSyncedAt,
  }) {
    return SmsState(
      status: status ?? this.status,
      lastResponse: lastResponse ?? this.lastResponse,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}
