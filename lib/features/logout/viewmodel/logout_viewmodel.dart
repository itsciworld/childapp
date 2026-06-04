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

      // Clear every stored credential so the splash screen routes back to the
      // onboarding flow on next launch instead of the child home screen.
      await Future.wait([
        ref.read(tokenStorageProvider).clearToken(),
        ref.read(identityStorageProvider).clear(),
        ref.read(deviceStorageProvider).clear(),
      ]);

      // Tear down the background isolate that syncs SMS / call logs / contacts.
      FlutterBackgroundService().invoke('stopService');

      state = state.copyWith(
        status: LogoutStatus.success,
        message: res.message,
        clearError: true,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        status: LogoutStatus.error,
        errorMessage: e.message,
      );
    } catch (e, st) {
      debugPrint('[LogoutViewModel] Unexpected error: $e\n$st');
      state = state.copyWith(
        status: LogoutStatus.error,
        errorMessage: 'Something went wrong. Please try again.',
      );
    }
  }

  /// Resets to [LogoutStatus.initial] — useful after handling a snackbar.
  void reset() => state = const LogoutState();
}

final logoutViewModelProvider =
    NotifierProvider<LogoutViewModel, LogoutState>(LogoutViewModel.new);
