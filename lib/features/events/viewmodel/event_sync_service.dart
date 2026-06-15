import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/identity_storage.dart';
import '../data/event_sync_storage.dart';
import '../data/models/store_events_response.dart';
import '../data/repositories/event_repository.dart';

/// Reads device calendar events and uploads any new ones to the backend.
///
/// Shared by the UI [EventViewModel] and the background isolate. Runs silently
/// but logs every step with [debugPrint]. Crucially, when there are no new
/// events it does NOT call the API — it just records liveness and returns.
class EventSyncService {
  EventSyncService(this._repository, this._identityStorage, this._syncStorage);

  final EventRepository _repository;
  final IdentityStorage _identityStorage;
  final EventSyncStorage _syncStorage;

  static const String _tag = '[EventSync]';

  /// Events per upload request. Kept small so each POST is light and answers
  /// well within the network timeout — a big first sync drains as several quick
  /// chunks instead of one heavy request that stalls and times out.
  static const int _batchSize = 20;

  /// Runs one sync pass. Reads the device's new (not-yet-uploaded) events and,
  /// if there are any, uploads them in [_batchSize] chunks — marking each chunk
  /// as synced the instant it lands, so a failure part-way through never
  /// re-sends what already arrived. Returns the last server response, or `null`
  /// when the pass was skipped (no identity / no new events) or the first chunk
  /// failed.
  Future<StoreEventsResponse?> sync() async {
    try {
      final identity = await _identityStorage.read();
      if (!identity.isComplete) {
        debugPrint('$_tag skipped — childId/parentId not set yet.');
        return null;
      }

      final synced = await _syncStorage.getSyncedKeys();
      final events = await _repository.readDeviceEvents(alreadySynced: synced);
      if (events.isEmpty) {
        // Nothing new → record liveness, DON'T call the API.
        await _syncStorage.setLastRunAt(DateTime.now());
        debugPrint('$_tag no new events (${synced.length} already synced).');
        return null;
      }

      StoreEventsResponse? lastResponse;
      var uploaded = 0;
      for (var i = 0; i < events.length; i += _batchSize) {
        final end =
            (i + _batchSize < events.length) ? i + _batchSize : events.length;
        final chunk = events.sublist(i, end);

        try {
          lastResponse = await _repository.storeEvents(
            chunk,
            childId: identity.childId!,
            parentId: identity.parentId!,
          );
        } on ApiException catch (e) {
          // Stop here; the unsent events keep their ids unmarked and resume on
          // the next pass. Already-sent chunks above stay marked → no re-send.
          debugPrint('$_tag chunk failed after $uploaded/${events.length} '
              '(resume next pass): ${e.message}');
          await _syncStorage.setLastRunAt(DateTime.now());
          return lastResponse;
        }

        // Mark this chunk's ids as synced the moment it succeeds, so they are
        // never sent again — even if a later chunk fails.
        await _syncStorage.addSyncedKeys(chunk.map((e) => e.id));
        uploaded += chunk.length;
        debugPrint('$_tag chunk ok: $uploaded/${events.length} uploaded '
            '→ saved ${lastResponse.saved}, dupes ${lastResponse.duplicates}');
      }

      await _syncStorage.setLastRunAt(DateTime.now());
      debugPrint('$_tag done — posted $uploaded new events in chunks of '
          '$_batchSize ("${lastResponse?.message}").');
      return lastResponse;
    } on ApiException catch (e) {
      debugPrint('$_tag upload failed (will resume next pass): ${e.message}');
      return null;
    } catch (e, st) {
      debugPrint('$_tag unexpected error: $e\n$st');
      return null;
    }
  }
}

final eventSyncServiceProvider = Provider<EventSyncService>((ref) {
  return EventSyncService(
    ref.watch(eventRepositoryProvider),
    ref.watch(identityStorageProvider),
    ref.watch(eventSyncStorageProvider),
  );
});
