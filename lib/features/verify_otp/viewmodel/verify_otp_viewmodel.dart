import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/device/device_info_service.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/device_storage.dart';
import '../../../core/storage/identity_storage.dart';
import '../../../core/storage/token_storage.dart';
import '../../auth/data/models/login_request.dart';
import '../../auth/data/repositories/auth_repository.dart';
import '../../device/data/repositories/device_repository.dart';
import '../data/models/verify_otp_request.dart';
import '../data/repositories/verify_otp_repository.dart';
import 'verify_otp_state.dart';

/// Holds verify-OTP screen logic. The UI calls [verify] and reacts to
/// [VerifyOtpState]; it never touches the repository or network directly.
class VerifyOtpViewModel extends Notifier<VerifyOtpState> {
  @override
  VerifyOtpState build() => const VerifyOtpState();

  Future<void> verify({
    required String email,
    required String otp,
    required String name,
    required String ageText,
  }) async {
    final trimmedEmail = email.trim();
    final trimmedOtp = otp.trim();
    final trimmedName = name.trim();
    final age = int.tryParse(ageText.trim());

    if (trimmedOtp.isEmpty || trimmedName.isEmpty || age == null || age <= 0) {
      state = state.copyWith(
        status: VerifyOtpStatus.error,
        errorMessage: 'Please enter the OTP, child name and a valid age.',
      );
      return;
    }

    state = state.copyWith(status: VerifyOtpStatus.loading, clearError: true);

    try {
      // Read this phone's info up front so its id goes into the pairing request
      // body; the same [device] is reused below to persist name/id locally.
      final device = await ref.read(deviceInfoServiceProvider).read();
      debugPrint('[VerifyOtpViewModel] pairing with deviceId="${device.id}" '
          '(name="${device.name}")');

      final response =
          await ref.read(verifyOtpRepositoryProvider).verifyOtpAndPairDevice(
                VerifyOtpRequest(
                  email: trimmedEmail,
                  otp: trimmedOtp,
                  name: trimmedName,
                  age: age,
                  deviceId: device.id,
                ),
              );

      if (response.childId == null || response.childId!.isEmpty) {
        state = state.copyWith(
          status: VerifyOtpStatus.error,
          errorMessage: 'Pairing succeeded but no child id was returned.',
        );
        return;
      }

      // Persist the identity so the background SMS sync can read it later, and
      // the home screen can greet the child by name. The parent email is kept
      // too: a later sign-in on this device is matched against it before the
      // session is restored without an OTP.
      await ref.read(identityStorageProvider).save(
            childId: response.childId,
            parentId: response.parentId,
            childName: trimmedName,
            childAge: age,
            parentEmail: trimmedEmail,
          );

      // A fresh pairing supersedes any earlier logout.
      await ref.read(tokenStorageProvider).setSignedOut(false);

      // Persist this device's name / id (already read above) locally, alongside
      // the backend-issued device key needed for the `x-device-key` header.
      await ref.read(deviceStorageProvider).save(
            name: device.name,
            id: device.id,
            key: response.deviceKey,
          );

      // Upload the full device info to the backend ONCE, now that pairing
      // succeeded (childId + auth token are stored). This is the only place it's
      // sent — it must not run on every app restart. A failure here must not
      // fail an otherwise-successful pairing, so [_uploadDeviceInfo] swallows
      // errors and returns null; the message (when present) drives the success
      // snackbar on the verify screen.
      final deviceMessage = await _uploadDeviceInfo();

      state = state.copyWith(
        status: VerifyOtpStatus.success,
        response: response,
        deviceMessage: deviceMessage,
        clearError: true,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        status: VerifyOtpStatus.error,
        errorMessage: e.message,
      );
    } catch (e, st) {
      debugPrint('[VerifyOtpViewModel] Unexpected error: $e\n$st');
      state = state.copyWith(
        status: VerifyOtpStatus.error,
        errorMessage: 'Something went wrong. Please try again.',
      );
    }
  }

  /// Re-triggers the OTP email by replaying the login call
  /// (`POST /api/children/login-and-send-otp`) with the same credentials the
  /// parent entered on the login screen — no new endpoint is involved.
  ///
  /// Tracked via [VerifyOtpState.resendStatus] so it never interferes with the
  /// verify request or its navigation.
  Future<void> resendOtp({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();

    if (trimmedEmail.isEmpty || password.isEmpty) {
      state = state.copyWith(
        resendStatus: ResendOtpStatus.error,
        resendMessage: 'Please sign in again to resend the OTP.',
      );
      return;
    }

    state = state.copyWith(
      resendStatus: ResendOtpStatus.loading,
      clearResendMessage: true,
    );

    try {
      final response = await ref.read(authRepositoryProvider).login(
            LoginRequest(email: trimmedEmail, password: password),
          );
      state = state.copyWith(
        resendStatus: ResendOtpStatus.success,
        resendMessage: response.message?.isNotEmpty == true
            ? response.message
            : 'A new OTP has been sent to $trimmedEmail.',
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        resendStatus: ResendOtpStatus.error,
        resendMessage: e.message,
      );
    } catch (e, st) {
      debugPrint('[VerifyOtpViewModel] Unexpected resend error: $e\n$st');
      state = state.copyWith(
        resendStatus: ResendOtpStatus.error,
        resendMessage: 'Could not resend the OTP. Please try again.',
      );
    }
  }

  /// Clears the resend result after the UI has shown its toast, so the same
  /// message is not re-emitted on the next state change.
  void resetResend() => state = state.copyWith(
        resendStatus: ResendOtpStatus.initial,
        clearResendMessage: true,
      );

  /// Uploads this device's info to the backend a single time, at pairing, and
  /// returns the server `msg` on success (for the success snackbar). Errors are
  /// swallowed (logged only, returns null) so they never block pairing success.
  Future<String?> _uploadDeviceInfo() async {
    try {
      final res = await ref.read(deviceRepositoryProvider).uploadDeviceInfo();
      debugPrint('[VerifyOtpViewModel] device-info uploaded: ${res.message}');
      return res.message;
    } catch (e) {
      debugPrint('[VerifyOtpViewModel] device-info upload failed: $e');
      return null;
    }
  }

  /// Resets to [VerifyOtpStatus.initial] — useful after showing a snackbar.
  void reset() => state = const VerifyOtpState();
}

final verifyOtpViewModelProvider =
    NotifierProvider<VerifyOtpViewModel, VerifyOtpState>(
        VerifyOtpViewModel.new);
