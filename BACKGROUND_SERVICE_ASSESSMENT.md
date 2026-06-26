# Background Service Reliability Assessment

**Date**: 2026-06-19  
**Status**: ⚠️ **NEEDS CRITICAL IMPROVEMENTS**

## Executive Summary

Your background service is **partially functional** but will **NOT work reliably** when the app is killed on most Android devices, especially modern versions (Android 8.0+) and devices from manufacturers with aggressive battery optimization (Xiaomi, Huawei, OnePlus, Samsung, Oppo, Vivo).

## Current Implementation Status

### ✅ What's Working

1. **Foreground Service**: Correctly implemented with notification
2. **Auto-start on Boot**: Configured to restart after device reboot
3. **Multi-stream Architecture**: Each sync service runs independently
4. **Leader Election**: Prevents duplicate syncs from multiple isolates
5. **Proper Permissions**: All required permissions declared
6. **Batch Processing**: Efficient data upload strategy

### ❌ Critical Issues

#### 1. Battery Optimization NOT Properly Handled
**Status**: ⚠️ **FIXED** - Added battery optimization exemption request

**What I Added**:
```dart
// In main.dart
await _requestBatteryOptimizationExemption();
```

**What This Does**: 
- Prompts user to disable battery optimization for the app
- Essential for background service survival on modern Android
- Without this, system WILL kill your service aggressively

---

#### 2. Timer Intervals Too Aggressive
**Status**: ❌ **NEEDS FIX**

**Problem**: Your current intervals are too short for reliable background operation:
- SMS: 10 seconds ⚠️ Too frequent
- Call Logs: 55 seconds ⚠️ Too frequent  
- Location: 10 seconds ⚠️ Too frequent

**Android Restrictions**:
- Android 8.0+ enforces background execution limits
- Doze mode batches/delays short-interval operations
- Frequent wake-ups trigger aggressive battery optimization

**Recommended Changes**:
```dart
class SyncIntervals {
  static const Duration sms = Duration(minutes: 2);          // Was 10 seconds
  static const Duration callLogs = Duration(minutes: 3);     // Was 55 seconds
  static const Duration contacts = Duration(minutes: 10);     // OK
  static const Duration events = Duration(minutes: 15);       // OK
  static const Duration liveStatus = Duration(minutes: 1);    // Was 30 seconds
  static const Duration location = Duration(minutes: 1);      // Was 10 seconds (but has distance filter)
  static const Duration appUsage = Duration(minutes: 15);     // OK
  static const Duration gallery = Duration(minutes: 15);      // OK
  static const Duration notification = Duration(minutes: 5);  // Was 320 seconds
}
```

**Note on Location**: Your location service has smart distance-based filtering (500m threshold + 10-minute heartbeat), so a 1-minute check interval is acceptable since it won't upload unless the device actually moves.

---

#### 3. No Doze Mode Exemption
**Status**: ❌ **NEEDS FIX**

**Problem**: Android Doze mode puts the device into deep sleep, pausing all timers and network access.

**Impact**: 
- Your service won't run when screen is off for extended periods
- Network requests will be queued/delayed/dropped
- This is why "complete day" monitoring won't work

**Solutions**:

**Option A: Request Doze Whitelist** (Easier but less reliable)
```dart
// Add this permission to AndroidManifest.xml (already present)
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />

// In code, explicitly request Doze exemption
await Permission.ignoreBatteryOptimizations.request();

// Guide user to manually whitelist app in Settings > Battery > Battery Optimization
```

**Option B: Use WorkManager** (More reliable, recommended)
```yaml
# pubspec.yaml
dependencies:
  workmanager: ^0.5.2
```

```dart
// Initialize in main.dart
await Workmanager().initialize(callbackDispatcher, isInDebugMode: kDebugMode);

// Schedule periodic work that survives Doze
await Workmanager().registerPeriodicTask(
  "vigil-sync",
  "syncAllData",
  frequency: Duration(minutes: 15), // Minimum allowed by Android
  constraints: Constraints(
    networkType: NetworkType.connected,
  ),
);
```

---

#### 4. No Explicit Restart Mechanism
**Status**: ❌ **NEEDS FIX**

**Problem**: When the OS kills your service (which it WILL under memory pressure), there's no guaranteed restart.

**Current Setup**: 
- `autoStart: true` only works on device reboot
- Doesn't handle service death during normal operation

**Solution**: Add a watchdog/restart mechanism

```dart
// In background_services.dart, add periodic service health check

// Check if service is running every 30 minutes
Timer.periodic(Duration(minutes: 30), (_) async {
  final service = FlutterBackgroundService();
  final isRunning = await service.isRunning();
  
  if (!isRunning) {
    debugPrint('[Watchdog] ⚠️ Service stopped unexpectedly - restarting');
    await service.startService();
  }
});
```

**Better Solution**: Use WorkManager as a fallback that checks if the foreground service is running.

---

#### 5. Manufacturer-Specific Battery Restrictions
**Status**: ⚠️ **REQUIRES USER ACTION**

**Problem**: Manufacturers like Xiaomi, Huawei, OnePlus add custom battery optimization that ignores standard Android exemptions.

**Impact**: Even with all exemptions granted, the service may still be killed.

**Solution**: Guide users to manually whitelist your app:

**Xiaomi (MIUI)**:
1. Settings → Apps → Manage Apps → Vigil-Child
2. Battery Saver → No Restrictions
3. Autostart → Enable
4. Lock app in Recent Apps (pull down on app card)

**Huawei (EMUI)**:
1. Settings → Battery → Launch → Vigil-Child → Manage Manually
2. Enable all three toggles (Auto-launch, Secondary launch, Run in background)

**OnePlus (OxygenOS)**:
1. Settings → Battery → Battery Optimization → Vigil-Child → Don't Optimize
2. Recent Apps → Lock Vigil-Child

**Samsung (One UI)**:
1. Settings → Apps → Vigil-Child → Battery → Optimize battery usage → All → Vigil-Child → Turn Off
2. Settings → Device Care → Battery → Background Usage Limits → Never Sleeping Apps → Add Vigil-Child

---

#### 6. Missing Exact Alarm Permissions (Android 12+)
**Status**: ❌ **NEEDS FIX**

**Problem**: Android 12+ requires explicit permission for exact/repeating alarms.

**Solution**:
```xml
<!-- Add to AndroidManifest.xml -->
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.USE_EXACT_ALARM" />
```

```dart
// Request at runtime
if (await Permission.scheduleExactAlarm.isDenied) {
  await Permission.scheduleExactAlarm.request();
}
```

---

## Testing Recommendations

### Test Scenarios

1. **Doze Mode Test**:
   ```bash
   # Enable Doze immediately
   adb shell dumpsys deviceidle force-idle
   
   # Check logs - your timers should still fire (with delays)
   adb logcat | grep -E "(LocationSync|SmsSync|CallLogSync)"
   
   # Exit Doze
   adb shell dumpsys deviceidle unforce
   ```

2. **App Standby Test**:
   ```bash
   # Put app in standby
   adb shell dumpsys battery unplug
   adb shell am set-inactive com.example.vigil1 true
   
   # Check if service survives
   adb shell dumpsys activity services | grep BackgroundService
   ```

3. **Force Kill Test**:
   ```bash
   # Kill app process
   adb shell am force-stop com.example.vigil1
   
   # Wait 5 minutes, check if service restarts
   adb shell dumpsys activity services | grep BackgroundService
   ```

4. **Extended Background Test**:
   - Install app on physical device
   - Grant all permissions including battery optimization
   - Lock screen and don't touch device for 6+ hours
   - Check backend logs to verify continuous data upload

---

## Priority Action Items

### 🔴 **HIGH PRIORITY** (Do These First)

1. ✅ **DONE**: Add battery optimization exemption request
2. **TODO**: Adjust timer intervals to be more conservative (2-15 minutes)
3. **TODO**: Add WorkManager as backup/fallback mechanism
4. **TODO**: Add exact alarm permissions for Android 12+

### 🟡 **MEDIUM PRIORITY**

5. **TODO**: Implement service restart watchdog
6. **TODO**: Add user guidance for manufacturer-specific battery settings
7. **TODO**: Add telemetry to track service alive time vs expected time

### 🟢 **LOW PRIORITY** (Nice to Have)

8. **TODO**: Add exponential backoff for failed sync attempts
9. **TODO**: Implement queue-based sync for offline scenarios
10. **TODO**: Add admin notification when service stops unexpectedly

---

## Expected Behavior After Fixes

**With all fixes implemented**:
- ✅ Service survives app being swiped away from recent apps
- ✅ Service survives overnight with screen locked
- ✅ Service restarts automatically if killed by system
- ✅ Data uploads continue every few minutes throughout the day
- ⚠️ Some delays during Doze mode (expected Android behavior)
- ⚠️ May still need manual whitelisting on aggressive manufacturers

**Realistic Limitations**:
- Android WILL still throttle/delay operations during deep Doze
- Some data loss is possible if device is off or in airplane mode
- Manufacturer restrictions may require user education/whitelisting

---

## Code Changes Summary

### Files Modified
1. ✅ `lib/main.dart` - Added battery optimization exemption request

### Files That Need Changes
2. ❌ `lib/services/background_services/background_services.dart` - Adjust intervals
3. ❌ `android/app/src/main/AndroidManifest.xml` - Add exact alarm permissions
4. ❌ `pubspec.yaml` - Add workmanager dependency
5. ❌ Create new file: `lib/services/background_services/work_manager_service.dart`

---

## Testing Checklist

Before deploying to production:

- [ ] Test on multiple Android versions (8.0, 10, 12, 13, 14)
- [ ] Test on multiple manufacturers (Samsung, Xiaomi, OnePlus, Google Pixel)
- [ ] Test 24-hour continuous monitoring with screen off
- [ ] Test after force-killing app
- [ ] Test after device reboot
- [ ] Test with airplane mode on/off cycles
- [ ] Test with low battery (< 15%)
- [ ] Verify backend receives data consistently throughout test period

---

## Additional Resources

- [Android Background Execution Limits](https://developer.android.com/about/versions/oreo/background)
- [Doze Mode and App Standby](https://developer.android.com/training/monitoring-device-state/doze-standby)
- [Don't Kill My App](https://dontkillmyapp.com/) - Manufacturer-specific guides
- [WorkManager Documentation](https://developer.android.com/topic/libraries/architecture/workmanager)

---

## Questions?

If you need help implementing any of these fixes, let me know which one you'd like to tackle first.
