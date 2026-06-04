/// A single call-log record inside the `logs` array of
/// `POST /api/logs/store_calllogs`.
///
/// `child_id` / `parent_id` are NOT part of a log — they are sent once at the
/// top level of the request body (see [CallLogRepository.storeCallLogs]).
///
/// Matches one element of the `logs` array:
/// `{ "number", "name", "callType", "timestamp", "duration" }`.
class CallLogItem {
  const CallLogItem({
    required this.number,
    required this.name,
    required this.callType,
    required this.timestamp,
    required this.duration,
  });

  /// Other party's phone number, e.g. `+923001234567`.
  final String number;

  /// Contact name (empty when the number isn't in contacts).
  final String name;

  /// Call type, e.g. `incoming`, `outgoing`, `missed`.
  final String callType;

  /// When the call started (UTC).
  final DateTime timestamp;

  /// Call length in seconds.
  final int duration;

  Map<String, dynamic> toJson() => {
        'number': number,
        'name': name,
        'callType': callType,
        // ISO-8601 in UTC, e.g. `2026-06-02T10:00:00Z`.
        'timestamp': timestamp.toUtc().toIso8601String(),
        'duration': duration,
      };
}
