import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/device_storage.dart';
import '../models/location_item.dart';
import '../models/store_location_response.dart';

/// Owns all location data access: reading the current GPS fix, reverse-geocoding
/// it to an address, and uploading it to the backend. The UI / background loop
/// never touches `geolocator` / `geocoding` or Dio directly — it goes through
/// this repository.
class LocationRepository {
  LocationRepository(this._dio, this._deviceStorage);

  final Dio _dio;
  final DeviceStorage _deviceStorage;

  static const String _tag = '[LocationRepo]';

  /// Reads the device's current position, or `null` when location services are
  /// off or the permission isn't granted (the sync just skips that pass).
  Future<Position?> readCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        debugPrint('$_tag location services are OFF — skipping.');
        return null;
      }
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        debugPrint('$_tag location permission not granted — skipping.');
        return null;
      }
      // A [timeLimit] is essential: with high accuracy and no GPS fix (very
      // common on emulators) this call would otherwise block forever and hang
      // the isolate. On timeout we fall back to the last known position.
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
    } catch (e) {
      debugPrint('$_tag getCurrentPosition failed ($e) — trying last known.');
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  /// Reverse-geocodes [lat]/[lng] into the FULL street address, e.g.
  /// `123, Mall Road, Gulberg, Lahore, Punjab 54000, Pakistan` — building number
  /// + street, area, city, state, postal code and country, in that order.
  /// Best-effort: returns `null` if the platform geocoder fails or is offline.
  Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return null;
      final p = placemarks.first;
      // Build the address from fine → coarse. We DON'T drop the street-level
      // fields any more, so the full address is sent instead of only the city.
      final ordered = <String?>[
        p.subThoroughfare, // building / house number
        p.thoroughfare, // street name
        p.subLocality, // neighbourhood / area
        p.locality, // city
        p.subAdministrativeArea, // district
        p.administrativeArea, // state / province
        p.postalCode, // ZIP / postal code
        p.country,
      ];
      // Some platforms also expose a ready-made `street` line; fall back to it
      // when the granular thoroughfare fields are empty.
      if ((p.thoroughfare ?? '').isEmpty &&
          (p.subThoroughfare ?? '').isEmpty &&
          (p.street ?? '').isNotEmpty) {
        ordered.insert(0, p.street);
      }

      final parts = <String>[];
      for (final raw in ordered) {
        final v = raw?.trim() ?? '';
        if (v.isEmpty) continue;
        // Skip near-duplicate fields (e.g. `street` already containing the
        // thoroughfare, or locality == subAdministrativeArea).
        final dup = parts.any((existing) =>
            existing.toLowerCase() == v.toLowerCase() ||
            existing.toLowerCase().contains(v.toLowerCase()) ||
            v.toLowerCase().contains(existing.toLowerCase()));
        if (dup) continue;
        parts.add(v);
      }

      final address = parts.join(', ');
      return address.isEmpty ? null : address;
    } catch (e) {
      debugPrint('$_tag reverse-geocode failed: $e');
      return null;
    }
  }

  /// Uploads one [item] to `POST /api/locations/store_location`.
  ///
  /// [childId] / [parentId] are sent in the flat body alongside the coordinates.
  /// The backend-issued device key is sent in the `x-device-key` header. The
  /// server response is printed so success can be confirmed from the terminal.
  ///
  /// Throws [ApiException] on any network / server failure.
  Future<StoreLocationResponse> storeLocation(
    LocationItem item, {
    required String childId,
    required String parentId,
  }) async {
    try {
      final deviceKey = await _deviceStorage.getDeviceKey();
      final response = await _dio.post<dynamic>(
        '/api/locations/store_location',
        data: item.toJson(childId: childId, parentId: parentId),
        options: Options(
          headers: {
            if (deviceKey != null && deviceKey.isNotEmpty)
              'x-device-key': deviceKey,
          },
        ),
      );

      // Print the raw response so the API result is visible in the terminal.
      debugPrint('$_tag store_location response '
          '(${response.statusCode}): ${response.data}');

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return const StoreLocationResponse(status: 200);
      }
      return StoreLocationResponse.fromJson(data);
    } on DioException catch (e) {
      debugPrint('$_tag store_location failed: '
          '${e.response?.statusCode} ${e.response?.data ?? e.message}');
      throw ApiException.fromDio(e);
    } on FormatException catch (e) {
      throw ApiException(e.message);
    }
  }
}

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository(
    ref.watch(dioProvider),
    ref.watch(deviceStorageProvider),
  );
});
