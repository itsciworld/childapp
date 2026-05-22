import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/models/login_request.dart';
import '../data/repositories/auth_repository.dart';
import 'login_state.dart';

/// Holds login-screen logic. The UI calls [login] and reacts to [LoginState];
/// it never touches the repository or network directly.
class LoginViewModel extends Notifier<LoginState> {
  @override
  LoginState build() => const LoginState();

  Future<void> login({required String email, required String password}) async {
    final trimmedEmail = email.trim();
    final trimmedPassword = password.trim();

    if (trimmedEmail.isEmpty || trimmedPassword.isEmpty) {
      state = state.copyWith(
        status: LoginStatus.error,
        errorMessage: 'Please enter both email and password.',
      );
      return;
    }

    state = state.copyWith(status: LoginStatus.loading, clearError: true);

    try {
      final response = await ref.read(authRepositoryProvider).login(
            LoginRequest(email: trimmedEmail, password: trimmedPassword),
          );
      state = state.copyWith(
        status: LoginStatus.success,
        response: response,
        clearError: true,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        status: LoginStatus.error,
        errorMessage: e.message,
      );
    } catch (e, st) {
      debugPrint('[LoginViewModel] Unexpected error: $e\n$st');
      state = state.copyWith(
        status: LoginStatus.error,
        errorMessage: 'Something went wrong. Please try again.',
      );
    }
  }

  /// Resets to [LoginStatus.initial] — useful after showing an error snackbar.
  void reset() => state = const LoginState();
}

final loginViewModelProvider =
    NotifierProvider<LoginViewModel, LoginState>(LoginViewModel.new);
