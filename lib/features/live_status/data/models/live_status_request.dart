import 'battery_info.dart';
import 'connectivity_info.dart';

/// Full body for `PUT /api/children/:childId/live-status` — the child's current
/// online flag plus a battery and connectivity snapshot.
class LiveStatusRequest {
  const LiveStatusRequest({
    required this.isOnline,
    required this.batteryInfo,
    required this.connectivity,
  });

  /// Whether the device currently has a working network connection.
  final bool isOnline;

  final BatteryInfo batteryInfo;
  final ConnectivityInfo connectivity;

  Map<String, dynamic> toJson() => {
        'isOnline': isOnline,
        'batteryInfo': batteryInfo.toJson(),
        'connectivity': connectivity.toJson(),
      };
}
