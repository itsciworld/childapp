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
        'text': text,
        'capturedAt': capturedAt.millisecondsSinceEpoch,
      };

  /// Upload payload shape. ADJUST THIS to match the backend schema when wiring
  /// the real endpoint — it's the only place the request contract is built.
  Map<String, dynamic> toJson() => {
        'package': packageName,
        'app': appName,
        'conversation': conversation,
        'text': text,
        'captured_at': capturedAt.toUtc().toIso8601String(),
        'source': 'accessibility',
      };
}
