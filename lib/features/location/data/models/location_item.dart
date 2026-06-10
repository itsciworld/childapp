/// A single location fix uploaded to `POST /api/locations/store_location`.
///
/// The body is flat (not an array): `{ latitude, longitude, address,
/// child_id, parent_id }`. The ids are supplied by the repository at send time.
class LocationItem {
  const LocationItem({
    required this.latitude,
    required this.longitude,
    this.address,
  });

  final double latitude;
  final double longitude;

  /// Human-readable reverse-geocoded address, e.g. `Lahore, Pakistan`. May be
  /// null when geocoding is unavailable (no network / no geocoder).
  final String? address;

  Map<String, dynamic> toJson({
    required String childId,
    required String parentId,
  }) =>
      {
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'child_id': childId,
        'parent_id': parentId,
      };
}
