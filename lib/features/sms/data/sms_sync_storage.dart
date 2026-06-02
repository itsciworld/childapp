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
}

final smsSyncStorageProvider =
    Provider<SmsSyncStorage>((ref) => SmsSyncStorage());
