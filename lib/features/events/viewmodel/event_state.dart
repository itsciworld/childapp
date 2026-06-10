import '../data/models/store_events_response.dart';

enum EventSyncStatus { idle, syncing, synced, error }

/// Immutable state for calendar-event sync. Lets the home screen show an
/// Active / Last-sync indicator like the other monitored streams.
class EventState {
  const EventState({
    this.status = EventSyncStatus.idle,
    this.lastResponse,
    this.lastSyncedAt,
  });

  final EventSyncStatus status;
  final StoreEventsResponse? lastResponse;
  final DateTime? lastSyncedAt;

  bool get isSyncing => status == EventSyncStatus.syncing;

  EventState copyWith({
    EventSyncStatus? status,
    StoreEventsResponse? lastResponse,
    DateTime? lastSyncedAt,
  }) {
    return EventState(
      status: status ?? this.status,
      lastResponse: lastResponse ?? this.lastResponse,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}
