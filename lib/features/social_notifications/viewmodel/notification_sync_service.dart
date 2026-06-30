import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/identity_storage.dart';
import '../data/notification_sync_storage.dart';
import '../data/repositories/notification_capture_repository.dart';

/// FEATURE A orchestrator — drains the notification queue and ships it.
///
/// Runs silently in the background isolate on its own [_SyncJob] timer (see
/// `background_services.dart`). Like [SmsSyncService] it never throws: a failed
/// pass is logged and retried next tick.
class NotificationSyncService {
  NotificationSyncService(
    this._repository,
    this._identityStorage,
    this._syncStorage,
  );

  final NotificationCaptureRepository _repository;
  final IdentityStorage _identityStorage;
  final NotificationSyncStorage _syncStorage;

  static const String _tag = '[SocialNotif]';

  /// Records per upload request.
  static const int _batchSize = 100;

  /// Upper bound on records shipped in a single pass; the rest are re-queued and
  /// drained next tick, so a large backlog drains gradually instead of in one
  /// huge burst.
  static const int _maxPerPass = 500;

  Future<void> sync() async {
    try {
      final identity = await _identityStorage.read();
      if (!identity.isComplete) {
        debugPrint('$_tag skipped — childId/parentId not set yet.');
        return;
      }

      final all = await _repository.readQueued();
      if (all.isEmpty) {
        await _syncStorage.setLastRunAt(DateTime.now());
        debugPrint('$_tag no new notifications captured.');
        return;
      }

      // Bound the work per pass; overflow goes back on the queue for next tick.
      final toProcess = all.length > _maxPerPass
          ? all.sublist(0, _maxPerPass)
          : all;
      if (all.length > _maxPerPass) {
        await _repository.requeue(all.sublist(_maxPerPass));
      }

      var saved = 0;
      for (var i = 0; i < toProcess.length; i += _batchSize) {
        final batch = toProcess.sublist(
          i,
          math.min(i + _batchSize, toProcess.length),
        );
        try {
          final response = await _repository.store(
            batch,
            childId: identity.childId!,
            parentId: identity.parentId!,
          );
          saved += response.saved ?? batch.length;
        } on ApiException catch (e) {
          // Re-queue this batch and everything after it, then stop this pass.
          final unsent = toProcess.sublist(i);
          await _repository.requeue(unsent);
          debugPrint('$_tag upload failed (${e.message}); '
              're-queued ${unsent.length} for next pass.');
          break;
        }
      }

      await _syncStorage.setLastRunAt(DateTime.now());
      debugPrint('$_tag pass done — processed ${toProcess.length}, '
          'saved $saved'
          '${all.length > _maxPerPass ? ', ${all.length - _maxPerPass} deferred' : ''}.');
    } catch (e, st) {
      debugPrint('$_tag unexpected error: $e\n$st');
    }
  }
}

final notificationSyncServiceProvider =
    Provider<NotificationSyncService>((ref) {
  return NotificationSyncService(
    ref.watch(notificationCaptureRepositoryProvider),
    ref.watch(identityStorageProvider),
    ref.watch(notificationSyncStorageProvider),
  );
});
