import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/identity_storage.dart';
import '../data/models/store_sms_response.dart';
import '../data/repositories/sms_repository.dart';
import '../data/sms_sync_storage.dart';

/// Reads device SMS and uploads them to the backend.
///
/// This is the single piece of orchestration shared by the UI [SmsViewModel]
/// and the background monitoring isolate. It runs *silently* — there is no UI
/// surface for SMS sync — but logs every step with [debugPrint] so the flow
/// can be followed in the console.
class SmsSyncService {
  SmsSyncService(this._repository, this._identityStorage, this._syncStorage);

  final SmsRepository _repository;
  final IdentityStorage _identityStorage;
  final SmsSyncStorage _syncStorage;

  static const String _tag = '[SmsSync]';

  /// Max messages per upload request. Like the contacts / call-log sync, we send
  /// ONE batch per pass so each request is small/fast and a big first sync
  /// drains gradually over successive passes instead of one huge upload.
  static const int _batchSize = 150;

  /// Runs one sync pass. Returns the server response on success, or `null`
  /// when the pass was skipped (missing identity / no messages) or failed.
  /// Never throws — failures are swallowed and logged so a background timer
  /// keeps ticking.
  Future<StoreSmsResponse?> sync() async {
    try {
      final identity = await _identityStorage.read();
      if (!identity.isComplete) {
        debugPrint('$_tag skipped — childId/parentId not set yet.');
        return null;
      }

      final lastSyncedAt = await _syncStorage.getLastSyncedAt();
      final entries = await _repository.readDeviceSms(since: lastSyncedAt);
      if (entries.isEmpty) {
        // Still a successful pass — record the time so the UI shows liveness.
        await _syncStorage.setLastRunAt(DateTime.now());
        debugPrint(
          '$_tag no new SMS since '
          '${lastSyncedAt?.toIso8601String() ?? 'never (first run)'}.',
        );
        return null;
      }

      // Upload only ONE batch (oldest-first) per pass — same approach as the
      // contacts / call-log sync. The recurring loop drains the rest later.
      final batch = entries.length > _batchSize
          ? entries.sublist(0, _batchSize)
          : entries;
      final remaining = entries.length - batch.length;

      final response = await _repository.storeSms(
        batch,
        childId: identity.childId!,
        parentId: identity.parentId!,
      );

      // Advance the watermark to the newest message in THIS batch (batch is
      // oldest-first), so the next pass picks up from where we stopped.
      final newest = batch.last.date;
      await _syncStorage.setLastSyncedAt(newest);
      await _syncStorage.setLastRunAt(DateTime.now());

      debugPrint(
        '$_tag posted ${batch.length} SMS ($remaining remaining) → '
        'saved ${response.saved}, duplicates ${response.duplicates}, '
        'total ${response.total}; watermark → ${newest.toIso8601String()} '
        '("${response.message}")',
      );
      return response;
    } on ApiException catch (e) {
      debugPrint('$_tag upload failed (will resume next pass): ${e.message}');
      return null;
    } catch (e, st) {
      debugPrint('$_tag unexpected error: $e\n$st');
      return null;
    }
  }
}

final smsSyncServiceProvider = Provider<SmsSyncService>((ref) {
  return SmsSyncService(
    ref.watch(smsRepositoryProvider),
    ref.watch(identityStorageProvider),
    ref.watch(smsSyncStorageProvider),
  );
});
