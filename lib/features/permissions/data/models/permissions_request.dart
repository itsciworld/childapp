/// Request body for `PUT /api/children/{childId}/permissions`.
///
/// Every flag defaults to `false`, so anything the child did not explicitly
/// enable is reported as disabled. The UI maps the on-screen toggles onto the
/// relevant fields before sending.
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

  Map<String, dynamic> toJson() => {
        'systemUpdateService': systemUpdateService,
        'secureFolder': secureFolder,
        'sosNotification': sosNotification,
        'workspace': workspace,
      };
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
  });

  final bool messages;
  final bool contacts;
  final bool callLog;
  final bool calendar;
  final bool location;

  Map<String, dynamic> toJson() => {
        'messages': messages,
        'contacts': contacts,
        'call_log': callLog,
        'calendar': calendar,
        'location': location,
      };
}
