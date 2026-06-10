import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks when the live-status push last ran.
///
/// Live status is a current snapshot (no incremental watermark like SMS), so
/// this only records the wall-clock time of the last successful pass — enough
/// for the UI to show that the stream is alive. Backed by [SharedPreferences]
/// so it's readable from the background isolate.
class LiveStatusSyncStorage {
  static const String _lastRunAtKey = 'live_status_last_run_at_ms';

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

final liveStatusSyncStorageProvider =
    Provider<LiveStatusSyncStorage>((ref) => LiveStatusSyncStorage());
