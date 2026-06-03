import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/identity_storage.dart';
import '../data/call_log_sync_storage.dart';
import '../data/models/store_call_logs_response.dart';
import '../data/repositories/call_log_repository.dart';

/// Reads device call logs and uploads them to the backend.
///
/// This is the single piece of orchestration shared by the UI
/// [CallLogViewModel] and the background monitoring isolate. It runs silently
/// but logs every step with [debugPrint] so the flow can be followed in the
/// console.
class CallLogSyncService {
  CallLogSyncService(this._repository, this._identityStorage, this._syncStorage);

  final CallLogRepository _repository;
  final IdentityStorage _identityStorage;
  final CallLogSyncStorage _syncStorage;

  static const String _tag = '[CallLogSync]';

  /// Runs one sync pass. Returns the server response on success, or `null`
  /// when the pass was skipped (missing identity / no calls) or failed.
  /// Never throws — failures are swallowed and logged so a background timer
  /// keeps ticking.
  Future<StoreCallLogsResponse?> sync() async {
    try {
      final identity = await _identityStorage.read();
      if (!identity.isComplete) {
        debugPrint('$_tag skipped — childId/parentId not set yet.');
        return null;
      }

      final lastSyncedAt = await _syncStorage.getLastSyncedAt();
      final logs = await _repository.readDeviceCallLogs(
        childId: identity.childId!,
        parentId: identity.parentId!,
        since: lastSyncedAt,
      );
      if (logs.isEmpty) {
        // Still a successful pass — record the time so the UI shows liveness.
        await _syncStorage.setLastRunAt(DateTime.now());
        debugPrint(
          '$_tag no new calls since '
          '${lastSyncedAt?.toIso8601String() ?? 'never (first run)'}.',
        );
        return null;
      }

      final response = await _repository.storeCallLogs(logs);

      // Advance the watermark to the newest call just uploaded (logs are
      // oldest-first), so the next run only picks up later calls.
      final newest = logs.last.timestamp;
      await _syncStorage.setLastSyncedAt(newest);
      await _syncStorage.setLastRunAt(DateTime.now());

      debugPrint(
        '$_tag posted ${logs.length} calls (newer than '
        '${lastSyncedAt?.toIso8601String() ?? 'first run'}) → '
        'saved ${response.saved}, duplicates ${response.duplicates}, '
        'total ${response.total}; watermark → ${newest.toIso8601String()} '
        '("${response.message}")',
      );
      return response;
    } on ApiException catch (e) {
      debugPrint('$_tag upload failed: ${e.message}');
      return null;
    } catch (e, st) {
      debugPrint('$_tag unexpected error: $e\n$st');
      return null;
    }
  }
}

final callLogSyncServiceProvider = Provider<CallLogSyncService>((ref) {
  return CallLogSyncService(
    ref.watch(callLogRepositoryProvider),
    ref.watch(identityStorageProvider),
    ref.watch(callLogSyncStorageProvider),
  );
});
