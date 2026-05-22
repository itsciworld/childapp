import '../data/models/verify_otp_response.dart';

enum VerifyOtpStatus { initial, loading, success, error }

/// Immutable UI state for the verify-OTP screen, driven by [VerifyOtpViewModel].
class VerifyOtpState {
  const VerifyOtpState({
    this.status = VerifyOtpStatus.initial,
    this.errorMessage,
    this.response,
  });

  final VerifyOtpStatus status;
  final String? errorMessage;
  final VerifyOtpResponse? response;

  bool get isLoading => status == VerifyOtpStatus.loading;

  VerifyOtpState copyWith({
    VerifyOtpStatus? status,
    String? errorMessage,
    VerifyOtpResponse? response,
    bool clearError = false,
  }) {
    return VerifyOtpState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      response: response ?? this.response,
    );
  }
}
