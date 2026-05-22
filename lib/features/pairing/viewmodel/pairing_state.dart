import '../data/models/pairing_response.dart';

enum PairingStatus { initial, loading, success, error }

/// Immutable UI state for the pairing screen, driven by [PairingViewModel].
class PairingState {
  const PairingState({
    this.status = PairingStatus.initial,
    this.errorMessage,
    this.response,
  });

  final PairingStatus status;
  final String? errorMessage;
  final PairingResponse? response;

  bool get isLoading => status == PairingStatus.loading;

  PairingState copyWith({
    PairingStatus? status,
    String? errorMessage,
    PairingResponse? response,
    bool clearError = false,
  }) {
    return PairingState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      response: response ?? this.response,
    );
  }
}
