# Vigil Child App - Complete API Data Structure
## Frontend to Backend Data Specification

---

## 📋 Table of Contents
1. [Device Information](#1-device-information)
2. [Battery Information](#2-battery-information)
3. [Network & Connectivity](#3-network--connectivity)
4. [Location Data](#4-location-data)
5. [Call Logs](#5-call-logs)
6. [Contacts](#6-contacts)
7. [SMS Messages](#7-sms-messages)
8. [Media & Photos](#8-media--photos)
9. [App Usage Statistics](#9-app-usage-statistics)
10. [Installed Apps](#10-installed-apps)
11. [Permissions Status](#11-permissions-status)
12. [Complete JSON Example](#complete-json-example)

---

## 1. Device Information
**Endpoint:** `POST /api/device-info`

### Request Body:
```json
{
  "childId": "string (required)",
  "timestamp": "ISO 8601 datetime",
  "deviceInfo": {
    "brand": "string",
    "model": "string",
    "manufacturer": "string",
    "device": "string",
    "product": "string",
    "hardware": "string",
    "board": "string",
    "bootloader": "string",
    "androidVersion": "string",
    "sdkInt": "integer",
    "securityPatch": "string",
    "buildId": "string",
    "fingerprint": "string",
    "host": "string",
    "tags": "string",
    "type": "string",
    "isPhysicalDevice": "boolean",
    "supportedAbis": ["string"],
    "display": "string",
    "deviceName": "string"
  }
}
```

### Example:
```json
{
  "childId": "child_123456",
  "timestamp": "2026-05-08T10:30:00Z",
  "deviceInfo": {
    "brand": "Samsung",
    "model": "SM-G998B",
    "manufacturer": "Samsung",
    "device": "p3s",
    "product": "p3sxxx",
    "hardware": "exynos2100",
    "board": "universal2100",
    "bootloader": "G998BXXU5DVJB",
    "androidVersion": "13",
    "sdkInt": 33,
    "securityPatch": "2024-10-01",
    "buildId": "TP1A.220624.014",
    "fingerprint": "samsung/p3sxxx/p3s:13/TP1A.220624.014/G998BXXU5DVJB:user/release-keys",
    "host": "SWDD5723",
    "tags": "release-keys",
    "type": "user",
    "isPhysicalDevice": true,
    "supportedAbis": ["arm64-v8a", "armeabi-v7a", "armeabi"],
    "display": "TP1A.220624.014.G998BXXU5DVJB",
    "deviceName": "Galaxy S21 Ultra"
  }
}
```

---

## 2. Battery Information
**Endpoint:** `POST /api/battery-status`

### Request Body:
```json
{
  "childId": "string (required)",
  "timestamp": "ISO 8601 datetime",
  "batteryInfo": {
    "level": "integer (0-100)",
    "state": "string (charging|discharging|full|unknown)",
    "isInBatterySaveMode": "boolean",
    "temperature": "float (optional)",
    "voltage": "integer (optional)"
  }
}
```

### Example:
```json
{
  "childId": "child_123456",
  "timestamp": "2026-05-08T10:30:00Z",
  "batteryInfo": {
    "level": 75,
    "state": "discharging",
    "isInBatterySaveMode": false,
    "temperature": 32.5,
    "voltage": 3850
  }
}
```

---

## 3. Network & Connectivity
**Endpoint:** `POST /api/connectivity-status`

### Request Body:
```json
{
  "childId": "string (required)",
  "timestamp": "ISO 8601 datetime",
  "connectivity": {
    "connectionType": ["string"],
    "isConnected": "boolean",
    "hasWifi": "boolean",
    "hasMobile": "boolean",
    "hasEthernet": "boolean",
    "hasBluetooth": "boolean",
    "hasVpn": "boolean",
    "wifiInfo": {
      "ssid": "string (optional)",
      "bssid": "string (optional)",
      "ipAddress": "string (optional)",
      "linkSpeed": "integer (optional)"
    }
  }
}
```

### Example:
```json
{
  "childId": "child_123456",
  "timestamp": "2026-05-08T10:30:00Z",
  "connectivity": {
    "connectionType": ["wifi"],
    "isConnected": true,
    "hasWifi": true,
    "hasMobile": false,
    "hasEthernet": false,
    "hasBluetooth": false,
    "hasVpn": false,
    "wifiInfo": {
      "ssid": "Home_WiFi_5G",
      "bssid": "00:11:22:33:44:55",
      "ipAddress": "192.168.1.105",
      "linkSpeed": 866
    }
  }
}
```

---

## 4. Location Data
**Endpoint:** `POST /api/location`

### Request Body:
```json
{
  "childId": "string (required)",
  "timestamp": "ISO 8601 datetime",
  "location": {
    "latitude": "float",
    "longitude": "float",
    "altitude": "float",
    "accuracy": "float (meters)",
    "speed": "float (m/s)",
    "heading": "float (degrees)",
    "timestamp": "ISO 8601 datetime",
    "serviceEnabled": "boolean",
    "permissionStatus": "string"
  }
}
```

### Example:
```json
{
  "childId": "child_123456",
  "timestamp": "2026-05-08T10:30:00Z",
  "location": {
    "latitude": 28.6139,
    "longitude": 77.2090,
    "altitude": 216.5,
    "accuracy": 15.2,
    "speed": 0.0,
    "heading": 0.0,
    "timestamp": "2026-05-08T10:30:00Z",
    "serviceEnabled": true,
    "permissionStatus": "granted"
  }
}
```

---

## 5. Call Logs
**Endpoint:** `POST /api/call-logs`

### Request Body:
```json
{
  "childId": "string (required)",
  "timestamp": "ISO 8601 datetime",
  "callLogs": [
    {
      "name": "string (nullable)",
      "number": "string",
      "formattedNumber": "string (nullable)",
      "callType": "string (incoming|outgoing|missed|rejected|blocked)",
      "duration": "integer (seconds)",
      "timestamp": "integer (milliseconds since epoch)",
      "cachedNumberType": "integer (nullable)",
      "cachedNumberLabel": "string (nullable)",
      "simDisplayName": "string (nullable)"
    }
  ],
  "totalCount": "integer",
  "permissionStatus": "string"
}
```

### Example:
```json
{
  "childId": "child_123456",
  "timestamp": "2026-05-08T10:30:00Z",
  "callLogs": [
    {
      "name": "Mom",
      "number": "+919876543210",
      "formattedNumber": "+91 98765 43210",
      "callType": "incoming",
      "duration": 125,
      "timestamp": 1746694200000,
      "cachedNumberType": 2,
      "cachedNumberLabel": "Mobile",
      "simDisplayName": "SIM 1"
    },
    {
      "name": "Dad",
      "number": "+919876543211",
      "formattedNumber": "+91 98765 43211",
      "callType": "outgoing",
      "duration": 45,
      "timestamp": 1746690600000,
      "cachedNumberType": 2,
      "cachedNumberLabel": "Mobile",
      "simDisplayName": "SIM 1"
    },
    {
      "name": null,
      "number": "+919876543212",
      "formattedNumber": "+91 98765 43212",
      "callType": "missed",
      "duration": 0,
      "timestamp": 1746687000000,
      "cachedNumberType": null,
      "cachedNumberLabel": null,
      "simDisplayName": "SIM 1"
    }
  ],
  "totalCount": 150,
  "permissionStatus": "granted"
}
```

---

## 6. Contacts
**Endpoint:** `POST /api/contacts`

### Request Body:
```json
{
  "childId": "string (required)",
  "timestamp": "ISO 8601 datetime",
  "contacts": [
    {
      "id": "string",
      "displayName": "string",
      "phones": [
        {
          "number": "string",
          "normalizedNumber": "string (nullable)",
          "label": "string (mobile|home|work|other)",
          "isPrimary": "boolean"
        }
      ],
      "emails": [
        {
          "address": "string",
          "label": "string (home|work|other)",
          "isPrimary": "boolean"
        }
      ],
      "name": {
        "first": "string",
        "last": "string",
        "middle": "string (nullable)",
        "prefix": "string (nullable)",
        "suffix": "string (nullable)"
      },
      "photo": "string (base64 or url, optional)",
      "thumbnail": "string (base64 or url, optional)"
    }
  ],
  "totalCount": "integer",
  "permissionStatus": "string"
}
```

### Example:
```json
{
  "childId": "child_123456",
  "timestamp": "2026-05-08T10:30:00Z",
  "contacts": [
    {
      "id": "contact_001",
      "displayName": "John Doe",
      "phones": [
        {
          "number": "+919876543210",
          "normalizedNumber": "+919876543210",
          "label": "mobile",
          "isPrimary": true
        },
        {
          "number": "+911234567890",
          "normalizedNumber": "+911234567890",
          "label": "home",
          "isPrimary": false
        }
      ],
      "emails": [
        {
          "address": "john.doe@example.com",
          "label": "work",
          "isPrimary": true
        }
      ],
      "name": {
        "first": "John",
        "last": "Doe",
        "middle": null,
        "prefix": null,
        "suffix": null
      },
      "photo": null,
      "thumbnail": null
    }
  ],
  "totalCount": 250,
  "permissionStatus": "granted"
}
```

---

## 7. SMS Messages
**Endpoint:** `POST /api/sms-messages`

### Request Body:
```json
{
  "childId": "string (required)",
  "timestamp": "ISO 8601 datetime",
  "messages": [
    {
      "id": "string",
      "threadId": "string",
      "address": "string (phone number)",
      "body": "string",
      "date": "integer (milliseconds since epoch)",
      "dateSent": "integer (milliseconds since epoch)",
      "type": "string (inbox|sent|draft|outbox|failed|queued)",
      "read": "boolean",
      "seen": "boolean",
      "status": "integer",
      "subject": "string (nullable)",
      "serviceCenterAddress": "string (nullable)"
    }
  ],
  "totalCount": "integer",
  "permissionStatus": "string"
}
```

### Example:
```json
{
  "childId": "child_123456",
  "timestamp": "2026-05-08T10:30:00Z",
  "messages": [
    {
      "id": "sms_001",
      "threadId": "thread_001",
      "address": "+919876543210",
      "body": "Hi, how are you?",
      "date": 1746694200000,
      "dateSent": 1746694200000,
      "type": "inbox",
      "read": true,
      "seen": true,
      "status": 0,
      "subject": null,
      "serviceCenterAddress": "+919876543000"
    },
    {
      "id": "sms_002",
      "threadId": "thread_001",
      "address": "+919876543210",
      "body": "I'm good, thanks!",
      "date": 1746694260000,
      "dateSent": 1746694260000,
      "type": "sent",
      "read": true,
      "seen": true,
      "status": 0,
      "subject": null,
      "serviceCenterAddress": null
    }
  ],
  "totalCount": 500,
  "permissionStatus": "granted"
}
```

---

## 8. Media & Photos
**Endpoint:** `POST /api/media-info`

### Request Body:
```json
{
  "childId": "string (required)",
  "timestamp": "ISO 8601 datetime",
  "mediaInfo": {
    "albums": [
      {
        "id": "string",
        "name": "string",
        "assetCount": "integer",
        "isAll": "boolean"
      }
    ],
    "recentAssets": [
      {
        "id": "string",
        "type": "string (image|video|audio)",
        "width": "integer",
        "height": "integer",
        "createDateTime": "ISO 8601 datetime",
        "modifiedDateTime": "ISO 8601 datetime",
        "duration": "integer (seconds, for video/audio)",
        "size": "integer (bytes)",
        "mimeType": "string",
        "title": "string",
        "relativePath": "string",
        "latitude": "float (nullable)",
        "longitude": "float (nullable)"
      }
    ],
    "totalAssets": "integer",
    "permissionStatus": "string"
  }
}
```

### Example:
```json
{
  "childId": "child_123456",
  "timestamp": "2026-05-08T10:30:00Z",
  "mediaInfo": {
    "albums": [
      {
        "id": "album_001",
        "name": "Camera",
        "assetCount": 150,
        "isAll": false
      },
      {
        "id": "album_002",
        "name": "Screenshots",
        "assetCount": 45,
        "isAll": false
      }
    ],
    "recentAssets": [
      {
        "id": "asset_001",
        "type": "image",
        "width": 4032,
        "height": 3024,
        "createDateTime": "2026-05-08T09:15:00Z",
        "modifiedDateTime": "2026-05-08T09:15:00Z",
        "duration": 0,
        "size": 2458624,
        "mimeType": "image/jpeg",
        "title": "IMG_20260508_091500.jpg",
        "relativePath": "DCIM/Camera/",
        "latitude": 28.6139,
        "longitude": 77.2090
      },
      {
        "id": "asset_002",
        "type": "video",
        "width": 1920,
        "height": 1080,
        "createDateTime": "2026-05-07T18:30:00Z",
        "modifiedDateTime": "2026-05-07T18:30:00Z",
        "duration": 45,
        "size": 15728640,
        "mimeType": "video/mp4",
        "title": "VID_20260507_183000.mp4",
        "relativePath": "DCIM/Camera/",
        "latitude": null,
        "longitude": null
      }
    ],
    "totalAssets": 195,
    "permissionStatus": "granted"
  }
}
```

---

## 9. App Usage Statistics
**Endpoint:** `POST /api/app-usage`

### Request Body:
```json
{
  "childId": "string (required)",
  "timestamp": "ISO 8601 datetime",
  "period": {
    "startTime": "ISO 8601 datetime",
    "endTime": "ISO 8601 datetime"
  },
  "appUsage": [
    {
      "packageName": "string",
      "appName": "string (optional)",
      "totalTimeInForeground": "integer (milliseconds)",
      "firstTimeStamp": "integer (milliseconds since epoch)",
      "lastTimeStamp": "integer (milliseconds since epoch)",
      "lastTimeUsed": "integer (milliseconds since epoch)",
      "totalTimesOpened": "integer (optional)"
    }
  ],
  "totalAppsTracked": "integer",
  "permissionStatus": "string"
}
```

### Example:
```json
{
  "childId": "child_123456",
  "timestamp": "2026-05-08T10:30:00Z",
  "period": {
    "startTime": "2026-05-07T10:30:00Z",
    "endTime": "2026-05-08T10:30:00Z"
  },
  "appUsage": [
    {
      "packageName": "com.whatsapp",
      "appName": "WhatsApp",
      "totalTimeInForeground": 3600000,
      "firstTimeStamp": 1746651000000,
      "lastTimeStamp": 1746694200000,
      "lastTimeUsed": 1746694200000,
      "totalTimesOpened": 25
    },
    {
      "packageName": "com.instagram.android",
      "appName": "Instagram",
      "totalTimeInForeground": 2700000,
      "firstTimeStamp": 1746658200000,
      "lastTimeStamp": 1746690600000,
      "lastTimeUsed": 1746690600000,
      "totalTimesOpened": 15
    },
    {
      "packageName": "com.google.android.youtube",
      "appName": "YouTube",
      "totalTimeInForeground": 5400000,
      "firstTimeStamp": 1746654600000,
      "lastTimeStamp": 1746687000000,
      "lastTimeUsed": 1746687000000,
      "totalTimesOpened": 10
    }
  ],
  "totalAppsTracked": 45,
  "permissionStatus": "granted"
}
```

---

## 10. Installed Apps
**Endpoint:** `POST /api/installed-apps`

### Request Body:
```json
{
  "childId": "string (required)",
  "timestamp": "ISO 8601 datetime",
  "installedApps": [
    {
      "packageName": "string",
      "appName": "string",
      "versionName": "string",
      "versionCode": "integer",
      "installTime": "integer (milliseconds since epoch)",
      "updateTime": "integer (milliseconds since epoch)",
      "isSystemApp": "boolean",
      "category": "string (optional)"
    }
  ],
  "totalCount": "integer"
}
```

### Example:
```json
{
  "childId": "child_123456",
  "timestamp": "2026-05-08T10:30:00Z",
  "installedApps": [
    {
      "packageName": "com.whatsapp",
      "appName": "WhatsApp",
      "versionName": "2.24.10.75",
      "versionCode": 242410075,
      "installTime": 1704067200000,
      "updateTime": 1746316800000,
      "isSystemApp": false,
      "category": "communication"
    },
    {
      "packageName": "com.android.chrome",
      "appName": "Chrome",
      "versionName": "122.0.6261.64",
      "versionCode": 626106400,
      "installTime": 1672531200000,
      "updateTime": 1746230400000,
      "isSystemApp": true,
      "category": "browser"
    }
  ],
  "totalCount": 85
}
```

---

## 11. Permissions Status
**Endpoint:** `POST /api/permissions-status`

### Request Body:
```json
{
  "childId": "string (required)",
  "timestamp": "ISO 8601 datetime",
  "permissions": {
    "camera": "string (granted|denied|permanentlyDenied|restricted)",
    "microphone": "string",
    "location": "string",
    "locationAlways": "string",
    "phone": "string",
    "contacts": "string",
    "sms": "string",
    "storage": "string",
    "photos": "string",
    "notification": "string",
    "bluetoothScan": "string",
    "activityRecognition": "string",
    "ignoreBatteryOptimizations": "string",
    "accessibility": "boolean",
    "deviceAdmin": "boolean",
    "usageStats": "boolean",
    "overlayPermission": "boolean"
  }
}
```

### Example:
```json
{
  "childId": "child_123456",
  "timestamp": "2026-05-08T10:30:00Z",
  "permissions": {
    "camera": "granted",
    "microphone": "granted",
    "location": "granted",
    "locationAlways": "granted",
    "phone": "granted",
    "contacts": "granted",
    "sms": "granted",
    "storage": "granted",
    "photos": "granted",
    "notification": "granted",
    "bluetoothScan": "denied",
    "activityRecognition": "granted",
    "ignoreBatteryOptimizations": "granted",
    "accessibility": true,
    "deviceAdmin": true,
    "usageStats": true,
    "overlayPermission": false
  }
}
```

---

## Complete JSON Example
### Full Monitoring Data Payload
**Endpoint:** `POST /api/monitoring-data/bulk`

```json
{
  "childId": "child_123456",
  "timestamp": "2026-05-08T10:30:00Z",
  "dataVersion": "1.0",
  "deviceInfo": {
    "brand": "Samsung",
    "model": "SM-G998B",
    "manufacturer": "Samsung",
    "androidVersion": "13",
    "sdkInt": 33,
    "isPhysicalDevice": true,
    "deviceName": "Galaxy S21 Ultra"
  },
  "batteryInfo": {
    "level": 75,
    "state": "discharging",
    "isInBatterySaveMode": false
  },
  "connectivity": {
    "connectionType": ["wifi"],
    "isConnected": true,
    "hasWifi": true
  },
  "location": {
    "latitude": 28.6139,
    "longitude": 77.2090,
    "accuracy": 15.2,
    "timestamp": "2026-05-08T10:30:00Z"
  },
  "callLogs": {
    "logs": [],
    "totalCount": 150,
    "permissionStatus": "granted"
  },
  "contacts": {
    "contacts": [],
    "totalCount": 250,
    "permissionStatus": "granted"
  },
  "smsMessages": {
    "messages": [],
    "totalCount": 500,
    "permissionStatus": "granted"
  },
  "mediaInfo": {
    "totalAssets": 195,
    "permissionStatus": "granted"
  },
  "appUsage": {
    "usage": [],
    "totalAppsTracked": 45,
    "permissionStatus": "granted"
  },
  "installedApps": {
    "apps": [],
    "totalCount": 85
  },
  "permissions": {
    "camera": "granted",
    "location": "granted",
    "contacts": "granted",
    "sms": "granted",
    "phone": "granted",
    "storage": "granted",
    "usageStats": true,
    "accessibility": true,
    "deviceAdmin": true
  }
}
```

---


---



### Success Response:
```json
{
  "success": true,
  "message": "Data received successfully",
  "timestamp": "2026-05-08T10:30:00Z",
  "dataId": "data_123456"
}
```

### Error Response:
```json
{
  "success": false,
  "error": {
    "code": "INVALID_DATA",
    "message": "Invalid childId provided",
    "details": {}
  },
  "timestamp": "2026-05-08T10:30:00Z"
}
```

---

## 🔄 Batch Upload Support

For offline scenarios, support batch uploads:

**Endpoint:** `POST /api/monitoring-data/batch`

```json
{
  "childId": "child_123456",
  "batchId": "batch_789",
  "items": [
    {
      "type": "location",
      "timestamp": "2026-05-08T10:00:00Z",
      "data": { /* location data */ }
    },
    {
      "type": "callLog",
      "timestamp": "2026-05-08T10:15:00Z",
      "data": { /* call log data */ }
    }
  ]
}
```

---


