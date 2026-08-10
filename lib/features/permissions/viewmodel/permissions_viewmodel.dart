import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/device_storage.dart';
import '../../../core/storage/identity_storage.dart';
import '../../../services/background_services/background_services.dart';
import '../data/models/permissions_request.dart';
import '../data/permission_service.dart';
import '../data/repositories/permissions_repository.dart';
import 'permissions_state.dart';

/// Holds permission-screen logic. The UI calls [toggle] / [refreshAll] and
/// reacts to [PermissionsState]; it never touches the platform APIs directly.
class PermissionsViewModel extends Notifier<PermissionsState> {
  /// Debounce timer for the auto-save that pushes each permission change to the
  /// backend without waiting for a "Continue"/"Save" tap.
  Timer? _autoSaveTimer;

  /// Guards a single auto-save from overlapping the next one (the permissions
  /// PUT sends the full state, so overlapping calls could land out of order).
  bool _autoSaveInFlight = false;

  /// True once the first [refreshAll] has populated the grants — so the initial
  /// load doesn't fire an auto-save before the child has actually changed
  /// anything.
  bool _grantsInitialised = false;

  @override
  PermissionsState build() {
    ref.onDispose(() => _autoSaveTimer?.cancel());
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
    final changed = _grantsChanged(state.granted, granted);
    state = state.copyWith(granted: granted, loading: false);

    // Covers the grant-from-system-settings path (no callback, so this runs on
    // resume). No-ops unless the service types actually changed.
    await BackgroundService.refreshForegroundServiceTypes();

    // Auto-save changes detected on resume — e.g. a permission revoked, or a
    // special-access permission (usage / notification-listener / accessibility)
    // granted on the system settings screen. Skipped on the very first load so
    // we don't push the initial state before the child does anything.
    if (_grantsInitialised && changed) _scheduleAutoSave();
    _grantsInitialised = true;
  }

  /// Requests [key] when [value] is true; sends the user to system settings
  /// when [value] is false (the OS doesn't expose programmatic revocation).
  Future<void> toggle(PermissionKey key, bool value) async {
    if (state.isBusy(key)) return;
    final wasGranted = state.isGranted(key);
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

      // The foreground service only claims the `location` service type while the
      // permission backing it is granted (claiming it without the permission
      // makes Android 14 kill the process). Recycle it here so it starts — or
      // stops — claiming that type as soon as the child flips this toggle.
      if (key == PermissionKey.location) {
        await BackgroundService.refreshForegroundServiceTypes();
      }

      // Auto-save the change to the backend immediately — no "Continue" tap
      // needed. (A revoke opened in system settings isn't reflected here yet;
      // it's picked up by [refreshAll] on resume, which also auto-saves.)
      if (granted != wasGranted) _scheduleAutoSave();
    } catch (e, st) {
      debugPrint('[PermissionsViewModel] toggle($key) failed: $e\n$st');
      state = state.copyWith(clearBusy: true);
    }
  }

  /// True if [b] differs from [a] for any permission key.
  bool _grantsChanged(
      Map<PermissionKey, bool> a, Map<PermissionKey, bool> b) {
    for (final entry in b.entries) {
      if ((a[entry.key] ?? false) != entry.value) return true;
    }
    return false;
  }

  /// Debounced trigger for [_runAutoSave] — coalesces a burst of toggles into a
  /// single backend PUT.
  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 400), _runAutoSave);
  }

  /// Pushes the current selections to the backend without blocking the UI. If a
  /// push is already running, retries shortly so the latest state still lands.
  Future<void> _runAutoSave() async {
    if (_autoSaveInFlight) {
      _scheduleAutoSave();
      return;
    }
    _autoSaveInFlight = true;
    try {
      await _pushPermissions();
    } finally {
      _autoSaveInFlight = false;
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
    // The explicit tap supersedes any pending debounced auto-save.
    _autoSaveTimer?.cancel();
    return _pushPermissions(markSubmitting: true);
  }

  /// SharedPreferences key holding the signature of the last successfully-synced
  /// permission set.
  static const String _syncSigKey = 'perm_last_synced_signature';

  /// A stable string capturing the grant state of every permission, in a fixed
  /// order — used to detect whether anything changed since the last sync.
  String _grantsSignature(Map<PermissionKey, bool> grants) {
    final sb = StringBuffer();
    for (final key in PermissionKey.values) {
      sb.write((grants[key] ?? false) ? '1' : '0');
    }
    return sb.toString();
  }

  Future<void> _storeSyncedSignature() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_syncSigKey, _grantsSignature(state.granted));
  }

  /// Reads the live OS permission state and, if it differs from what was last
  /// synced, pushes it to the backend.
  ///
  /// This is the safety net for revocations: turning a permission OFF happens on
  /// the system settings screen, which frequently kills/restarts the app — so
  /// the per-toggle auto-save never runs. Calling this when the child lands on
  /// (or resumes) the home screen guarantees the backend catches up regardless.
  Future<void> reconcileWithBackend() async {
    final service = ref.read(permissionServiceProvider);
    final granted = <PermissionKey, bool>{};
    for (final key in PermissionKey.values) {
      granted[key] = await service.check(key);
    }
    state = state.copyWith(granted: granted, loading: false);
    _grantsInitialised = true;

    final prefs = await SharedPreferences.getInstance();
    if (_grantsSignature(granted) == prefs.getString(_syncSigKey)) {
      return; // nothing changed since the last successful sync
    }
    // _pushPermissions stores the new signature on success.
    await _pushPermissions();
  }

  /// Builds the request from the current toggle state and PUTs it to
  /// `/api/children/{childId}/permissions`.
  ///
  /// [markSubmitting] drives the Continue button's spinner; the debounced
  /// auto-save calls this silently (`false`) so toggling never shows a spinner.
  Future<bool> _pushPermissions({bool markSubmitting = false}) async {
    final identity = await ref.read(identityStorageProvider).read();
    final childId = identity.childId;
    if (childId == null || childId.isEmpty) {
      debugPrint('[PermissionsViewModel] push aborted — no childId stored.');
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
        photos: state.isGranted(PermissionKey.photos),
        notification: state.isGranted(PermissionKey.notification),
        messageNotifications:
            state.isGranted(PermissionKey.notificationListener),
        chatScreen: state.isGranted(PermissionKey.accessibilityService),
      ),
      // Everything else (scanDeviceForSecurity, improveHarmfulDetection,
      // systemUpdateService, administratorAccess, notificationAccess.*)
      // defaults to false.
    );

    state = markSubmitting
        ? state.copyWith(submitting: true, clearError: true)
        : state.copyWith(clearError: true);
    try {
      final response = await ref
          .read(permissionsRepositoryProvider)
          .updatePermissions(childId, request);
      debugPrint(
          '[PermissionsViewModel] permissions updated: "${response.message}"');
      state = state.copyWith(submitting: false);
      // Remember what we just synced so the home-screen reconcile can tell when
      // nothing has changed and skip a redundant PUT.
      await _storeSyncedSignature();
      return true;
    } on ApiException catch (e) {
      debugPrint('[PermissionsViewModel] push failed: ${e.message}');
      state = state.copyWith(submitting: false, errorMessage: e.message);
      return false;
    } catch (e, st) {
      debugPrint('[PermissionsViewModel] push unexpected error: $e\n$st');
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
