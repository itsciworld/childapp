import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/identity_storage.dart';
import '../data/models/sms_entry.dart';
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

  /// Max messages per upload request, so each POST stays small and fast.
  ///
  /// This was 150, and `POST /api/sms/store_sms` could not process that many
  /// within the 35s receive timeout — every pass sent the same 150 messages,
  /// waited, and died on `receiveTimeout`, while the small POSTs from live
  /// status and location returned 200 instantly on the very same connection.
  /// Because the watermark only advances after a *successful* upload, the SMS
  /// stream was wedged permanently at the timestamp of the first oversized
  /// batch — which is why "Last sync" froze at one time of day while every
  /// other tile kept ticking.
  static const int _batchSize = 45;

  /// How many batches a single pass may upload before yielding to the timer.
  ///
  /// The upload is strictly OLDEST-FIRST — it has to be, because the watermark
  /// is "newest message already sent", so today's messages are always the LAST
  /// thing to go out. Uploading one batch per pass meant a backlog (the first
  /// sync after pairing, or the gap left behind whenever the service was
  /// killed) needed one 10s tick per 150 messages, and anything that
  /// interrupted that slow drain — a restart, a dead network, the foreground
  /// service being killed — left the newest messages permanently unsent while
  /// the server happily filled up with old ones. That is the "it uploads
  /// yesterday's messages but not today's" symptom.
  ///
  /// 20 × 25 = 500 messages per pass, so a backlog clears in a couple of passes
  /// instead of one 10s tick per batch, and today's messages arrive with it.
  static const int _maxBatchesPerPass = 20;

  /// Consecutive failed uploads before we start halving the batch.
  static const int _failuresBeforeShrink = 1;

  /// Consecutive rejections before we step over the single message the server
  /// will not accept. Only ever reached for an outright rejection — a timeout
  /// or a dead network never discards a message.
  static const int _failuresBeforeSkip = 10;

  /// Batch size to use given the current failure streak.
  ///
  /// The upload is a strict queue: every pass re-reads from the same watermark,
  /// so if the server refuses a batch, the very same batch is rebuilt and
  /// refused again on the next tick — forever. That is a deadlock, and it is
  /// why "Last sync" freezes at one time of day while every other stream keeps
  /// ticking: the SMS pass is running fine, it just never reaches the code that
  /// advances the watermark. Halving isolates the offending message (an
  /// oversized batch, one body the server's column can't store, a malformed
  /// address); [_failuresBeforeSkip] then lets the queue step over it.
  static int _effectiveBatchSize(int failures) {
    if (failures < _failuresBeforeShrink) return _batchSize;
    final shift = failures - _failuresBeforeShrink + 1;
    if (shift >= 31) return 1;
    final shrunk = _batchSize >> shift;
    return shrunk < 1 ? 1 : shrunk;
  }

  /// Runs one sync pass, draining up to [_maxBatchesPerPass] batches. Returns
  /// the last server response, or `null` when the pass uploaded nothing
  /// (missing identity / no permission / no new messages) or failed.
  /// Never throws — failures are swallowed and logged so a background timer
  /// keeps ticking.
  Future<StoreSmsResponse?> sync() async {
    try {
      final identity = await _identityStorage.read();
      if (!identity.isComplete) {
        debugPrint('$_tag skipped — childId/parentId not set yet.');
        return null;
      }

      // Checked separately from the read below: a denied permission also yields
      // an empty list, and treating that as "nothing new" made the pass record
      // liveness and the home tile report a healthy sync while no message was
      // ever collected. Return without touching the timestamps so the tile
      // keeps showing the permission state instead.
      if (!await _repository.hasSmsPermission()) {
        debugPrint('$_tag skipped — READ_SMS not granted.');
        return null;
      }

      final failures = await _syncStorage.getFailureStreak();
      final batchSize = _effectiveBatchSize(failures);
      if (failures > 0) {
        debugPrint('$_tag recovering — $failures consecutive rejection(s), '
            'batch size now $batchSize.');
      }

      StoreSmsResponse? lastResponse;

      for (var pass = 0; pass < _maxBatchesPerPass; pass++) {
        final lastSyncedAt = await _syncStorage.getLastSyncedAt();
        final alreadySent = await _syncStorage.getLastSyncedIds();
        final entries = (await _repository.readDeviceSms(since: lastSyncedAt))
            .where((e) =>
                lastSyncedAt == null ||
                !e.date.isAtSameMomentAs(lastSyncedAt) ||
                !alreadySent.contains('${e.id}'))
            .toList();
        if (entries.isEmpty) {
          if (pass == 0) {
            debugPrint(
              '$_tag no new SMS since '
              '${lastSyncedAt?.toIso8601String() ?? 'never (first run)'}.',
            );
          }
          break;
        }

        final batch = entries.length > batchSize
            ? entries.sublist(0, batchSize)
            : entries;
        final remaining = entries.length - batch.length;

        final StoreSmsResponse response;
        try {
          response = await _repository.storeSms(
            batch,
            childId: identity.childId!,
            parentId: identity.parentId!,
          );
        } on ApiException catch (e) {
          // Handled here, where the offending batch is still in scope, so the
          // recovery can shrink it or step over it.
          await _handleUploadFailure(e, batch, failures);
          return null;
        }
        lastResponse = response;

        // Advance the watermark to the newest message in THIS batch (batch is
        // oldest-first), so the next iteration picks up from where we stopped.
        final newest = batch.last.date;
        await _syncStorage.setLastSyncedAt(newest);
        // Remember which ids we just sent AT that instant, so the inclusive
        // read on the next pass re-offers the boundary without re-uploading it.
        await _syncStorage.setLastSyncedIds(
          batch
              .where((e) => e.date.isAtSameMomentAs(newest))
              .map((e) => '${e.id}')
              .toList(),
        );

        debugPrint(
          '$_tag posted ${batch.length} SMS ($remaining remaining) → '
          'saved ${response.saved}, duplicates ${response.duplicates}, '
          'total ${response.total}; watermark → ${newest.toIso8601String()} '
          '("${response.message}")',
        );

        // Caught up. The watermark filter is inclusive, so the next read would
        // just re-offer this batch's newest message as a duplicate.
        if (remaining == 0) break;
      }

      // A pass that completed without throwing is a healthy pass, whether or
      // not it had anything to upload.
      await _syncStorage.setLastRunAt(DateTime.now());
      await _syncStorage.setLastError(null);
      await _syncStorage.setFailureStreak(0);
      return lastResponse;
    } on ApiException catch (e) {
      debugPrint('$_tag upload failed (will resume next pass): ${e.message}');
      await _recordFailure(e.message);
      return null;
    } catch (e, st) {
      debugPrint('$_tag unexpected error: $e\n$st');
      await _recordFailure('$e');
      return null;
    }
  }

  /// Decides what a failed upload means for the next attempt.
  ///
  /// - **offline** — nothing reached the server, so the batch is not the
  ///   problem. Leave the streak alone and wait for connectivity; shrinking or
  ///   discarding here would throw away messages over a tunnel.
  /// - **timeout** — the request went out and the server could not finish it in
  ///   time. That is the too-big-a-batch signal, so shrink. Never skip: the
  ///   messages are perfectly valid, the batch is just more than this endpoint
  ///   can chew.
  /// - **rejected (4xx)** — the server understood and refused. Shrink to
  ///   isolate the offender, then step over it once it is alone, so one
  ///   un-storable message cannot block every message behind it forever.
  /// - **5xx** — shrink (a large payload often surfaces as a 500) but never
  ///   discard; the fault is on the server side.
  Future<void> _handleUploadFailure(
    ApiException e,
    List<SmsEntry> batch,
    int previousFailures,
  ) async {
    await _recordFailure(e.message);

    if (e.kind == ApiErrorKind.offline) {
      debugPrint(
          '$_tag offline — keeping batch of ${batch.length} for next pass.');
      return;
    }

    final failures = previousFailures + 1;
    await _syncStorage.setFailureStreak(failures);
    debugPrint(
      '$_tag upload of ${batch.length} SMS failed '
      '(${e.kind.name}${e.statusCode == null ? '' : ' ${e.statusCode}'}), '
      'streak $failures → next batch ${_effectiveBatchSize(failures)}: '
      '${e.message}',
    );

    final rejected = e.kind == ApiErrorKind.badResponse &&
        e.statusCode != null &&
        e.statusCode! >= 400 &&
        e.statusCode! < 500;
    if (rejected && batch.length == 1 && failures >= _failuresBeforeSkip) {
      final poison = batch.first;
      // The watermark filter is inclusive, so land just past this message to
      // actually clear it.
      await _syncStorage
          .setLastSyncedAt(poison.date.add(const Duration(milliseconds: 1)));
      await _syncStorage.setLastSyncedIds(const []);
      await _syncStorage.setFailureStreak(0);
      debugPrint(
        '$_tag ⚠️ server keeps rejecting SMS id=${poison.id} at '
        '${poison.date.toIso8601String()} — skipping it so the queue can move on.',
      );
    }
  }

  /// Records that a pass ran and failed.
  ///
  /// Both timestamps matter: without [SmsSyncStorage.setLastRunAt] the home
  /// tile had no last-run time to read and sat on "Starting… / Waiting for
  /// first sync" indefinitely — for as long as uploads kept failing, which is
  /// exactly when the user most needs to be told something is wrong. The error
  /// string is what turns that into "Retrying" rather than a false "Active".
  Future<void> _recordFailure(String message) async {
    try {
      await _syncStorage.setLastRunAt(DateTime.now());
      await _syncStorage.setLastError(message);
    } catch (e) {
      debugPrint('$_tag could not record failure state: $e');
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
