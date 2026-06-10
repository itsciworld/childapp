import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/identity_storage.dart';
import '../data/app_usage_sync_storage.dart';
import '../data/models/app_usage_item.dart';
import '../data/models/save_apps_response.dart';
import '../data/repositories/app_usage_repository.dart';

/// Reads app foreground-usage stats and uploads them to the backend —
/// **change-based**: it only POSTs when the usage picture differs from the last
/// upload, with a [_heartbeat] fallback so the backend still gets a periodic
/// refresh while apps are in use.
///
/// Shared by the UI [AppUsageViewModel] and the background isolate. Runs
/// silently but logs every step with [debugPrint]. Never throws.
class AppUsageSyncService {
  AppUsageSyncService(
      this._repository, this._identityStorage, this._syncStorage);

  final AppUsageRepository _repository;
  final IdentityStorage _identityStorage;
  final AppUsageSyncStorage _syncStorage;

  static const String _tag = '[AppUsageSync]';

  /// Re-upload at least this often even if the signature is unchanged.
  static const Duration _heartbeat = Duration(minutes: 15);

  /// Runs one pass. Returns the server response when usage was uploaded, or
  /// `null` when the pass was skipped (no identity / no usage / no change) or
  /// failed.
  Future<SaveAppsResponse?> sync() async {
    try {
      final identity = await _identityStorage.read();
      if (!identity.isComplete) {
        debugPrint('$_tag skipped — childId/parentId not set yet.');
        return null;
      }

      final apps = await _repository.readUsage();
      if (apps.isEmpty) {
        // No usage / no permission — record liveness, don't call the API.
        await _syncStorage.setLastRunAt(DateTime.now());
        debugPrint('$_tag no usage to report.');
        return null;
      }

      // Skip the upload when nothing changed and the heartbeat isn't due.
      final signature = _signatureOf(apps);
      final lastSignature = await _syncStorage.getSignature();
      final lastSentAt = await _syncStorage.getLastSentAt();
      final heartbeatDue = lastSentAt == null ||
          DateTime.now().difference(lastSentAt) >= _heartbeat;

      if (signature == lastSignature && !heartbeatDue) {
        await _syncStorage.setLastRunAt(DateTime.now());
        debugPrint('$_tag unchanged (${apps.length} apps) — skipping upload.');
        return null;
      }

      final response = await _repository.saveApps(
        apps,
        childId: identity.childId!,
        parentId: identity.parentId!,
      );

      final now = DateTime.now();
      await _syncStorage.setSignature(signature, now);
      await _syncStorage.setLastRunAt(now);

      debugPrint(
        '$_tag posted ${apps.length} apps → '
        'total ${response.total}, new ${response.newCount}, '
        'updated ${response.updated} ("${response.message}")',
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

  String _signatureOf(List<AppUsageItem> apps) {
    final parts = apps.map((a) => a.signature).toList()..sort();
    return parts.join('|');
  }
}

final appUsageSyncServiceProvider = Provider<AppUsageSyncService>((ref) {
  return AppUsageSyncService(
    ref.watch(appUsageRepositoryProvider),
    ref.watch(identityStorageProvider),
    ref.watch(appUsageSyncStorageProvider),
  );
});
