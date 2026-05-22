import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/models/pairing_request.dart';
import '../data/repositories/pairing_repository.dart';
import 'pairing_state.dart';

/// Holds pairing-screen logic. The UI calls [verify] and reacts to
/// [PairingState]; it never touches the repository or network directly.
class PairingViewModel extends Notifier<PairingState> {
  @override
  PairingState build() => const PairingState();

  Future<void> verify({required String email, required String code}) async {
    final trimmedEmail = email.trim();
    final trimmedCode = code.trim();

    if (trimmedCode.isEmpty) {
      state = state.copyWith(
        status: PairingStatus.error,
        errorMessage: 'Please enter the pairing code.',
      );
      return;
    }

    state = state.copyWith(status: PairingStatus.loading, clearError: true);

    try {
      final response = await ref.read(pairingRepositoryProvider).verifyPairingCode(
            PairingRequest(email: trimmedEmail, code: trimmedCode),
          );
      state = state.copyWith(
        status: PairingStatus.success,
        response: response,
        clearError: true,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        status: PairingStatus.error,
        errorMessage: e.message,
      );
    } catch (e, st) {
      debugPrint('[PairingViewModel] Unexpected error: $e\n$st');
      state = state.copyWith(
        status: PairingStatus.error,
        errorMessage: 'Something went wrong. Please try again.',
      );
    }
  }

  /// Resets to [PairingStatus.initial] — useful after showing a snackbar.
  void reset() => state = const PairingState();
}

final pairingViewModelProvider =
    NotifierProvider<PairingViewModel, PairingState>(PairingViewModel.new);
