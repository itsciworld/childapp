enum LogoutStatus { initial, loading, success, error, deviceUnpaired }

/// Immutable UI state for the logout action, driven by [LogoutViewModel].
class LogoutState {
  const LogoutState({
    this.status = LogoutStatus.initial,
    this.message,
    this.errorMessage,
  });

  final LogoutStatus status;

  /// Server `msg` on success — shown in a snackbar.
  final String? message;
  final String? errorMessage;

  bool get isLoading => status == LogoutStatus.loading;

  LogoutState copyWith({
    LogoutStatus? status,
    String? message,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LogoutState(
      status: status ?? this.status,
      message: message ?? this.message,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
