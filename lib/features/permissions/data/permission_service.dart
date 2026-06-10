import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:usage_stats/usage_stats.dart';

import '../viewmodel/permissions_state.dart';

/// Wraps the platform permission APIs so the viewmodel never imports
/// `permission_handler` or `usage_stats` directly.
///
/// Most keys go through `permission_handler`; [PermissionKey.usageAccess] is a
/// special Android setting handled by `usage_stats`.
class PermissionService {
  Future<bool> check(PermissionKey key) async {
    if (key == PermissionKey.usageAccess) {
      if (!Platform.isAndroid) return false;
      return (await UsageStats.checkUsagePermission()) ?? false;
    }
    return (await _toPermission(key).status).isGranted;
  }

  /// Triggers the OS prompt (or settings screen) for [key] and returns the
  /// resulting granted state.
  Future<bool> request(PermissionKey key) async {
    if (key == PermissionKey.usageAccess) {
      if (!Platform.isAndroid) return false;
      // `usage_stats` only opens the settings screen — there's no callback,
      // so we re-check after the user returns.
      await UsageStats.grantUsagePermission();
      return (await UsageStats.checkUsagePermission()) ?? false;
    }
    final status = await _toPermission(key).request();
    return status.isGranted;
  }

  /// Opens the system app-settings page. The only way to *revoke* a granted
  /// permission is through here — the OS doesn't expose a programmatic API.
  Future<void> openSettings() => openAppSettings();

  Permission _toPermission(PermissionKey key) {
    switch (key) {
      case PermissionKey.location:
        return Permission.location;
      case PermissionKey.contacts:
        return Permission.contacts;
      case PermissionKey.sms:
        return Permission.sms;
      case PermissionKey.phone:
        return Permission.phone;
      case PermissionKey.photos:
        return Permission.photos;
      case PermissionKey.notification:
        return Permission.notification;
      case PermissionKey.nearbyWifiDevices:
        return Permission.nearbyWifiDevices;
      case PermissionKey.ignoreBatteryOptimizations:
        return Permission.ignoreBatteryOptimizations;
      case PermissionKey.usageAccess:
        throw StateError('usageAccess has no permission_handler mapping');
    }
  }
}

final permissionServiceProvider =
    Provider<PermissionService>((ref) => PermissionService());
