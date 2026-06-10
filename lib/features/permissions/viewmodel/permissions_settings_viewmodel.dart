import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/identity_storage.dart';
import '../data/models/permissions_request.dart';
import '../data/permission_service.dart';
import '../data/repositories/permissions_repository.dart';
import 'permissions_settings_state.dart';
import 'permissions_state.dart';

/// Drives the full permissions *settings* screen: loads the current config from
/// the backend, lets the UI edit it, and saves it back. The UI calls [load] /
/// [update] / [save] and reacts to [PermissionsSettingsState]; it never touches
/// Dio or storage directly.
class PermissionsSettingsViewModel
    extends Notifier<PermissionsSettingsState> {
  @override
  PermissionsSettingsState build() => const PermissionsSettingsState();

  Future<String?> _childId() async {
    final identity = await ref.read(identityStorageProvider).read();
    final childId = identity.childId;
    return (childId == null || childId.isEmpty) ? null : childId;
  }

  /// Fetches the current permissions for the paired child.
  ///
  /// Loads in the background so the page can render its UI immediately: the
  /// on-device permission state is read first and reflected right away (no
  /// network wait), then the backend config is fetched and merged on top.
  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);

    // Reflect the live OS grants straight away so the device-backed toggles
    // are correct before the network call returns.
    state = state.copyWith(config: await _withLiveOsState(state.config));

    final childId = await _childId();
    if (childId == null) {
      state = state.copyWith(
        loading: false,
        errorMessage: 'Device not paired yet. Please pair again.',
      );
      return;
    }

    try {
      final remote =
          await ref.read(permissionsRepositoryProvider).getPermissions(childId);
      // Merge the live OS grants on top of the backend config so any of the
      // eight permissions the child has actually granted show as enabled.
      final config = await _withLiveOsState(remote);
      state = state.copyWith(config: config, loading: false, clearError: true);
    } on ApiException catch (e) {
      debugPrint('[PermissionsSettingsViewModel] load failed: ${e.message}');
      state = state.copyWith(
        loading: false,
        errorMessage: e.message.isNotEmpty
            ? e.message
            : 'Failed to load permissions.',
      );
    } catch (e, st) {
      debugPrint('[PermissionsSettingsViewModel] load error: $e\n$st');
      state = state.copyWith(
        loading: false,
        errorMessage: 'Something went wrong. Please try again.',
      );
    }
  }

  /// Replaces the in-memory config (called by each non-OS toggle, e.g.
  /// Calendar and the Main Permissions / Notification flags, via `copyWith`).
  void update(PermissionsRequest config) {
    state = state.copyWith(config: config);
  }

  /// Maps each Data Access toggle to the device permission behind it.
  static const Map<PermissionKey, void> _dataPermissionKeys = {
    PermissionKey.sms: null,
    PermissionKey.contacts: null,
    PermissionKey.phone: null,
    PermissionKey.location: null,
    PermissionKey.usageAccess: null,
    PermissionKey.nearbyWifiDevices: null,
    PermissionKey.calendar: null,
  };

  /// Guards against re-entrant taps while a permission flow is in progress.
  final Set<PermissionKey> _inFlight = {};

  /// Handles a Data Access toggle the same way the setup screen does: turning
  /// it on requests the OS permission, turning it off opens system settings
  /// (the OS has no programmatic revoke). The toggle is then set to whatever
  /// the OS actually grants.
  Future<void> toggleDataPermission(PermissionKey key, bool enable) async {
    if (!_dataPermissionKeys.containsKey(key) || _inFlight.contains(key)) {
      return;
    }
    _inFlight.add(key);
    final service = ref.read(permissionServiceProvider);
    try {
      bool granted;
      if (enable) {
        granted = await service.request(key);
      } else {
        await service.openSettings();
        granted = await service.check(key);
      }
      state = state.copyWith(
        config: _setDataPermission(state.config, key, granted),
      );
    } catch (e, st) {
      debugPrint('[PermissionsSettingsViewModel] toggle($key) failed: $e\n$st');
      state = state.copyWith(
        config: _setDataPermission(state.config, key, await service.check(key)),
      );
    } finally {
      _inFlight.remove(key);
    }
  }

  /// Re-reads the live OS grants and reflects them in the config. Called when
  /// the app resumes, so a permission granted/revoked on the system settings
  /// screen (which returns no callback) updates the Data Access toggles.
  Future<void> refreshOsState() async {
    state = state.copyWith(config: await _withLiveOsState(state.config));
  }

  /// Writes [granted] into the Data Access flag that [key] backs.
  PermissionsRequest _setDataPermission(
      PermissionsRequest config, PermissionKey key, bool granted) {
    final data = config.dataAccess;
    switch (key) {
      case PermissionKey.sms:
        return config.copyWith(dataAccess: data.copyWith(messages: granted));
      case PermissionKey.contacts:
        return config.copyWith(dataAccess: data.copyWith(contacts: granted));
      case PermissionKey.phone:
        return config.copyWith(dataAccess: data.copyWith(callLog: granted));
      case PermissionKey.location:
        return config.copyWith(dataAccess: data.copyWith(location: granted));
      case PermissionKey.usageAccess:
        return config.copyWith(dataAccess: data.copyWith(appUsage: granted));
      case PermissionKey.nearbyWifiDevices:
        return config.copyWith(dataAccess: data.copyWith(networkWifi: granted));
      case PermissionKey.calendar:
        return config.copyWith(dataAccess: data.copyWith(calendar: granted));
      default:
        return config;
    }
  }

  /// Overlays the live OS permission grants onto [config].
  ///
  /// The Data Access toggles mirror the real device permissions, so they are
  /// set directly to the current OS grant — a permission revoked in system
  /// settings turns its toggle back off. `calendar` has no OS permission, so it
  /// is left untouched. The Main Permissions usage / battery flags can only be
  /// turned on by an OS grant, never off.
  Future<PermissionsRequest> _withLiveOsState(PermissionsRequest config) async {
    final service = ref.read(permissionServiceProvider);
    Future<bool> granted(PermissionKey key) => service.check(key);

    final usage = await granted(PermissionKey.usageAccess);
    final battery = await granted(PermissionKey.ignoreBatteryOptimizations);
    final sms = await granted(PermissionKey.sms);
    final contacts = await granted(PermissionKey.contacts);
    final phone = await granted(PermissionKey.phone);
    final location = await granted(PermissionKey.location);
    final networkWifi = await granted(PermissionKey.nearbyWifiDevices);
    final calendar = await granted(PermissionKey.calendar);

    return config.copyWith(
      allowUsageTracking: config.allowUsageTracking || usage,
      batteryOptimizationAllowed: config.batteryOptimizationAllowed || battery,
      dataAccess: config.dataAccess.copyWith(
        messages: sms,
        contacts: contacts,
        callLog: phone,
        location: location,
        appUsage: usage,
        networkWifi: networkWifi,
        calendar: calendar,
      ),
    );
  }

  /// Persists the current config to the backend. Returns `true` on success.
  Future<bool> save() async {
    if (state.saving) return false;

    final childId = await _childId();
    if (childId == null) {
      state = state.copyWith(
        errorMessage: 'Device not paired yet. Please pair again.',
      );
      return false;
    }

    state = state.copyWith(saving: true, clearError: true);
    try {
      final response = await ref
          .read(permissionsRepositoryProvider)
          .updatePermissions(childId, state.config);
      state = state.copyWith(
        saving: false,
        successMessage: response.message,
      );
      return true;
    } on ApiException catch (e) {
      debugPrint('[PermissionsSettingsViewModel] save failed: ${e.message}');
      state = state.copyWith(
        saving: false,
        errorMessage: e.message.isNotEmpty
            ? e.message
            : 'Failed to update permissions.',
      );
      return false;
    } catch (e, st) {
      debugPrint('[PermissionsSettingsViewModel] save error: $e\n$st');
      state = state.copyWith(
        saving: false,
        errorMessage: 'Something went wrong. Please try again.',
      );
      return false;
    }
  }
}

final permissionsSettingsViewModelProvider =
    NotifierProvider<PermissionsSettingsViewModel, PermissionsSettingsState>(
        PermissionsSettingsViewModel.new);
