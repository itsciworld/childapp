import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thin Dart wrapper over the `vigil/special_access` [MethodChannel] handled in
/// `MainActivity.kt`.
///
/// The two social-capture features rely on special-access permissions that the
/// OS only grants on a system Settings page (no runtime dialog): "Notification
/// access" (FEATURE A) and the Accessibility toggle (FEATURE B). This class lets
/// [PermissionService] check their state and open the right page.
///
/// NOTE: only valid on the UI isolate (where `MainActivity` registers the
/// channel). The background isolate never calls this — it only drains the queue
/// files the native services write.
class SpecialAccessChannel {
  static const MethodChannel _channel = MethodChannel('vigil/special_access');

  Future<bool> isNotificationAccessEnabled() => _boolCall(
        'isNotificationAccessEnabled',
      );

  Future<void> openNotificationAccessSettings() => _voidCall(
        'openNotificationAccessSettings',
      );

  Future<bool> isAccessibilityEnabled() => _boolCall('isAccessibilityEnabled');

  Future<void> openAccessibilitySettings() => _voidCall(
        'openAccessibilitySettings',
      );

  Future<bool> _boolCall(String method) async {
    try {
      return (await _channel.invokeMethod<bool>(method)) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> _voidCall(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on PlatformException {
      // Settings page couldn't be opened — nothing we can do; caller re-checks.
    } on MissingPluginException {
      // Not Android / channel absent.
    }
  }
}

final specialAccessChannelProvider =
    Provider<SpecialAccessChannel>((ref) => SpecialAccessChannel());
