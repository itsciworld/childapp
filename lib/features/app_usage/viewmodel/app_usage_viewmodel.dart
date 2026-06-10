import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_usage_sync_storage.dart';
import 'app_usage_state.dart';
import 'app_usage_sync_service.dart';

/// Foreground entry point for app-usage sync. Delegates the work to
/// [AppUsageSyncService] (shared with the background isolate) and tracks the
/// last outcome in [AppUsageState]. The recurring upload runs in the background
/// service; this just lets the home screen observe / trigger it.
class AppUsageViewModel extends Notifier<AppUsageState> {
  @override
  AppUsageState build() => const AppUsageState();

  Future<void> sync() async {
    state = state.copyWith(status: AppUsageSyncStatus.syncing);
    final response = await ref.read(appUsageSyncServiceProvider).sync();
    state = state.copyWith(
      status:
          response != null ? AppUsageSyncStatus.synced : AppUsageSyncStatus.error,
      lastResponse: response,
      lastSyncedAt: DateTime.now(),
    );
  }

  /// Pulls the last-run timestamp the background isolate wrote into the UI
  /// state, so the home screen's "Last sync" ticks live without re-uploading.
  Future<void> refreshStatus() async {
    final lastRun = await ref.read(appUsageSyncStorageProvider).getLastRunAt();
    if (lastRun == null) return;
    if (state.status == AppUsageSyncStatus.syncing) return;
    state = state.copyWith(
      status: AppUsageSyncStatus.synced,
      lastSyncedAt: lastRun,
    );
  }
}

final appUsageViewModelProvider =
    NotifierProvider<AppUsageViewModel, AppUsageState>(AppUsageViewModel.new);
