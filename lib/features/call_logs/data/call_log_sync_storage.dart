import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers how far the call-log upload has progressed.
///
/// Backed by [SharedPreferences] so the watermark survives app restarts and is
/// readable from the background isolate — the same incremental scheme the SMS
/// sync uses.
class CallLogSyncStorage {
  static const String _lastSyncedAtKey = 'call_log_last_synced_at_ms';
  static const String _lastRunAtKey = 'call_log_last_run_at_ms';

  /// The timestamp of the newest call already uploaded, or `null` if the app
  /// has never synced call logs on this device.
  Future<DateTime?> getLastSyncedAt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final ms = prefs.getInt(_lastSyncedAtKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setLastSyncedAt(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSyncedAtKey, time.millisecondsSinceEpoch);
  }

  /// The wall-clock time the last sync pass completed — updated on every pass
  /// (even when there were no new calls), so the UI can show monitoring is
  /// alive.
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

final callLogSyncStorageProvider =
    Provider<CallLogSyncStorage>((ref) => CallLogSyncStorage());
