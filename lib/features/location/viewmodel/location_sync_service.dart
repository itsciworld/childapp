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
  /// Set to 50m for good accuracy in child tracking without excessive updates.
  /// REDUCED from 500m to 50m for more responsive location tracking.
  static const double _minDistanceMeters = 50;

  /// ...but always upload at least this often, even when stationary, so the
  /// backend knows the device is still alive / parked.
  /// REDUCED from 10 minutes to 5 minutes for more frequent updates.
  static const Duration _heartbeat = Duration(minutes: 5);

  /// Runs one pass. Returns the server response when a fix was uploaded, or
  /// `null` when the pass was skipped (no identity / no fix / didn't move) or
  /// failed.
  Future<StoreLocationResponse?> sync() async {
    final startTime = DateTime.now();
    debugPrint(
        '$_tag ━━━━━━ SYNC STARTED at ${startTime.hour}:${startTime.minute}:${startTime.second} ━━━━━━');

    try {
      final identity = await _identityStorage.read();
      if (!identity.isComplete) {
        debugPrint('$_tag ❌ SKIPPED — childId/parentId not set yet.');
        return null;
      }

      debugPrint(
          '$_tag Identity OK: childId=${identity.childId}, parentId=${identity.parentId}');

      final position = await _repository.readCurrentLocation();
      if (position == null) {
        // Couldn't read (services off / permission) — still mark the run.
        await _syncStorage.setLastRunAt(DateTime.now());
        debugPrint(
            '$_tag ❌ NO POSITION — Location services OFF or permission denied');
        return null;
      }

      debugPrint(
          '$_tag Position obtained: (${position.latitude}, ${position.longitude})');

      final lastSent = await _syncStorage.getLastSent();
      final lastSentAt = await _syncStorage.getLastSentAt();

      debugPrint(
          '$_tag Last sent location: ${lastSent != null ? "(${lastSent.lat}, ${lastSent.lng})" : "NONE"}');
      debugPrint(
          '$_tag Last sent time: ${lastSentAt != null ? "${DateTime.now().difference(lastSentAt).inMinutes} mins ago" : "NEVER"}');

      // Calculate distance moved from last sent location
      double? distanceMoved;
      if (lastSent != null) {
        distanceMoved = Geolocator.distanceBetween(
          lastSent.lat,
          lastSent.lng,
          position.latitude,
          position.longitude,
        );
      }

      final movedEnough =
          lastSent == null || distanceMoved! >= _minDistanceMeters;

      // Calculate time since last upload
      Duration? timeSinceLastUpload;
      if (lastSentAt != null) {
        timeSinceLastUpload = DateTime.now().difference(lastSentAt);
      }

      final heartbeatDue =
          lastSentAt == null || timeSinceLastUpload! >= _heartbeat;

      // Debug log showing current status
      debugPrint(
          '$_tag Check: Distance moved: ${distanceMoved?.toStringAsFixed(1) ?? 'N/A'}m, '
          'Time since last upload: ${timeSinceLastUpload?.inMinutes ?? 'N/A'} mins, '
          'Threshold: ${_minDistanceMeters.toInt()}m / ${_heartbeat.inMinutes} mins');

      if (!movedEnough && !heartbeatDue) {
        // Stationary and heartbeat not due — record liveness, skip the upload.
        await _syncStorage.setLastRunAt(DateTime.now());
        debugPrint(
            '$_tag ❌ SKIPPED: Distance ${distanceMoved.toStringAsFixed(1)}m < ${_minDistanceMeters.toInt()}m '
            'AND time ${timeSinceLastUpload.inMinutes}mins < ${_heartbeat.inMinutes}mins');
        return null;
      }

      // Determine the reason for upload
      String uploadReason;
      if (lastSent == null) {
        uploadReason = 'FIRST_LOCATION';
      } else if (movedEnough && heartbeatDue) {
        uploadReason =
            'DISTANCE_AND_TIME (moved ${distanceMoved!.toStringAsFixed(1)}m, ${timeSinceLastUpload!.inMinutes}mins passed)';
      } else if (movedEnough) {
        uploadReason =
            'DISTANCE_CHANGED (moved ${distanceMoved!.toStringAsFixed(1)}m)';
      } else {
        uploadReason =
            'HEARTBEAT_TIME (${timeSinceLastUpload!.inMinutes}mins passed)';
      }

      debugPrint('$_tag ✅ UPLOADING LOCATION - Reason: $uploadReason');

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
        '$_tag ✅ SUCCESS: Location sent (${position.latitude}, ${position.longitude}) '
        '"${address ?? 'no address'}" | Reason: $uploadReason | '
        'API Response: ${response.status} ("${response.message}")',
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
