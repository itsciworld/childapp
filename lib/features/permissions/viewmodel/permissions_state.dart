/// The set of runtime / special-access permissions the app can request.
///
/// Each value maps to one toggle on the permissions screen and to a concrete
/// platform permission resolved by [PermissionService].
enum PermissionKey {
  location,
  contacts,
  sms,
  phone,
  photos,
  notification,
  usageAccess,
  ignoreBatteryOptimizations,
}

/// Immutable UI state for the permissions screen, driven by
/// [PermissionsViewModel].
class PermissionsState {
  const PermissionsState({
    this.granted = const {},
    this.busy,
    this.loading = false,
    this.submitting = false,
    this.errorMessage,
  });

  /// `true` for every permission currently granted by the OS.
  final Map<PermissionKey, bool> granted;

  /// The permission that is currently being requested, if any. Used to show
  /// a spinner on a single tile without blocking the others.
  final PermissionKey? busy;

  /// `true` while the initial bulk-status check is in flight.
  final bool loading;

  /// `true` while the Continue button's permissions-update API call is in
  /// flight.
  final bool submitting;

  /// Set when the permissions-update call fails, for surfacing a snackbar.
  final String? errorMessage;

  bool isGranted(PermissionKey key) => granted[key] ?? false;
  bool isBusy(PermissionKey key) => busy == key;

  PermissionsState copyWith({
    Map<PermissionKey, bool>? granted,
    PermissionKey? busy,
    bool clearBusy = false,
    bool? loading,
    bool? submitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PermissionsState(
      granted: granted ?? this.granted,
      busy: clearBusy ? null : (busy ?? this.busy),
      loading: loading ?? this.loading,
      submitting: submitting ?? this.submitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
