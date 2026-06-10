import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/identity_storage.dart';
import '../data/live_status_sync_storage.dart';
import '../data/models/live_status_response.dart';
import '../data/repositories/live_status_repository.dart';

/// Reads the device's live battery + connectivity snapshot and pushes it to the
/// backend.
///
/// This is the single piece of orchestration shared by the UI
/// [LiveStatusViewModel] and the background monitoring isolate. It runs silently
/// but logs every step with [debugPrint] so the flow can be followed in the
/// console. Unlike SMS / call logs there is no batching or watermark — each pass
/// sends the *current* state.
class LiveStatusSyncService {
  LiveStatusSyncService(
      this._repository, this._identityStorage, this._syncStorage);

  final LiveStatusRepository _repository;
  final IdentityStorage _identityStorage;
  final LiveStatusSyncStorage _syncStorage;

  static const String _tag = '[LiveStatusSync]';

  /// Runs one push. Returns the server response on success, or `null` when the
  /// pass was skipped (missing identity) or failed. Never throws — failures are
  /// swallowed and logged so a background timer keeps ticking.
  Future<LiveStatusResponse?> sync() async {
    try {
      final identity = await _identityStorage.read();
      if (!identity.isComplete) {
        debugPrint('$_tag skipped — childId/parentId not set yet.');
        return null;
      }

      final request = await _repository.readDeviceStatus();
      final response = await _repository.pushLiveStatus(
        childId: identity.childId!,
        request: request,
      );

      await _syncStorage.setLastRunAt(DateTime.now());

      debugPrint(
        '$_tag pushed → online=${request.isOnline}, '
        'battery=${request.batteryInfo.level}% '
        '(${request.batteryInfo.state}), '
        'conn=${request.connectivity.connectionType} '
        '("${response.message ?? response.status}")',
      );
      return response;
    } on ApiException catch (e) {
      debugPrint('$_tag push failed (will resume next pass): ${e.message}');
      return null;
    } catch (e, st) {
      debugPrint('$_tag unexpected error: $e\n$st');
      return null;
    }
  }
}

final liveStatusSyncServiceProvider = Provider<LiveStatusSyncService>((ref) {
  return LiveStatusSyncService(
    ref.watch(liveStatusRepositoryProvider),
    ref.watch(identityStorageProvider),
    ref.watch(liveStatusSyncStorageProvider),
  );
});
