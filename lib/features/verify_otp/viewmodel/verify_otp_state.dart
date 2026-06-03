import '../data/models/verify_otp_response.dart';

enum VerifyOtpStatus { initial, loading, success, error }

/// Immutable UI state for the verify-OTP screen, driven by [VerifyOtpViewModel].
class VerifyOtpState {
  const VerifyOtpState({
    this.status = VerifyOtpStatus.initial,
    this.errorMessage,
    this.response,
    this.deviceMessage,
  });

  final VerifyOtpStatus status;
  final String? errorMessage;
  final VerifyOtpResponse? response;

  /// Server `msg` from the one-time device-info upload (e.g. "Device info
  /// updated"), shown as a success snackbar. Null when it failed/returned none.
  final String? deviceMessage;

  bool get isLoading => status == VerifyOtpStatus.loading;

  VerifyOtpState copyWith({
    VerifyOtpStatus? status,
    String? errorMessage,
    VerifyOtpResponse? response,
    String? deviceMessage,
    bool clearError = false,
  }) {
    return VerifyOtpState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      response: response ?? this.response,
      deviceMessage: deviceMessage ?? this.deviceMessage,
    );
  }
}
