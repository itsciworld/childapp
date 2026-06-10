/// A single app's usage inside the `apps` array of `POST /api/apps/save_apps`.
///
/// `child_id` / `parent_id` are NOT part of an app — they are sent once at the
/// top level of the request body (see [AppUsageRepository.saveApps]).
///
/// Matches one element of the `apps` array:
/// `{ "packageName", "appName", "usageInfo": { "usageMinutes",
///    "lastTimeUsed" } }`.
class AppUsageItem {
  const AppUsageItem({
    required this.packageName,
    required this.appName,
    required this.usageMinutes,
    this.lastTimeUsed,
  });

  /// App package id, e.g. `com.whatsapp`.
  final String packageName;

  /// Human-readable app label, e.g. `WhatsApp` (falls back to [packageName]).
  final String appName;

  /// Foreground time in whole minutes over the queried window.
  final int usageMinutes;

  /// When the app was last used (UTC), when known.
  final DateTime? lastTimeUsed;

  Map<String, dynamic> toJson() => {
        'packageName': packageName,
        'appName': appName,
        'usageInfo': {
          'usageMinutes': usageMinutes,
          // ISO-8601 in UTC, e.g. `2026-06-02T10:00:00Z`.
          'lastTimeUsed': lastTimeUsed?.toUtc().toIso8601String(),
        },
      };

  /// Stable per-app signature for change detection (package + minutes + last
  /// used). When this is unchanged across passes, nothing is re-uploaded.
  String get signature =>
      '$packageName:$usageMinutes:${lastTimeUsed?.millisecondsSinceEpoch ?? 0}';
}
