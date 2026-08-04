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

  /// Max events per upload request — one batch per pass, like contacts, so a
  /// large first sync drains gradually instead of one huge request.
  static const int _batchSize = 100;

  /// Runs one sync pass. Returns the server response on success, or `null` when
  /// the pass was skipped (no identity / no new events) or failed.
  Future<StoreEventsResponse?> sync() async {
    try {
      final identity = await _identityStorage.read();
      if (!identity.isComplete) {
        debugPrint('$_tag skipped — childId/parentId not set yet.');
        return null;
      }

      // Identity is present, so this is a real pass — the monitor is alive.
      // Record liveness in a `finally` so the home tile shows "Active" even if
      // the upload below fails: the background isolate has no way to surface an
      // error to the UI, so without this a failing/odd-response pass would leave
      // the tile stuck on "Starting…" forever (never "Retrying"). This mirrors
      // location, which reports "Active" whenever its pass ran.
      try {
        final synced = await _syncStorage.getSyncedKeys();
        final events =
            await _repository.readDeviceEvents(alreadySynced: synced);
        if (events.isEmpty) {
          debugPrint('$_tag no new events (${synced.length} already synced).');
          return null;
        }

        // Upload only ONE batch per pass; the recurring loop drains the rest.
        final batch = events.length > _batchSize
            ? events.sublist(0, _batchSize)
            : events;
        final remaining = events.length - batch.length;

        final response = await _repository.storeEvents(
          batch,
          childId: identity.childId!,
          parentId: identity.parentId!,
        );

        // Mark this batch's ids as synced so the next pass skips them.
        await _syncStorage.addSyncedKeys(batch.map((e) => e.id));

        debugPrint(
          '$_tag posted ${batch.length} new events ($remaining remaining) → '
          'saved ${response.saved}, duplicates ${response.duplicates}, '
          'total ${response.total} ("${response.message}")',
        );
        return response;
      } finally {
        await _syncStorage.setLastRunAt(DateTime.now());
      }
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
