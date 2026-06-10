import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the last uploaded app-usage snapshot so the sync is change-based:
/// it only POSTs when the usage picture actually changed, with a periodic
/// heartbeat otherwise. Backed by [SharedPreferences] so it survives restarts
/// and is readable from the background isolate.
class AppUsageSyncStorage {
  static const String _signatureKey = 'app_usage_signature';
  static const String _lastSentAtKey = 'app_usage_last_sent_at_ms';
  static const String _lastRunAtKey = 'app_usage_last_run_at_ms';

  /// A digest of the last uploaded usage list (empty string if never sent).
  Future<String> getSignature() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getString(_signatureKey) ?? '';
  }

  Future<void> setSignature(String signature, DateTime at) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_signatureKey, signature);
    await prefs.setInt(_lastSentAtKey, at.millisecondsSinceEpoch);
  }

  /// When the last upload happened (drives the heartbeat).
  Future<DateTime?> getLastSentAt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final ms = prefs.getInt(_lastSentAtKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Wall-clock time of the last pass (even when it skipped sending), so the
  /// home screen can show the stream is alive.
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

final appUsageSyncStorageProvider =
    Provider<AppUsageSyncStorage>((ref) => AppUsageSyncStorage());
