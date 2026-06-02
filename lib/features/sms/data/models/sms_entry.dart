/// A single SMS uploaded to `POST /api/sms/store_sms`.
///
/// Matches one element of the `sms` array in the request body:
/// `{ "address", "body", "date", "child_id", "parent_id" }`.
class SmsEntry {
  const SmsEntry({
    required this.address,
    required this.body,
    required this.date,
    required this.childId,
    required this.parentId,
  });

  /// Sender / recipient phone number, e.g. `+923001234567`.
  final String address;

  /// Message text.
  final String body;

  /// When the message was received/sent (UTC).
  final DateTime date;

  final String childId;
  final String parentId;

  Map<String, dynamic> toJson() => {
        'address': address,
        'body': body,
        // ISO-8601 in UTC, e.g. `2026-05-05T10:00:00Z`.
        'date': date.toUtc().toIso8601String(),
        'child_id': childId,
        'parent_id': parentId,
      };
}
