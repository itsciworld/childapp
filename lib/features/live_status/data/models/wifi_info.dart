/// The `wifiInfo` nested object of the `connectivity` payload.
///
/// All fields are nullable: SSID / BSSID require location permission on
/// Android and may be unavailable, and `linkSpeed` is not exposed by the
/// cross-platform plugins (left null unless a native channel provides it).
class WifiInfo {
  const WifiInfo({
    this.ssid,
    this.bssid,
    this.ipAddress,
    this.linkSpeed,
  });

  /// Network name, e.g. `Home_Wifi`.
  final String? ssid;

  /// Access-point MAC, e.g. `00:11:22:33`.
  final String? bssid;

  /// This device's IPv4 on the WLAN, e.g. `192.168.1.2`.
  final String? ipAddress;

  /// Negotiated link speed in Mbps, when known.
  final int? linkSpeed;

  /// True when at least one WiFi detail was resolved — lets the caller omit an
  /// all-null `wifiInfo` from the body.
  bool get hasAny =>
      ssid != null || bssid != null || ipAddress != null || linkSpeed != null;

  Map<String, dynamic> toJson() => {
        'ssid': ssid,
        'bssid': bssid,
        'ipAddress': ipAddress,
        'linkSpeed': linkSpeed,
      };
}
