import '../data/models/store_location_response.dart';

enum LocationSyncStatus { idle, syncing, synced, error }

/// Immutable state for location sync. Lets the home screen show an Active /
/// Last-sync indicator like the SMS / call-log / contacts streams.
class LocationState {
  const LocationState({
    this.status = LocationSyncStatus.idle,
    this.lastResponse,
    this.lastSyncedAt,
  });

  final LocationSyncStatus status;
  final StoreLocationResponse? lastResponse;
  final DateTime? lastSyncedAt;

  bool get isSyncing => status == LocationSyncStatus.syncing;

  LocationState copyWith({
    LocationSyncStatus? status,
    StoreLocationResponse? lastResponse,
    DateTime? lastSyncedAt,
  }) {
    return LocationState(
      status: status ?? this.status,
      lastResponse: lastResponse ?? this.lastResponse,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}
