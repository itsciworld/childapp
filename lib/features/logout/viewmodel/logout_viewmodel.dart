import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/device_storage.dart';
import '../../../core/storage/identity_storage.dart';
import '../../../core/storage/token_storage.dart';
import '../data/repositories/logout_repository.dart';
import 'logout_state.dart';

/// Handles logging the device out. The UI calls [logout] and reacts to
/// [LogoutState]; it never touches the repository or storages directly.
class LogoutViewModel extends Notifier<LogoutState> {
  @override
  LogoutState build() => const LogoutState();

  /// Calls the logout endpoint and, on success, wipes the local session
  /// (token + child/parent identity + device key) and stops the background
  /// monitoring service so no further uploads run for the unpaired device.
  Future<void> logout() async {
    state = state.copyWith(status: LogoutStatus.loading, clearError: true);

    try {
      final res = await ref.read(logoutRepositoryProvider).logout();

      // Whether logout "succeeded" or the device was unpaired, we always wipe
      // the local session so the next launch routes back to onboarding.
      await _clearAllData();

      // Some backends return HTTP 200 with an unpaired payload in the body
      // (status: 401 / "device unpaired"), so check the parsed response too.
      if (_isUnpaired(res.message, res.status)) {
        state = state.copyWith(
          status: LogoutStatus.deviceUnpaired,
          errorMessage: (res.message?.isNotEmpty ?? false)
              ? res.message
              : 'Device unpaired. This child profile was removed.',
        );
      } else {
        state = state.copyWith(
          status: LogoutStatus.success,
          message: res.message,
          clearError: true,
        );
      }
    } on ApiException catch (e) {
      // The unpaired signal can also arrive as a real HTTP 401 error.
      if (_isUnpaired(e.message, e.statusCode)) {
        // Clear all data even on unpaired error.
        await _clearAllData();

        state = state.copyWith(
          status: LogoutStatus.deviceUnpaired,
          errorMessage: e.message.isNotEmpty
              ? e.message
              : 'Device unpaired. This child profile was removed.',
        );
      } else {
        state = state.copyWith(
          status: LogoutStatus.error,
          errorMessage: e.message.isNotEmpty
              ? e.message
              : 'Failed to logout. Please try again.',
        );
      }
    } catch (e, st) {
      debugPrint('[LogoutViewModel] Unexpected error: $e\n$st');
      state = state.copyWith(
        status: LogoutStatus.error,
        errorMessage: 'Something went wrong. Please try again.',
      );
    }
  }

  /// True when the server is telling us this device was unpaired / the child
  /// profile was removed — signalled either by a 401 [status] or by the message
  /// text. Used to route the child to the login screen instead of onboarding.
  bool _isUnpaired(String? message, int? status) {
    final msg = (message ?? '').toLowerCase();
    return status == 401 ||
        msg.contains('device unpaired') ||
        msg.contains('profile was removed');
  }

  /// Clears all stored data and stops background service
  Future<void> _clearAllData() async {
    await Future.wait([
      ref.read(tokenStorageProvider).clearToken(),
      ref.read(identityStorageProvider).clear(),
      ref.read(deviceStorageProvider).clear(),
    ]);

    // Tear down the background isolate that syncs SMS / call logs / contacts.
    FlutterBackgroundService().invoke('stopService');
  }

  /// Resets to [LogoutStatus.initial] — useful after handling a snackbar.
  void reset() => state = const LogoutState();
}

final logoutViewModelProvider =
    NotifierProvider<LogoutViewModel, LogoutState>(LogoutViewModel.new);
