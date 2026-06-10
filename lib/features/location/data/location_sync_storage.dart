import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the last *sent* location and run times so the location sync can be
/// distance-based: a new fix is only uploaded once the device has moved far
/// enough from the last sent point, with a periodic heartbeat otherwise.
///
/// Backed by [SharedPreferences] so it survives restarts and is readable from
/// the background isolate.
class LocationSyncStorage {
  static const String _lastLatKey = 'location_last_sent_lat';
  static const String _lastLngKey = 'location_last_sent_lng';
  static const String _lastSentAtKey = 'location_last_sent_at_ms';
  static const String _lastRunAtKey = 'location_last_run_at_ms';

  /// The last latitude/longitude actually uploaded, or `null` if none yet.
  Future<({double lat, double lng})?> getLastSent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final lat = prefs.getDouble(_lastLatKey);
    final lng = prefs.getDouble(_lastLngKey);
    if (lat == null || lng == null) return null;
    return (lat: lat, lng: lng);
  }

  Future<void> setLastSent(double lat, double lng, DateTime at) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_lastLatKey, lat);
    await prefs.setDouble(_lastLngKey, lng);
    await prefs.setInt(_lastSentAtKey, at.millisecondsSinceEpoch);
  }

  /// When the last upload actually happened (drives the heartbeat).
  Future<DateTime?> getLastSentAt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final ms = prefs.getInt(_lastSentAtKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Wall-clock time the last pass ran (even when it skipped sending), so the
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

final locationSyncStorageProvider =
    Provider<LocationSyncStorage>((ref) => LocationSyncStorage());
