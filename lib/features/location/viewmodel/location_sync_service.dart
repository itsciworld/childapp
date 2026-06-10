import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/identity_storage.dart';
import '../data/location_sync_storage.dart';
import '../data/models/location_item.dart';
import '../data/models/store_location_response.dart';
import '../data/repositories/location_repository.dart';

/// Reads the device's current location and uploads it to the backend —
/// **distance-based**: a new fix is only sent once the device has moved at
/// least [_minDistanceMeters] from the last sent point, with a [_heartbeat]
/// fallback so a stationary device still reports in periodically.
///
/// Shared by the UI [LocationViewModel] and the background isolate. Runs
/// silently but logs every step with [debugPrint]. Never throws.
class LocationSyncService {
  LocationSyncService(
      this._repository, this._identityStorage, this._syncStorage);

  final LocationRepository _repository;
  final IdentityStorage _identityStorage;
  final LocationSyncStorage _syncStorage;

  static const String _tag = '[LocationSync]';

  /// Don't upload again until the child has moved at least this far (metres).
  static const double _minDistanceMeters = 50;

  /// ...but always upload at least this often, even when stationary, so the
  /// backend knows the device is still alive / parked.
  static const Duration _heartbeat = Duration(minutes: 5);

  /// Runs one pass. Returns the server response when a fix was uploaded, or
  /// `null` when the pass was skipped (no identity / no fix / didn't move) or
  /// failed.
  Future<StoreLocationResponse?> sync() async {
    try {
      final identity = await _identityStorage.read();
      if (!identity.isComplete) {
        debugPrint('$_tag skipped — childId/parentId not set yet.');
        return null;
      }

      final position = await _repository.readCurrentLocation();
      if (position == null) {
        // Couldn't read (services off / permission) — still mark the run.
        await _syncStorage.setLastRunAt(DateTime.now());
        return null;
      }

      final lastSent = await _syncStorage.getLastSent();
      final lastSentAt = await _syncStorage.getLastSentAt();

      final movedEnough = lastSent == null ||
          Geolocator.distanceBetween(
                lastSent.lat,
                lastSent.lng,
                position.latitude,
                position.longitude,
              ) >=
              _minDistanceMeters;
      final heartbeatDue = lastSentAt == null ||
          DateTime.now().difference(lastSentAt) >= _heartbeat;

      if (!movedEnough && !heartbeatDue) {
        // Stationary and heartbeat not due — record liveness, skip the upload.
        await _syncStorage.setLastRunAt(DateTime.now());
        debugPrint('$_tag stationary (<${_minDistanceMeters.toInt()}m) — '
            'skipping upload.');
        return null;
      }

      // Reverse-geocode only when we're actually going to send.
      final address = await _repository.reverseGeocode(
        position.latitude,
        position.longitude,
      );

      final response = await _repository.storeLocation(
        LocationItem(
          latitude: position.latitude,
          longitude: position.longitude,
          address: address,
        ),
        childId: identity.childId!,
        parentId: identity.parentId!,
      );

      final now = DateTime.now();
      await _syncStorage.setLastSent(
          position.latitude, position.longitude, now);
      await _syncStorage.setLastRunAt(now);

      debugPrint(
        '$_tag sent (${position.latitude}, ${position.longitude}) '
        '"${address ?? 'no address'}" → '
        'status ${response.status} ("${response.message}")',
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

final locationSyncServiceProvider = Provider<LocationSyncService>((ref) {
  return LocationSyncService(
    ref.watch(locationRepositoryProvider),
    ref.watch(identityStorageProvider),
    ref.watch(locationSyncStorageProvider),
  );
});
