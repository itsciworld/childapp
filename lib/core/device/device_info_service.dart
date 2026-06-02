import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The device's display name and a stable hardware identifier, read from the
/// OS via `device_info_plus`.
class DeviceDetails {
  const DeviceDetails({required this.name, required this.id});

  final String name;
  final String id;
}

/// Reads the current device's name and id from the platform.
class DeviceInfoService {
  DeviceInfoService([DeviceInfoPlugin? plugin])
      : _plugin = plugin ?? DeviceInfoPlugin();

  final DeviceInfoPlugin _plugin;

  /// Returns the device name (e.g. "Samsung SM-G991B") and a stable id.
  ///
  /// Falls back to an "Unknown Device" placeholder on unsupported platforms
  /// or if the plugin throws.
  Future<DeviceDetails> read() async {
    try {
      if (Platform.isAndroid) {
        final info = await _plugin.androidInfo;
        final name = info.isPhysicalDevice
            ? '${info.manufacturer} ${info.model}'.trim()
            : '${info.model} (Emulator)';
        return DeviceDetails(name: name, id: info.id);
      }
      if (Platform.isIOS) {
        final info = await _plugin.iosInfo;
        return DeviceDetails(
          name: info.name,
          id: info.identifierForVendor ?? info.name,
        );
      }
    } catch (e) {
      debugPrint('[DeviceInfoService] Failed to read device info: $e');
    }
    return const DeviceDetails(name: 'Unknown Device', id: '');
  }
}

final deviceInfoServiceProvider =
    Provider<DeviceInfoService>((ref) => DeviceInfoService());
