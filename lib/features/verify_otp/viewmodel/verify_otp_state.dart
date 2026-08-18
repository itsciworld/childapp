import '../data/models/verify_otp_response.dart';

enum VerifyOtpStatus { initial, loading, success, error }

/// Status of the "resend OTP" call, tracked separately from [VerifyOtpStatus]
/// so a resend never disturbs the verify button / navigation.
enum ResendOtpStatus { initial, loading, success, error }

/// Immutable UI state for the verify-OTP screen, driven by [VerifyOtpViewModel].
class VerifyOtpState {
  const VerifyOtpState({
    this.status = VerifyOtpStatus.initial,
    this.errorMessage,
    this.response,
    this.deviceMessage,
    this.resendStatus = ResendOtpStatus.initial,
    this.resendMessage,
  });

  final VerifyOtpStatus status;
  final String? errorMessage;
  final VerifyOtpResponse? response;

  /// Server `msg` from the one-time device-info upload (e.g. "Device info
  /// updated"), shown as a success snackbar. Null when it failed/returned none.
  final String? deviceMessage;

  final ResendOtpStatus resendStatus;

  /// Message for the last resend attempt — the server `msg` on success, the
  /// failure reason on error.
  final String? resendMessage;

  bool get isLoading => status == VerifyOtpStatus.loading;

  bool get isResending => resendStatus == ResendOtpStatus.loading;

  VerifyOtpState copyWith({
    VerifyOtpStatus? status,
    String? errorMessage,
    VerifyOtpResponse? response,
    String? deviceMessage,
    ResendOtpStatus? resendStatus,
    String? resendMessage,
    bool clearError = false,
    bool clearResendMessage = false,
  }) {
    return VerifyOtpState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      response: response ?? this.response,
      deviceMessage: deviceMessage ?? this.deviceMessage,
      resendStatus: resendStatus ?? this.resendStatus,
      resendMessage:
          clearResendMessage ? null : (resendMessage ?? this.resendMessage),
    );
  }
}
