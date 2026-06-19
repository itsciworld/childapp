# Location Tracking Debug Guide

## Changes Made to Fix Background Location

### 1. AndroidManifest.xml
- ✅ Added `FOREGROUND_SERVICE_LOCATION` permission for Android 14+
- ✅ Changed service type to `location|specialUse`

### 2. Location Repository
- ✅ Changed accuracy: `high` → `medium` (better for background)
- ✅ Increased timeout: 12s → 20s
- ✅ Added `distanceFilter: 100m`
- ✅ Added `forceAndroidLocationManager: true`

### 3. Location Sync Service
- ✅ Reduced distance threshold: 150m → 100m
- ✅ Reduced heartbeat time: 15 mins → 10 mins
- ✅ Added detailed debug logs

### 4. Background Service
- ✅ Reduced check interval: 6 mins → 2 mins
- ✅ Added timer tick logs

## How to Test

### Step 1: Build Fresh APK
```bash
cd /Users/apple/Documents/vigil/vigil-child-app-main
flutter clean
flutter pub get
flutter build apk --release
```

### Step 2: Install on Device
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Step 3: Watch Logs
```bash
# In terminal, run this command:
adb logcat | grep -E "\[location\]|\[LocationSync\]|\[LocationRepo\]"
```

## What You'll See in Logs

### Every 2 Minutes (Timer Tick):
```
[location] ⏰ Timer tick - starting sync
[location] 👑 Leadership claimed, executing sync
[LocationSync] ━━━━━━ SYNC STARTED at 14:25:30 ━━━━━━
[LocationSync] Identity OK: childId=123, parentId=456
[LocationRepo] got fresh position: (31.5204, 74.3587)
[LocationSync] Position obtained: (31.5204, 74.3587)
[LocationSync] Last sent location: (31.5203, 74.3586)
[LocationSync] Last sent time: 3 mins ago
[LocationSync] Check: Distance moved: 12.5m, Time since last upload: 3 mins, Threshold: 100m / 10 mins
```

### When Location Skipped (Not Moved Enough):
```
[LocationSync] ❌ SKIPPED: Distance 12.5m < 100m AND time 3mins < 10mins
[location] ✓ Sync completed, ready for next tick
```

### When Location Sent (Distance Reason):
```
[LocationSync] Check: Distance moved: 125.7m, Time since last upload: 5 mins, Threshold: 100m / 10 mins
[LocationSync] ✅ UPLOADING LOCATION - Reason: DISTANCE_CHANGED (moved 125.7m)
[LocationRepo] store_location response (200): {"status":200,"message":"Location saved."}
[LocationSync] ✅ SUCCESS: Location sent (31.5213, 74.3598) "Mall Road, Gulberg..." | Reason: DISTANCE_CHANGED (moved 125.7m) | API Response: 200 ("Location saved.")
```

### When Location Sent (Time/Heartbeat Reason):
```
[LocationSync] Check: Distance moved: 25.1m, Time since last upload: 11 mins, Threshold: 100m / 10 mins
[LocationSync] ✅ UPLOADING LOCATION - Reason: HEARTBEAT_TIME (11mins passed)
[LocationRepo] store_location response (200): {"status":200,"message":"Location saved."}
[LocationSync] ✅ SUCCESS: Location sent (31.5204, 74.3587) "Mall Road..." | Reason: HEARTBEAT_TIME (11mins passed) | API Response: 200 ("Location saved.")
```

## Upload Triggers

Location will be sent when:
1. **Distance Trigger**: Device moves 100+ meters from last sent location
2. **Time Trigger**: 10+ minutes passed since last upload (heartbeat)
3. **Both**: Either condition is satisfied

## Current Settings

| Setting | Value |
|---------|-------|
| Location check interval | 2 minutes |
| Distance threshold | 100 meters |
| Heartbeat time | 10 minutes |
| Location accuracy | Medium (~100m precision) |
| GPS timeout | 20 seconds |

## Troubleshooting

### If No Logs Appear:
1. Check if background service is running
2. Verify battery optimization is disabled
3. Ensure location permission is "Allow all the time"
4. Check if location services are enabled

### If Location Not Sending:
1. Check logs for "SKIPPED" reason
2. Verify distance moved is > 100m
3. Confirm 10+ minutes have passed
4. Check for "NO POSITION" errors

### If Position is NULL:
1. Location services might be OFF
2. Location permission not granted
3. GPS signal weak (try outdoors)

## Device Settings Required

1. **Location Permission**: Allow all the time (not just while using)
2. **Battery Optimization**: Disabled for Vigil-Child app
3. **Location Services**: Enabled
4. **Location Mode**: High accuracy (GPS + WiFi + Mobile)
5. **Background App Refresh**: Enabled

## Test Scenarios

### Test 1: Stationary Device
- Keep device in one place
- Should send location every 10 minutes (heartbeat)
- Check logs for "HEARTBEAT_TIME"

### Test 2: Moving Device
- Move 200+ meters (clearly above 100m threshold)
- Should send location immediately
- Check logs for "DISTANCE_CHANGED"

### Test 3: Background Mode
- Send app to background
- Keep device moving
- Should continue sending location updates
- Check logs every 2 minutes for timer ticks
