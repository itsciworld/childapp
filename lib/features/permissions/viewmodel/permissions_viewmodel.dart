import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/device_storage.dart';
import '../../../core/storage/identity_storage.dart';
import '../data/models/permissions_request.dart';
import '../data/permission_service.dart';
import '../data/repositories/permissions_repository.dart';
import 'permissions_state.dart';

/// Holds permission-screen logic. The UI calls [toggle] / [refreshAll] and
/// reacts to [PermissionsState]; it never touches the platform APIs directly.
class PermissionsViewModel extends Notifier<PermissionsState> {
  @override
  PermissionsState build() {
    // Kick off the bulk status check on first build.
    Future.microtask(refreshAll);
    return const PermissionsState(loading: true);
  }

  /// Re-reads the OS status for every permission. Called on open and after
  /// returning from a settings screen.
  Future<void> refreshAll() async {
    final service = ref.read(permissionServiceProvider);
    final granted = <PermissionKey, bool>{};
    for (final key in PermissionKey.values) {
      granted[key] = await service.check(key);
    }
    state = state.copyWith(granted: granted, loading: false);
  }

  /// Requests [key] when [value] is true; sends the user to system settings
  /// when [value] is false (the OS doesn't expose programmatic revocation).
  Future<void> toggle(PermissionKey key, bool value) async {
    if (state.isBusy(key)) return;
    state = state.copyWith(busy: key);

    final service = ref.read(permissionServiceProvider);
    try {
      final bool granted;
      if (value) {
        granted = await service.request(key);
      } else {
        await service.openSettings();
        granted = await service.check(key);
      }

      final updated = Map<PermissionKey, bool>.from(state.granted);
      updated[key] = granted;
      state = state.copyWith(granted: updated, clearBusy: true);
    } catch (e, st) {
      debugPrint('[PermissionsViewModel] toggle($key) failed: $e\n$st');
      state = state.copyWith(clearBusy: true);
    }
  }

  /// Pushes the current toggle selections to
  /// `PUT /api/children/{childId}/permissions`.
  ///
  /// The on-screen toggles map onto the request's `dataAccess` flags (and the
  /// usage / battery flags); everything the child did not grant is sent as
  /// `false`. Returns `true` on success.
  Future<bool> submit() async {
    if (state.submitting) return false;

    final identity = await ref.read(identityStorageProvider).read();
    final childId = identity.childId;
    if (childId == null || childId.isEmpty) {
      debugPrint('[PermissionsViewModel] submit aborted — no childId stored.');
      state = state.copyWith(
        errorMessage: 'Device not paired yet. Please pair again.',
      );
      return false;
    }

    final deviceName = (await ref.read(deviceStorageProvider).read()).name ?? '';

    final request = PermissionsRequest(
      // Special-access toggles the child can grant on this screen.
      allowUsageTracking: state.isGranted(PermissionKey.usageAccess),
      batteryOptimizationAllowed:
          state.isGranted(PermissionKey.ignoreBatteryOptimizations),
      deviceName: deviceName,
      // Per-data-source access driven by the runtime permission toggles.
      dataAccess: DataAccess(
        messages: state.isGranted(PermissionKey.sms),
        contacts: state.isGranted(PermissionKey.contacts),
        callLog: state.isGranted(PermissionKey.phone),
        location: state.isGranted(PermissionKey.location),
        calendar: state.isGranted(PermissionKey.calendar),
        appUsage: state.isGranted(PermissionKey.usageAccess),
        networkWifi: state.isGranted(PermissionKey.nearbyWifiDevices),
      ),
      // Everything else (scanDeviceForSecurity, improveHarmfulDetection,
      // systemUpdateService, administratorAccess, notificationAccess.*)
      // defaults to false.
    );

    state = state.copyWith(submitting: true, clearError: true);
    try {
      final response = await ref
          .read(permissionsRepositoryProvider)
          .updatePermissions(childId, request);
      debugPrint(
          '[PermissionsViewModel] permissions updated: "${response.message}"');
      state = state.copyWith(submitting: false);
      return true;
    } on ApiException catch (e) {
      debugPrint('[PermissionsViewModel] submit failed: ${e.message}');
      state = state.copyWith(submitting: false, errorMessage: e.message);
      return false;
    } catch (e, st) {
      debugPrint('[PermissionsViewModel] submit unexpected error: $e\n$st');
      state = state.copyWith(
        submitting: false,
        errorMessage: 'Something went wrong. Please try again.',
      );
      return false;
    }
  }
}

final permissionsViewModelProvider =
    NotifierProvider<PermissionsViewModel, PermissionsState>(
        PermissionsViewModel.new);
