import '../data/models/save_apps_response.dart';

enum AppUsageSyncStatus { idle, syncing, synced, error }

/// Immutable state for app-usage sync. Lets the home screen show an Active /
/// Last-sync indicator like the other monitored streams.
class AppUsageState {
  const AppUsageState({
    this.status = AppUsageSyncStatus.idle,
    this.lastResponse,
    this.lastSyncedAt,
  });

  final AppUsageSyncStatus status;
  final SaveAppsResponse? lastResponse;
  final DateTime? lastSyncedAt;

  bool get isSyncing => status == AppUsageSyncStatus.syncing;

  AppUsageState copyWith({
    AppUsageSyncStatus? status,
    SaveAppsResponse? lastResponse,
    DateTime? lastSyncedAt,
  }) {
    return AppUsageState(
      status: status ?? this.status,
      lastResponse: lastResponse ?? this.lastResponse,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}
