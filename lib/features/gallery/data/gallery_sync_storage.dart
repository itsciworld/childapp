import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which gallery photos/videos have already been uploaded.
///
/// Like the events sync, this tracks the set of asset ids already sent (instead
/// of a time watermark), so each pass only uploads newly-added media — and if
/// nothing is new, no API call is made. Backed by [SharedPreferences] so it
/// survives restarts and is readable from the background isolate.
class GallerySyncStorage {
  static const String _syncedKeysKey = 'gallery_synced_ids';
  static const String _lastRunAtKey = 'gallery_last_run_at_ms';

  /// The set of asset ids already uploaded.
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
  /// (even when there were no new photos), so the UI can show monitoring is
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

final gallerySyncStorageProvider =
    Provider<GallerySyncStorage>((ref) => GallerySyncStorage());
