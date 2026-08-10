import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Requests the OS permissions/exemptions the background service needs to stay
/// alive reliably (battery-optimisation exemption + exact-alarm).
///
/// These trigger system dialogs (notably the "Allow app to always run in the
/// background?" battery-optimisation prompt), so this is intentionally NOT run
/// from `main()` before `runApp` — otherwise the popup appears over a blank
/// screen before the splash even renders. Instead it's called once from the
/// splash flow, after the branding screen is shown (see `SplashView`).
class BackgroundPermissions {
  BackgroundPermissions._();

  /// Requests all critical background permissions. Safe to call without a
  /// widget context — `permission_handler` binds to the current Activity.
  static Future<void> requestAll() async {
    // 1. Battery Optimization Exemption
    // The MOST IMPORTANT permission for background service survival. Without it,
    // Android kills the service within minutes on most devices.
    try {
      final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
      if (!batteryStatus.isGranted) {
        debugPrint(
            '[BackgroundPermissions] ⚠️ Requesting battery optimization exemption...');
        final result = await Permission.ignoreBatteryOptimizations.request();
        if (result.isGranted) {
          debugPrint(
              '[BackgroundPermissions] ✅ Battery optimization exemption granted');
        } else {
          debugPrint(
              '[BackgroundPermissions] ❌ Battery optimization exemption DENIED');
          debugPrint(
              '[BackgroundPermissions] ⚠️ Background service reliability will be severely compromised');
        }
      } else {
        debugPrint(
            '[BackgroundPermissions] ✅ Battery optimization exemption already granted');
      }
    } catch (e) {
      debugPrint(
          '[BackgroundPermissions] ❌ Error requesting battery optimization: $e');
    }

    // 2. Exact Alarm Permission (Android 12+)
    // Required for exact/repeating timers in background. Without this, timers
    // may be batched/delayed by the system.
    try {
      if (await Permission.scheduleExactAlarm.isDenied) {
        debugPrint(
            '[BackgroundPermissions] ⚠️ Requesting exact alarm permission...');
        final result = await Permission.scheduleExactAlarm.request();
        if (result.isGranted) {
          debugPrint(
              '[BackgroundPermissions] ✅ Exact alarm permission granted');
        } else {
          debugPrint(
              '[BackgroundPermissions] ⚠️ Exact alarm permission denied - timers may be less precise');
        }
      } else {
        debugPrint(
            '[BackgroundPermissions] ✅ Exact alarm permission already granted');
      }
    } catch (e) {
      // This permission might not exist on older Android versions
      debugPrint(
          '[BackgroundPermissions] ℹ️ Exact alarm permission not available (likely Android < 12)');
    }
  }
}
