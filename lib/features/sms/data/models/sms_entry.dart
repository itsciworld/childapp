/// A single SMS inside the `sms` array of `POST /api/sms/store_sms`.
///
/// `child_id` / `parent_id` are NOT part of an entry — they are sent once at
/// the top level of the request body (see [SmsRepository.storeSms]).
///
/// Matches one element of the `sms` array:
/// `{ "id", "thread_id", "address", "body", "date", "date_sent", "read",
///    "kind", "state" }`.
class SmsEntry {
  const SmsEntry({
    required this.id,
    required this.threadId,
    required this.address,
    required this.body,
    required this.date,
    required this.dateSent,
    required this.read,
    required this.kind,
    required this.state,
  });

  /// Device-local message id — used by the server to de-duplicate.
  final int? id;

  /// Conversation/thread id this message belongs to.
  final int? threadId;

  /// Sender / recipient phone number, e.g. `+923001234567`.
  final String address;

  /// Message text.
  final String body;

  /// When the message was received / sent (UTC).
  final DateTime date;

  /// When the originator actually sent the message (UTC), when known.
  final DateTime? dateSent;

  /// Whether the message has been read on the device.
  final bool read;

  /// Mailbox the message came from: `inbox` | `sent` | `draft`.
  final String kind;

  /// Delivery state: `received` | `sent` | `draft`.
  final String state;

  Map<String, dynamic> toJson() => {
        'id': id,
        'thread_id': threadId,
        'address': address,
        'body': body,
        // ISO-8601 in UTC, e.g. `2026-06-02T10:00:00Z`.
        'date': date.toUtc().toIso8601String(),
        if (dateSent != null) 'date_sent': dateSent!.toUtc().toIso8601String(),
        'read': read,
        'kind': kind,
        'state': state,
      };
}
