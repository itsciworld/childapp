/// One captured message-notification (FEATURE A), decoded from a line of the
/// native `notif_queue.jsonl` queue.
///
/// `toJson()` is the upload shape sent to the backend; `toQueueMap()` is the
/// inverse of `fromQueue()` and is used to re-serialise an entry back onto the
/// queue file when an upload fails (so a retry re-drains it identically).
class NotificationMessageEntry {
  const NotificationMessageEntry({
    required this.packageName,
    required this.appName,
    required this.title,
    required this.text,
    required this.subText,
    required this.isGroup,
    required this.postedAt,
  });

  /// Source app package, e.g. `com.whatsapp`.
  final String packageName;

  /// Friendly app name set natively, e.g. `WhatsApp`.
  final String appName;

  /// Notification title — the sender, or the group name for group chats.
  final String title;

  /// Message body / preview (WhatsApp truncates this ~100 chars).
  final String text;

  /// Group name when the notification carried one (else empty).
  final String subText;

  /// Heuristic: whether this looked like a group message.
  final bool isGroup;

  /// When the notification was posted.
  final DateTime postedAt;

  factory NotificationMessageEntry.fromQueue(Map<String, dynamic> m) {
    final raw = m['postedAt'];
    final ms = raw is int ? raw : int.tryParse('${raw ?? ''}') ?? 0;
    return NotificationMessageEntry(
      packageName: '${m['package'] ?? ''}',
      appName: '${m['app'] ?? ''}',
      title: '${m['title'] ?? ''}',
      text: '${m['text'] ?? ''}',
      subText: '${m['subText'] ?? ''}',
      isGroup: m['isGroup'] == true,
      postedAt: ms > 0
          ? DateTime.fromMillisecondsSinceEpoch(ms)
          : DateTime.now(),
    );
  }

  /// Re-serialises to the exact native queue shape (see `fromQueue`).
  Map<String, dynamic> toQueueMap() => {
        'source': 'notification',
        'package': packageName,
        'app': appName,
        'title': title,
        'text': text,
        'subText': subText,
        'isGroup': isGroup,
        'postedAt': postedAt.millisecondsSinceEpoch,
      };

  /// Upload payload shape — matches the `POST /api/social/notifications`
  /// `messages[]` contract. The only place the request contract is built.
  Map<String, dynamic> toJson() => {
        'package': packageName,
        'app': appName,
        'sender': title,
        'body': text,
        'group_name': subText,
        'is_group': isGroup,
        'posted_at': postedAt.toUtc().toIso8601String(),
      };
}
