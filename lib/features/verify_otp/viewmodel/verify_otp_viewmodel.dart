import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/device/device_info_service.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/device_storage.dart';
import '../../../core/storage/identity_storage.dart';
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
      final response =
          await ref.read(verifyOtpRepositoryProvider).verifyOtpAndPairDevice(
                VerifyOtpRequest(
                  email: trimmedEmail,
                  otp: trimmedOtp,
                  name: trimmedName,
                  age: age,
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
      // the home screen can greet the child by name.
      await ref.read(identityStorageProvider).save(
            childId: response.childId,
            parentId: response.parentId,
            childName: trimmedName,
            childAge: age,
          );

      // Capture this device's name / id and persist them locally, alongside
      // the backend-issued device key needed for the `x-device-key` header.
      final device = await ref.read(deviceInfoServiceProvider).read();
      await ref.read(deviceStorageProvider).save(
            name: device.name,
            id: device.id,
            key: response.deviceKey,
          );

      state = state.copyWith(
        status: VerifyOtpStatus.success,
        response: response,
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

  /// Resets to [VerifyOtpStatus.initial] — useful after showing a snackbar.
  void reset() => state = const VerifyOtpState();
}

final verifyOtpViewModelProvider =
    NotifierProvider<VerifyOtpViewModel, VerifyOtpState>(
        VerifyOtpViewModel.new);
