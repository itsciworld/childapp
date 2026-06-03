/// A single call-log record uploaded to `POST /api/logs/store_calllogs`.
///
/// Matches one element of the `logs` array in the request body:
/// `{ "number", "name", "callType", "timestamp", "duration", "child_id",
/// "parent_id" }`.
class CallLogItem {
  const CallLogItem({
    required this.number,
    required this.name,
    required this.callType,
    required this.timestamp,
    required this.duration,
    required this.childId,
    required this.parentId,
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

  final String childId;
  final String parentId;

  Map<String, dynamic> toJson() => {
        'number': number,
        'name': name,
        'callType': callType,
        // ISO-8601 in UTC, e.g. `2026-05-05T10:00:00Z`.
        'timestamp': timestamp.toUtc().toIso8601String(),
        'duration': duration,
        'child_id': childId,
        'parent_id': parentId,
      };
}
