import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The persisted device name / id and the backend-issued device key.
class StoredDevice {
  const StoredDevice({this.name, this.id, this.key});

  /// Human-readable hardware name (e.g. "Samsung SM-G991B").
  final String? name;

  /// Stable hardware identifier from `device_info_plus`.
  final String? id;

  /// Backend-issued device key, sent in the `x-device-key` header.
  final String? key;
}

/// Persists the paired device's name / id and the backend device key in
/// [SharedPreferences] so they survive app restarts and can be read from any
/// isolate.
class DeviceStorage {
  static const String _nameKey = 'deviceName';
  static const String _idKey = 'deviceId';
  static const String _keyKey = 'deviceKey';

  Future<void> save({String? name, String? id, String? key}) async {
    final prefs = await SharedPreferences.getInstance();
    if (name != null && name.isNotEmpty) {
      await prefs.setString(_nameKey, name);
    }
    if (id != null && id.isNotEmpty) {
      await prefs.setString(_idKey, id);
    }
    if (key != null && key.isNotEmpty) {
      await prefs.setString(_keyKey, key);
    }
  }

  Future<StoredDevice> read() async {
    final prefs = await SharedPreferences.getInstance();
    // The background isolate caches prefs from app boot; reload so it sees
    // values written later by the main isolate.
    await prefs.reload();
    return StoredDevice(
      name: prefs.getString(_nameKey),
      id: prefs.getString(_idKey),
      key: prefs.getString(_keyKey),
    );
  }

  /// Convenience reader for the device key alone — used by the SMS upload
  /// header without pulling the full [StoredDevice].
  Future<String?> getDeviceKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getString(_keyKey);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_nameKey);
    await prefs.remove(_idKey);
    await prefs.remove(_keyKey);
  }
}

final deviceStorageProvider = Provider<DeviceStorage>((ref) => DeviceStorage());

/// One-shot read of the stored device name / id — handy for screens that just
/// need to display the paired device's details.
final storedDeviceProvider = FutureProvider<StoredDevice>((ref) {
  return ref.watch(deviceStorageProvider).read();
});
