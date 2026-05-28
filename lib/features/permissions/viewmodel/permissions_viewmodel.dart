import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/permission_service.dart';
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
}

final permissionsViewModelProvider =
    NotifierProvider<PermissionsViewModel, PermissionsState>(
        PermissionsViewModel.new);
