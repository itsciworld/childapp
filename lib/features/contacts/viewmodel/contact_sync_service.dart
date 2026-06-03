import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/identity_storage.dart';
import '../data/contact_sync_storage.dart';
import '../data/models/store_contacts_response.dart';
import '../data/repositories/contact_repository.dart';

/// Reads device contacts and uploads them to the backend.
///
/// This is the single piece of orchestration shared by the UI
/// [ContactViewModel] and the background monitoring isolate. It runs silently
/// but logs every step with [debugPrint] so the flow can be followed in the
/// console.
class ContactSyncService {
  ContactSyncService(
      this._repository, this._identityStorage, this._syncStorage);

  final ContactRepository _repository;
  final IdentityStorage _identityStorage;
  final ContactSyncStorage _syncStorage;

  static const String _tag = '[ContactSync]';

  /// Max contacts per upload request. Kept small because the server dedupes each
  /// contact and is slow — a big first-sync payload blew the receive timeout.
  /// Smaller batches mean fast requests and durable progress (each batch is
  /// marked synced as soon as it lands).
  static const int _batchSize = 50;

  /// Runs one sync pass. Returns the server response on success, or `null`
  /// when the pass was skipped (missing identity / no new contacts) or failed.
  /// Never throws — failures are swallowed and logged so a background timer
  /// keeps ticking.
  Future<StoreContactsResponse?> sync() async {
    try {
      final identity = await _identityStorage.read();
      if (!identity.isComplete) {
        debugPrint('$_tag skipped — childId/parentId not set yet.');
        return null;
      }

      final synced = await _syncStorage.getSyncedKeys();
      final contacts = await _repository.readDeviceContacts(
        childId: identity.childId!,
        parentId: identity.parentId!,
        alreadySynced: synced,
      );
      if (contacts.isEmpty) {
        // Still a successful pass — record the time so the UI shows liveness.
        await _syncStorage.setLastRunAt(DateTime.now());
        debugPrint('$_tag no new contacts (${synced.length} already synced).');
        return null;
      }

      // Upload only ONE batch per pass. A first sync on a large address book is
      // too big for a single request (the server dedupes each contact and hits
      // the receive timeout), and doing every batch in one pass would block the
      // whole sync cycle (SMS / call logs) for a long time. Instead each 5s pass
      // sends the next [_batchSize] contacts; the recurring loop drains the
      // backlog over successive passes. The batch is marked synced as soon as it
      // lands, so progress is durable and the next pass picks up the remainder.
      final remaining = contacts.length;
      final batch = contacts.length > _batchSize
          ? contacts.sublist(0, _batchSize)
          : contacts;

      final response = await _repository.storeContacts(batch);
      // Mark this batch's numbers as synced so the next pass skips them.
      await _syncStorage.addSyncedKeys(batch.map((c) => c.phone));
      await _syncStorage.setLastRunAt(DateTime.now());

      debugPrint(
        '$_tag posted ${batch.length} new contacts '
        '(${remaining - batch.length} remaining) → '
        'saved ${response.saved}, duplicates ${response.duplicates}, '
        'total ${response.total} ("${response.message}")',
      );
      return response;
    } on ApiException catch (e) {
      // A batch failed (e.g. timeout) — batches already sent stay marked synced,
      // so the next pass resumes from the remainder instead of restarting.
      debugPrint('$_tag upload failed (will resume next pass): ${e.message}');
      return null;
    } catch (e, st) {
      debugPrint('$_tag unexpected error: $e\n$st');
      return null;
    }
  }
}

final contactSyncServiceProvider = Provider<ContactSyncService>((ref) {
  return ContactSyncService(
    ref.watch(contactRepositoryProvider),
    ref.watch(identityStorageProvider),
    ref.watch(contactSyncStorageProvider),
  );
});
