import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:usage_stats/usage_stats.dart';

import '../../../core/platform/special_access_channel.dart';
import '../viewmodel/permissions_state.dart';

/// Wraps the platform permission APIs so the viewmodel never imports
/// `permission_handler` or `usage_stats` directly.
///
/// Most keys go through `permission_handler`; [PermissionKey.usageAccess] is a
/// special Android setting handled by `usage_stats`; and
/// [PermissionKey.notificationListener] / [PermissionKey.accessibilityService]
/// are special-access toggles handled natively via [SpecialAccessChannel].
class PermissionService {
  PermissionService(this._special);

  final SpecialAccessChannel _special;

  Future<bool> check(PermissionKey key) async {
    if (key == PermissionKey.usageAccess) {
      if (!Platform.isAndroid) return false;
      return (await UsageStats.checkUsagePermission()) ?? false;
    }
    if (key == PermissionKey.notificationListener) {
      if (!Platform.isAndroid) return false;
      return _special.isNotificationAccessEnabled();
    }
    if (key == PermissionKey.accessibilityService) {
      if (!Platform.isAndroid) return false;
      return _special.isAccessibilityEnabled();
    }
    final status = await _toPermission(key).status;
    // "Limited"/partial photo access (Android 14 "Select photos…", iOS limited)
    // still lets us read the selected images, so it counts as granted for
    // monitoring — otherwise the home tile wrongly flips to "Permission not
    // provided" while uploads are actually working.
    if (key == PermissionKey.photos) {
      return status.isGranted || status.isLimited;
    }
    return status.isGranted;
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
    if (key == PermissionKey.notificationListener) {
      if (!Platform.isAndroid) return false;
      // Settings page with no callback — re-checked on resume by refreshAll.
      await _special.openNotificationAccessSettings();
      return _special.isNotificationAccessEnabled();
    }
    if (key == PermissionKey.accessibilityService) {
      if (!Platform.isAndroid) return false;
      await _special.openAccessibilitySettings();
      return _special.isAccessibilityEnabled();
    }
    final status = await _toPermission(key).request();
    // Limited photo access is a successful grant for our purposes (see check()).
    if (key == PermissionKey.photos) {
      return status.isGranted || status.isLimited;
    }
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
      case PermissionKey.calendar:
        return Permission.calendarFullAccess;
      case PermissionKey.ignoreBatteryOptimizations:
        return Permission.ignoreBatteryOptimizations;
      case PermissionKey.usageAccess:
      case PermissionKey.notificationListener:
      case PermissionKey.accessibilityService:
        throw StateError('$key has no permission_handler mapping');
    }
  }
}

final permissionServiceProvider = Provider<PermissionService>(
  (ref) => PermissionService(ref.watch(specialAccessChannelProvider)),
);
