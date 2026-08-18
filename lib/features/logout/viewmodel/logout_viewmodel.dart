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

  /// Calls the logout endpoint and stops the background monitoring service so
  /// no further uploads run.
  ///
  /// A normal logout is a *soft* sign-out — see [_signOut]: the access token is
  /// dropped but the refresh token and the pairing survive, so signing back in
  /// skips the OTP flow. Only an unpaired device gets the full wipe.
  Future<void> logout() async {
    state = state.copyWith(status: LogoutStatus.loading, clearError: true);

    try {
      final res = await ref.read(logoutRepositoryProvider).logout();

      // Some backends return HTTP 200 with an unpaired payload in the body
      // (status: 401 / "device unpaired"), so check the parsed response too.
      if (_isUnpaired(res.message, res.status)) {
        // The pairing itself is gone — wipe everything, including the refresh
        // token, so the next sign-in has to go through the OTP flow.
        await _clearAllData();
        state = state.copyWith(
          status: LogoutStatus.deviceUnpaired,
          errorMessage: (res.message?.isNotEmpty ?? false)
              ? res.message
              : 'Device unpaired. This child profile was removed.',
        );
      } else {
        // A normal logout: the device stays paired, so the refresh token and
        // the child/parent identity are kept and signing back in restores the
        // session without another OTP.
        await _signOut();

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

  /// Signs the child out while keeping the device paired.
  ///
  /// Only the access token goes; the refresh token, the child/parent identity
  /// and the device key stay so the next sign-in can restore the session
  /// silently. The signed-out flag stops the splash from doing that on its own
  /// — the child must sign in again first.
  Future<void> _signOut() async {
    final tokenStorage = ref.read(tokenStorageProvider);
    await tokenStorage.clearAccessToken();
    await tokenStorage.setSignedOut(true);

    // Tear down the background isolate that syncs SMS / call logs / contacts.
    FlutterBackgroundService().invoke('stopService');
  }

  /// Clears all stored data and stops background service — used when the device
  /// is unpaired, where nothing is left to restore.
  Future<void> _clearAllData() async {
    await Future.wait([
      ref.read(tokenStorageProvider).clearTokens(),
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
