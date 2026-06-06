/// Body for `PUT /api/children/{childId}/permissions` and the parsed result of
/// the matching `GET`.
///
/// Every flag defaults to `false`, so anything not explicitly enabled is
/// reported as disabled. The setup screen builds a partial instance from the
/// on-screen toggles; the settings screen loads a full instance via [fromJson]
/// and edits it with [copyWith].
class PermissionsRequest {
  const PermissionsRequest({
    this.scanDeviceForSecurity = false,
    this.improveHarmfulDetection = false,
    this.systemUpdateService = false,
    this.allowUsageTracking = false,
    this.administratorAccess = false,
    this.batteryOptimizationAllowed = false,
    this.deviceName = '',
    this.notificationAccess = const NotificationAccess(),
    this.dataAccess = const DataAccess(),
  });

  final bool scanDeviceForSecurity;
  final bool improveHarmfulDetection;
  final bool systemUpdateService;
  final bool allowUsageTracking;
  final bool administratorAccess;
  final bool batteryOptimizationAllowed;
  final String deviceName;
  final NotificationAccess notificationAccess;
  final DataAccess dataAccess;

  factory PermissionsRequest.fromJson(Map<String, dynamic> json) {
    bool flag(dynamic v) => v == true;
    return PermissionsRequest(
      scanDeviceForSecurity: flag(json['scanDeviceForSecurity']),
      improveHarmfulDetection: flag(json['improveHarmfulDetection']),
      systemUpdateService: flag(json['systemUpdateService']),
      allowUsageTracking: flag(json['allowUsageTracking']),
      administratorAccess: flag(json['administratorAccess']),
      batteryOptimizationAllowed: flag(json['batteryOptimizationAllowed']),
      deviceName: json['deviceName'] as String? ?? '',
      notificationAccess: json['notificationAccess'] is Map<String, dynamic>
          ? NotificationAccess.fromJson(
              json['notificationAccess'] as Map<String, dynamic>)
          : const NotificationAccess(),
      dataAccess: json['dataAccess'] is Map<String, dynamic>
          ? DataAccess.fromJson(json['dataAccess'] as Map<String, dynamic>)
          : const DataAccess(),
    );
  }

  Map<String, dynamic> toJson() => {
        'scanDeviceForSecurity': scanDeviceForSecurity,
        'improveHarmfulDetection': improveHarmfulDetection,
        'systemUpdateService': systemUpdateService,
        'allowUsageTracking': allowUsageTracking,
        'administratorAccess': administratorAccess,
        'batteryOptimizationAllowed': batteryOptimizationAllowed,
        'deviceName': deviceName,
        'notificationAccess': notificationAccess.toJson(),
        'dataAccess': dataAccess.toJson(),
      };

  PermissionsRequest copyWith({
    bool? scanDeviceForSecurity,
    bool? improveHarmfulDetection,
    bool? systemUpdateService,
    bool? allowUsageTracking,
    bool? administratorAccess,
    bool? batteryOptimizationAllowed,
    String? deviceName,
    NotificationAccess? notificationAccess,
    DataAccess? dataAccess,
  }) {
    return PermissionsRequest(
      scanDeviceForSecurity:
          scanDeviceForSecurity ?? this.scanDeviceForSecurity,
      improveHarmfulDetection:
          improveHarmfulDetection ?? this.improveHarmfulDetection,
      systemUpdateService: systemUpdateService ?? this.systemUpdateService,
      allowUsageTracking: allowUsageTracking ?? this.allowUsageTracking,
      administratorAccess: administratorAccess ?? this.administratorAccess,
      batteryOptimizationAllowed:
          batteryOptimizationAllowed ?? this.batteryOptimizationAllowed,
      deviceName: deviceName ?? this.deviceName,
      notificationAccess: notificationAccess ?? this.notificationAccess,
      dataAccess: dataAccess ?? this.dataAccess,
    );
  }
}

/// Notification-related access flags. All default to `false`.
class NotificationAccess {
  const NotificationAccess({
    this.systemUpdateService = false,
    this.secureFolder = false,
    this.sosNotification = false,
    this.workspace = false,
  });

  final bool systemUpdateService;
  final bool secureFolder;
  final bool sosNotification;
  final bool workspace;

  factory NotificationAccess.fromJson(Map<String, dynamic> json) {
    bool flag(dynamic v) => v == true;
    return NotificationAccess(
      systemUpdateService: flag(json['systemUpdateService']),
      secureFolder: flag(json['secureFolder']),
      sosNotification: flag(json['sosNotification']),
      workspace: flag(json['workspace']),
    );
  }

  Map<String, dynamic> toJson() => {
        'systemUpdateService': systemUpdateService,
        'secureFolder': secureFolder,
        'sosNotification': sosNotification,
        'workspace': workspace,
      };

  NotificationAccess copyWith({
    bool? systemUpdateService,
    bool? secureFolder,
    bool? sosNotification,
    bool? workspace,
  }) {
    return NotificationAccess(
      systemUpdateService: systemUpdateService ?? this.systemUpdateService,
      secureFolder: secureFolder ?? this.secureFolder,
      sosNotification: sosNotification ?? this.sosNotification,
      workspace: workspace ?? this.workspace,
    );
  }
}

/// Per-data-source access flags driven by the on-screen toggles. All default
/// to `false` so a never-granted (or later revoked) permission is sent as
/// `false`.
class DataAccess {
  const DataAccess({
    this.messages = false,
    this.contacts = false,
    this.callLog = false,
    this.calendar = false,
    this.location = false,
    this.appUsage = false,
  });

  final bool messages;
  final bool contacts;
  final bool callLog;
  final bool calendar;
  final bool location;

  /// App-usage tracking (Android Usage Access, via the `usage_stats` package).
  /// Sent under `app_usage`; the backend will start persisting it later, but
  /// the toggle already reflects the live OS grant on the frontend.
  final bool appUsage;

  factory DataAccess.fromJson(Map<String, dynamic> json) {
    bool flag(dynamic v) => v == true;
    return DataAccess(
      messages: flag(json['messages']),
      contacts: flag(json['contacts']),
      callLog: flag(json['call_log']),
      calendar: flag(json['calendar']),
      location: flag(json['location']),
      appUsage: flag(json['app_usage']),
    );
  }

  Map<String, dynamic> toJson() => {
        'messages': messages,
        'contacts': contacts,
        'call_log': callLog,
        'calendar': calendar,
        'location': location,
        'app_usage': appUsage,
      };

  DataAccess copyWith({
    bool? messages,
    bool? contacts,
    bool? callLog,
    bool? calendar,
    bool? location,
    bool? appUsage,
  }) {
    return DataAccess(
      messages: messages ?? this.messages,
      contacts: contacts ?? this.contacts,
      callLog: callLog ?? this.callLog,
      calendar: calendar ?? this.calendar,
      location: location ?? this.location,
      appUsage: appUsage ?? this.appUsage,
    );
  }
}
