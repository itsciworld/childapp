/// Battery half of the `PUT /api/children/:childId/live-status` body.
///
/// Matches the `batteryInfo` object:
/// `{ "level", "state", "isInBatterySaveMode", "temperature", "voltage" }`.
class BatteryInfo {
  const BatteryInfo({
    required this.level,
    required this.state,
    required this.isInBatterySaveMode,
    this.temperature,
    this.voltage,
  });

  /// Charge percentage, 0–100.
  final int level;

  /// Charging state: `charging` | `discharging` | `full` |
  /// `connectedNotCharging` | `unknown`.
  final String state;

  /// Whether the OS battery-saver / low-power mode is on.
  final bool isInBatterySaveMode;

  /// Battery temperature in °C, when the platform exposes it (null otherwise).
  final double? temperature;

  /// Battery voltage in mV, when the platform exposes it (null otherwise).
  final int? voltage;

  Map<String, dynamic> toJson() => {
        'level': level,
        'state': state,
        'isInBatterySaveMode': isInBatterySaveMode,
        'temperature': temperature,
        'voltage': voltage,
      };
}
