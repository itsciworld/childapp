/// One captured on-screen text line (FEATURE B), decoded from a line of the
/// native `a11y_queue.jsonl` queue.
///
/// `toJson()` is the upload shape; `toQueueMap()` is the inverse of
/// `fromQueue()`, used to re-serialise an entry back onto the queue when an
/// upload fails so a retry re-drains it identically.
class ScreenMessageEntry {
  const ScreenMessageEntry({
    required this.packageName,
    required this.appName,
    required this.conversation,
    required this.direction,
    required this.sender,
    required this.text,
    required this.capturedAt,
  });

  /// Source app package, e.g. `org.telegram.messenger`.
  final String packageName;

  /// Friendly app name set natively, e.g. `Telegram`.
  final String appName;

  /// Best-effort name of the chat that was open when this was captured (the
  /// toolbar title), or empty when it couldn't be determined.
  final String conversation;

  /// Which side of the chat this line sat on, inferred natively from bubble
  /// alignment: `sent` (the child's own message), `received` (incoming), or
  /// `unknown` (date chips / system notices / anything not clearly aligned).
  final String direction;

  /// Who sent the line: `me` for the child's own messages, otherwise empty
  /// (the incoming sender's name isn't recoverable from a flat screen read).
  final String sender;

  /// A single visible text line pulled from the screen.
  final String text;

  /// When the screen was read.
  final DateTime capturedAt;

  factory ScreenMessageEntry.fromQueue(Map<String, dynamic> m) {
    final raw = m['capturedAt'];
    final ms = raw is int ? raw : int.tryParse('${raw ?? ''}') ?? 0;
    return ScreenMessageEntry(
      packageName: '${m['package'] ?? ''}',
      appName: '${m['app'] ?? ''}',
      conversation: '${m['conversation'] ?? ''}',
      direction: '${m['direction'] ?? 'unknown'}',
      sender: '${m['sender'] ?? ''}',
      text: '${m['text'] ?? ''}',
      capturedAt: ms > 0
          ? DateTime.fromMillisecondsSinceEpoch(ms)
          : DateTime.now(),
    );
  }

  /// Re-serialises to the exact native queue shape (see `fromQueue`).
  Map<String, dynamic> toQueueMap() => {
        'source': 'accessibility',
        'package': packageName,
        'app': appName,
        'conversation': conversation,
        'direction': direction,
        'sender': sender,
        'text': text,
        'capturedAt': capturedAt.millisecondsSinceEpoch,
      };

  /// Upload payload shape — matches the `POST /api/social/screen` `messages[]`
  /// contract: a FLAT list, each entry carrying its own app + open-chat context.
  /// (The server groups by `conversation` itself; sending a pre-grouped
  /// `conversations[]` is rejected with 400 "messages array is required".)
  /// Direction + sender are what let the backend render this as a two-sided
  /// chat instead of a flat line.
  Map<String, dynamic> toJson() => {
        'package': packageName,
        'app': appName,
        'conversation': conversation,
        'direction': direction,
        'sender': sender,
        'text': text,
        'captured_at': capturedAt.toUtc().toIso8601String(),
      };
}
