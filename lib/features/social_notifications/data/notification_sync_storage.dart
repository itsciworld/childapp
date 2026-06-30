import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Liveness watermark for FEATURE A. The queue file itself is the real
/// work-list (drained each pass), so all we persist here is the wall-clock time
/// of the last completed pass — handy for logs / a future "last synced" UI.
class NotificationSyncStorage {
  static const String _lastRunAtKey = 'social_notif_last_run_at_ms';

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

final notificationSyncStorageProvider =
    Provider<NotificationSyncStorage>((ref) => NotificationSyncStorage());
