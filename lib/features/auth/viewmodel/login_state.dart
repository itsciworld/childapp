import '../data/models/login_response.dart';

enum LoginStatus {
  initial,
  loading,

  /// Credentials accepted and an OTP was emailed — go to the verify screen.
  success,

  /// This device was already paired to the same account and just signed out:
  /// the previous session was restored, so skip the OTP and open the dashboard.
  sessionRestored,

  error,
}

/// Immutable UI state for the login screen, driven by [LoginViewModel].
class LoginState {
  const LoginState({
    this.status = LoginStatus.initial,
    this.errorMessage,
    this.response,
  });

  final LoginStatus status;
  final String? errorMessage;
  final LoginResponse? response;

  bool get isLoading => status == LoginStatus.loading;

  LoginState copyWith({
    LoginStatus? status,
    String? errorMessage,
    LoginResponse? response,
    bool clearError = false,
  }) {
    return LoginState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      response: response ?? this.response,
    );
  }
}
