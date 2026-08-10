import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers how far the SMS upload has progressed.
///
/// Backed by [SharedPreferences] so the watermark survives app restarts and is
/// readable from the background isolate. This is what makes the sync
/// incremental: open the app today, upload up to now; reopen two hours later
/// and only the messages *after* the last upload are sent.
class SmsSyncStorage {
  static const String _lastSyncedAtKey = 'sms_last_synced_at_ms';
  static const String _lastRunAtKey = 'sms_last_run_at_ms';
  static const String _lastErrorKey = 'sms_last_error';
  static const String _failureStreakKey = 'sms_failure_streak';
  static const String _lastSyncedIdsKey = 'sms_last_synced_ids';

  /// The timestamp of the newest SMS already uploaded, or `null` if the app
  /// has never synced on this device.
  Future<DateTime?> getLastSyncedAt() async {
    final prefs = await SharedPreferences.getInstance();
    // Pick up watermark writes made by the other isolate (foreground vs
    // background both read/write this key).
    await prefs.reload();
    final ms = prefs.getInt(_lastSyncedAtKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setLastSyncedAt(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSyncedAtKey, time.millisecondsSinceEpoch);
  }

  /// The wall-clock time the last sync pass completed — updated on every pass
  /// (even when there were no new messages), so the UI can show that
  /// monitoring is alive. Distinct from [getLastSyncedAt], which is the
  /// newest *uploaded message's* timestamp and only moves on new SMS.
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

  /// Why the most recent pass failed, or `null` when it succeeded.
  ///
  /// Without this the UI could only distinguish "never ran" from "ran", so a
  /// pass that ran and *failed* was indistinguishable from a healthy one — the
  /// home tile went green while nothing was reaching the server.
  Future<String?> getLastError() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getString(_lastErrorKey);
  }

  Future<void> setLastError(String? message) async {
    final prefs = await SharedPreferences.getInstance();
    if (message == null) {
      await prefs.remove(_lastErrorKey);
    } else {
      await prefs.setString(_lastErrorKey, message);
    }
  }

  /// How many times in a row the server has rejected the batch sitting at the
  /// current watermark. Drives the shrink-then-skip recovery in
  /// [SmsSyncService], which is what stops one un-storable message from
  /// blocking every later message behind it.
  Future<int> getFailureStreak() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getInt(_failureStreakKey) ?? 0;
  }

  Future<void> setFailureStreak(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_failureStreakKey, value);
  }

  /// Device message ids already uploaded that carry exactly the watermark's
  /// timestamp.
  ///
  /// The watermark read is inclusive (`>=`), because SMS timestamps collide and
  /// a strict `>` silently dropped every message sharing the boundary
  /// millisecond. Inclusive on its own would re-send the boundary message on
  /// every single pass, so these ids record what was already sent at that exact
  /// instant and the next pass filters them out — no loss, no repeat.
  Future<List<String>> getLastSyncedIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getStringList(_lastSyncedIdsKey) ?? const [];
  }

  Future<void> setLastSyncedIds(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_lastSyncedIdsKey, ids);
  }
}

final smsSyncStorageProvider =
    Provider<SmsSyncStorage>((ref) => SmsSyncStorage());
