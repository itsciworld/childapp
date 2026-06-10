import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which calendar events have already been uploaded.
///
/// Like the contacts sync, this tracks the set of event ids already sent
/// (instead of a time watermark), so each pass only uploads newly-added events
/// — and if nothing is new, no API call is made. Backed by [SharedPreferences]
/// so it survives restarts and is readable from the background isolate.
class EventSyncStorage {
  static const String _syncedKeysKey = 'event_synced_ids';
  static const String _lastRunAtKey = 'event_last_run_at_ms';

  /// The set of event ids already uploaded.
  Future<Set<String>> getSyncedKeys() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return (prefs.getStringList(_syncedKeysKey) ?? const []).toSet();
  }

  /// Adds [keys] to the uploaded set (union with what's already stored).
  Future<void> addSyncedKeys(Iterable<String> keys) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final merged = {
      ...(prefs.getStringList(_syncedKeysKey) ?? const []),
      ...keys,
    };
    await prefs.setStringList(_syncedKeysKey, merged.toList());
  }

  /// The wall-clock time the last sync pass completed — updated on every pass
  /// (even when there were no new events), so the UI can show monitoring is
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

final eventSyncStorageProvider =
    Provider<EventSyncStorage>((ref) => EventSyncStorage());
