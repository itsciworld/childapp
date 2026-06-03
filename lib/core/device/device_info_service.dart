import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The device's display name and a stable hardware identifier, read from the
/// OS via `device_info_plus`.
class DeviceDetails {
  const DeviceDetails({required this.name, required this.id});

  final String name;
  final String id;
}

/// The full set of hardware / OS / app fields reported to the backend by the
/// `device` feature (`POST /api/children/{childId}/device-info`).
class DeviceInfoData {
  const DeviceInfoData({
    required this.deviceId,
    required this.model,
    required this.manufacturer,
    required this.osVersion,
    required this.appVersion,
    required this.sdkVersion,
  });

  final String deviceId;
  final String model;
  final String manufacturer;
  final String osVersion;
  final String appVersion;
  final String sdkVersion;
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

  /// Reads the full hardware / OS / app payload for the backend `device-info`
  /// endpoint. The app version comes from `package_info_plus`; everything else
  /// from `device_info_plus`. Unknown fields fall back to empty strings.
  Future<DeviceInfoData> readDeviceInfo() async {
    String appVersion = '';
    try {
      final package = await PackageInfo.fromPlatform();
      appVersion = package.version;
    } catch (e) {
      debugPrint('[DeviceInfoService] Failed to read app version: $e');
    }

    try {
      if (Platform.isAndroid) {
        final info = await _plugin.androidInfo;
        return DeviceInfoData(
          deviceId: info.id,
          model: info.model,
          manufacturer: info.manufacturer,
          osVersion: 'Android ${info.version.release}',
          appVersion: appVersion,
          sdkVersion: '${info.version.sdkInt}',
        );
      }
      if (Platform.isIOS) {
        final info = await _plugin.iosInfo;
        return DeviceInfoData(
          deviceId: info.identifierForVendor ?? '',
          model: info.utsname.machine,
          manufacturer: 'Apple',
          osVersion: '${info.systemName} ${info.systemVersion}',
          appVersion: appVersion,
          sdkVersion: info.systemVersion,
        );
      }
    } catch (e) {
      debugPrint('[DeviceInfoService] Failed to read device info: $e');
    }

    return DeviceInfoData(
      deviceId: '',
      model: 'Unknown',
      manufacturer: 'Unknown',
      osVersion: '',
      appVersion: appVersion,
      sdkVersion: '',
    );
  }
}

final deviceInfoServiceProvider =
    Provider<DeviceInfoService>((ref) => DeviceInfoService());
