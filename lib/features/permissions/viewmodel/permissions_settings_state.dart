import '../data/models/permissions_request.dart';

/// Immutable UI state for the full permissions *settings* screen
/// (the backend-backed page with every toggle), driven by
/// [PermissionsSettingsViewModel].
class PermissionsSettingsState {
  const PermissionsSettingsState({
    this.config = const PermissionsRequest(),
    this.loading = false,
    this.saving = false,
    this.errorMessage,
    this.successMessage,
  });

  /// The current permission configuration shown on screen.
  final PermissionsRequest config;

  /// `true` while the initial load (`GET`) is in flight.
  final bool loading;

  /// `true` while a save (`PUT`) is in flight.
  final bool saving;

  /// Set when a load / save call fails, for surfacing a toast.
  final String? errorMessage;

  /// The server's message from the last successful save (`PUT`), e.g.
  /// "Permissions updated", for surfacing in the success toast.
  final String? successMessage;

  PermissionsSettingsState copyWith({
    PermissionsRequest? config,
    bool? loading,
    bool? saving,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
  }) {
    return PermissionsSettingsState(
      config: config ?? this.config,
      loading: loading ?? this.loading,
      saving: saving ?? this.saving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: successMessage ?? this.successMessage,
    );
  }
}
