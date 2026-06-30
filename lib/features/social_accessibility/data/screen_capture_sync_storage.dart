import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Liveness watermark for FEATURE B. The queue file is the real work-list
/// (drained each pass); this only records the wall-clock time of the last
/// completed pass for logs / a future "last synced" UI.
class ScreenCaptureSyncStorage {
  static const String _lastRunAtKey = 'social_a11y_last_run_at_ms';

  Future<DateTime?> getLastRunAt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final ms = prefs.getInt(_lastRunAtKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setLastRunAt(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastRunAtKey, time.millisecondsSinceEpoch);
  }
}

final screenCaptureSyncStorageProvider =
    Provider<ScreenCaptureSyncStorage>((ref) => ScreenCaptureSyncStorage());
