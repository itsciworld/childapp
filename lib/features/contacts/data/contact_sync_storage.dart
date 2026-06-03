import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which contacts have already been uploaded.
///
/// Contacts have no reliable "added at" timestamp, so — unlike the SMS / call
/// log sync which watermark on time — this tracks the set of phone numbers
/// already sent. Backed by [SharedPreferences] so it survives app restarts and
/// is readable from the background isolate. The result is the same incremental
/// behaviour: only newly-added contacts are uploaded on each pass.
class ContactSyncStorage {
  static const String _syncedKeysKey = 'contact_synced_phones';
  static const String _lastRunAtKey = 'contact_last_run_at_ms';

  /// The set of phone numbers already uploaded.
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
  /// (even when there were no new contacts), so the UI can show monitoring is
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

final contactSyncStorageProvider =
    Provider<ContactSyncStorage>((ref) => ContactSyncStorage());
