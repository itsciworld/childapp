import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/repositories/device_repository.dart';
import 'device_state.dart';

/// Drives the once-per-app-start device-info upload.
///
/// Call [upload] when the home screen opens; it gathers the device details and
/// posts them to the backend. The returned server `msg` (e.g. "Device info
/// updated") is exposed via state so the UI can show it as a toast.
class DeviceViewModel extends Notifier<DeviceState> {
  bool _uploaded = false;

  @override
  DeviceState build() => const DeviceState();

  /// Uploads the device info and returns the server message to toast, or `null`
  /// if nothing should be shown (already done this session, or on failure).
  Future<String?> upload() async {
    // Guard against duplicate uploads if the home screen rebuilds — this is a
    // once-per-app-start action.
    if (_uploaded || state.isUploading) return null;
    _uploaded = true;

    state = state.copyWith(status: DeviceUploadStatus.uploading);
    try {
      final response = await ref.read(deviceRepositoryProvider).uploadDeviceInfo();
      state = state.copyWith(
        status: DeviceUploadStatus.success,
        message: response.message,
      );
      return response.message;
    } on ApiException catch (e) {
      // Allow a retry on the next open if it failed.
      _uploaded = false;
      state = state.copyWith(
        status: DeviceUploadStatus.error,
        message: e.message,
      );
      return null;
    }
  }
}

final deviceViewModelProvider =
    NotifierProvider<DeviceViewModel, DeviceState>(DeviceViewModel.new);
