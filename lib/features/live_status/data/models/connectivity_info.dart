import 'wifi_info.dart';

/// Connectivity half of the `PUT /api/children/:childId/live-status` body.
///
/// Matches the `connectivity` object:
/// `{ "connectionType", "isConnected", "hasWifi", "hasMobile", "hasEthernet",
///    "hasBluetooth", "hasVpn", "wifiInfo" }`.
class ConnectivityInfo {
  const ConnectivityInfo({
    required this.connectionType,
    required this.isConnected,
    required this.hasWifi,
    required this.hasMobile,
    required this.hasEthernet,
    required this.hasBluetooth,
    required this.hasVpn,
    this.wifiInfo,
  });

  /// Active transports, e.g. `["wifi"]`.
  final List<String> connectionType;

  final bool isConnected;
  final bool hasWifi;
  final bool hasMobile;
  final bool hasEthernet;
  final bool hasBluetooth;
  final bool hasVpn;

  /// WiFi specifics — included only when on WiFi and at least one detail
  /// resolved.
  final WifiInfo? wifiInfo;

  Map<String, dynamic> toJson() => {
        'connectionType': connectionType,
        'isConnected': isConnected,
        'hasWifi': hasWifi,
        'hasMobile': hasMobile,
        'hasEthernet': hasEthernet,
        'hasBluetooth': hasBluetooth,
        'hasVpn': hasVpn,
        if (wifiInfo != null && wifiInfo!.hasAny) 'wifiInfo': wifiInfo!.toJson(),
      };
}
