enum DeviceUploadStatus { idle, uploading, success, error }

/// Immutable state for the one-shot device-info upload.
class DeviceState {
  const DeviceState({
    this.status = DeviceUploadStatus.idle,
    this.message,
  });

  final DeviceUploadStatus status;

  /// The server `msg` on success, or an error message on failure.
  final String? message;

  bool get isUploading => status == DeviceUploadStatus.uploading;

  DeviceState copyWith({
    DeviceUploadStatus? status,
    String? message,
  }) {
    return DeviceState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }
}
