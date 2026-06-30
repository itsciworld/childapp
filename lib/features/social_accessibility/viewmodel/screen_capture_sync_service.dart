import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/identity_storage.dart';
import '../data/repositories/screen_capture_repository.dart';
import '../data/screen_capture_sync_storage.dart';

/// FEATURE B orchestrator — drains the on-screen-capture queue and ships it.
///
/// Runs silently in the background isolate on its own [_SyncJob] timer (see
/// `background_services.dart`). Never throws: a failed pass is logged and
/// retried next tick.
class ScreenCaptureSyncService {
  ScreenCaptureSyncService(
    this._repository,
    this._identityStorage,
    this._syncStorage,
  );

  final ScreenCaptureRepository _repository;
  final IdentityStorage _identityStorage;
  final ScreenCaptureSyncStorage _syncStorage;

  static const String _tag = '[SocialA11y]';

  /// Records per upload request.
  static const int _batchSize = 100;

  /// Upper bound on records shipped per pass; the rest are re-queued and drained
  /// next tick. Accessibility can produce a lot of lines, so this keeps each
  /// pass bounded.
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
        debugPrint('$_tag no new on-screen text captured.');
        return;
      }

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

final screenCaptureSyncServiceProvider =
    Provider<ScreenCaptureSyncService>((ref) {
  return ScreenCaptureSyncService(
    ref.watch(screenCaptureRepositoryProvider),
    ref.watch(identityStorageProvider),
    ref.watch(screenCaptureSyncStorageProvider),
  );
});
