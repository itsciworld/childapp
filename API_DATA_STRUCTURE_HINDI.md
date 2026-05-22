# Vigil Child App - Complete API Data Structure (हिंदी में)
## Frontend से Backend में भेजे जाने वाला पूरा Data

---

## 📱 हम क्या-क्या Data भेज सकते हैं?

### 1. **Device की जानकारी (Device Information)**
```json
{
  "childId": "child_123456",
  "timestamp": "2026-05-08T10:30:00Z",
  "deviceInfo": {
    "brand": "Samsung",                    // फोन की कंपनी
    "model": "SM-G998B",                   // फोन का मॉडल
    "manufacturer": "Samsung",             // बनाने वाली कंपनी
    "androidVersion": "13",                // Android version
    "sdkInt": 33,                          // SDK level
    "securityPatch": "2024-10-01",        // Security patch date
    "isPhysicalDevice": true,              // असली फोन है या emulator
    "deviceName": "Galaxy S21 Ultra"       // फोन का नाम
  }
}
```

**API Endpoint:** `POST /api/device-info`

---

### 2. **Battery की जानकारी (Battery Information)**
```json
{
  "childId": "child_123456",
  "timestamp": "2026-05-08T10:30:00Z",
  "batteryInfo": {
    "level": 75,                           // Battery % (0-100)
    "state": "discharging",                // charging, discharging, full
    "isInBatterySaveMode": false,          // Battery saver on/off
    "temperature": 32.5,                   // Temperature (optional)
    "voltage": 3850                        // Voltage (optional)
  }
}
```

**API Endpoint:** `POST /api/battery-status`

**कब भेजें:** हर 30 मिनट में

---

### 3. **Internet Connection की जानकारी (Connectivity)**
```json
{
  "childId": "child_123456",
  "timestamp": "2026-05-08T10:30:00Z",
  "connectivity": {
    "connectionType": ["wifi"],            // wifi, mobile, ethernet, vpn
    "isConnected": true,                   // Internet connected है या नहीं
    "hasWifi": true,                       // WiFi on है
    "hasMobile": false,                    // Mobile data on है
    "hasVpn": false,                       // VPN चल रहा है
    "wifiInfo": {
      "ssid": "Home_WiFi_5G",             // WiFi का नाम
      "ipAddress": "192.168.1.105",       // IP address
      "linkSpeed": 866                     // Speed (Mbps)
    }
  }
}
```

**API Endpoint:** `POST /api/connectivity-status`

---

### 4. **Location की जानकारी (GPS Location)**
```json
{
  "childId": "child_123456",
  "timestamp": "2026-05-08T10:30:00Z",
  "location": {
    "latitude": 28.6139,                   // Latitude (अक्षांश)
    "longitude": 77.2090,                  // Longitude (देशांतर)
    "altitude": 216.5,                     // ऊंचाई (meters)
    "accuracy": 15.2,                      // Accuracy (meters में)
    "speed": 0.0,                          // Speed (m/s)
    "heading": 0.0,                        // Direction (degrees)
    "timestamp": "2026-05-08T10:30:00Z",
    "serviceEnabled": true,                // GPS on है
    "permissionStatus": "granted"          // Permission मिली है
  }
}
```

**API Endpoint:** `POST /api/location`

**कब भेजें:** हर 5-15 मिनट में (बहुत important)

---

### 5. **Call Logs (कॉल की जानकारी)**
```json
{
  "childId": "child_123456",
  "timestamp": "2026-05-08T10:30:00Z",
  "callLogs": [
    {
      "name": "Mom",                       // Contact का नाम
      "number": "+919876543210",           // Phone number
      "callType": "incoming",              // incoming, outgoing, missed
      "duration": 125,                     // कॉल की लंबाई (seconds में)
      "timestamp": 1746694200000,          // कब हुई (milliseconds)
      "simDisplayName": "SIM 1"            // कौन सी SIM से
    },
    {
      "name": "Dad",
      "number": "+919876543211",
      "callType": "outgoing",
      "duration": 45,
      "timestamp": 1746690600000,
      "simDisplayName": "SIM 1"
    },
    {
      "name": null,                        // Unknown number
      "number": "+919876543212",
      "callType": "missed",                // Missed call
      "duration": 0,
      "timestamp": 1746687000000,
      "simDisplayName": "SIM 1"
    }
  ],
  "totalCount": 150,                       // कुल कितनी calls हैं
  "permissionStatus": "granted"
}
```

**API Endpoint:** `POST /api/call-logs`

**कब भेजें:** Real-time + हर 1 घंटे में

**Call Types:**
- `incoming` - आने वाली call
- `outgoing` - जाने वाली call
- `missed` - छूटी हुई call
- `rejected` - काटी गई call
- `blocked` - Block की गई call

---

### 6. **Contacts (संपर्क सूची)**
```json
{
  "childId": "child_123456",
  "timestamp": "2026-05-08T10:30:00Z",
  "contacts": [
    {
      "id": "contact_001",
      "displayName": "John Doe",           // नाम
      "phones": [
        {
          "number": "+919876543210",       // Phone number
          "label": "mobile",               // mobile, home, work
          "isPrimary": true                // Main number है
        },
        {
          "number": "+911234567890",
          "label": "home",
          "isPrimary": false
        }
      ],
      "emails": [
        {
          "address": "john.doe@example.com",  // Email
          "label": "work",
          "isPrimary": true
        }
      ],
      "name": {
        "first": "John",                   // पहला नाम
        "last": "Doe",                     // अंतिम नाम
        "middle": null
      }
    }
  ],
  "totalCount": 250,                       // कुल contacts
  "permissionStatus": "granted"
}
```

**API Endpoint:** `POST /api/contacts`

**कब भेजें:** रोज़ एक बार या जब change हो

---

### 7. **SMS Messages (संदेश)**
```json
{
  "childId": "child_123456",
  "timestamp": "2026-05-08T10:30:00Z",
  "messages": [
    {
      "id": "sms_001",
      "threadId": "thread_001",            // Conversation ID
      "address": "+919876543210",          // किससे आया/गया
      "body": "Hi, how are you?",          // Message का text
      "date": 1746694200000,               // कब आया (milliseconds)
      "type": "inbox",                     // inbox, sent, draft
      "read": true,                        // पढ़ा गया है
      "seen": true                         // देखा गया है
    },
    {
      "id": "sms_002",
      "threadId": "thread_001",
      "address": "+919876543210",
      "body": "I'm good, thanks!",
      "date": 1746694260000,
      "type": "sent",                      // भेजा गया message
      "read": true,
      "seen": true
    }
  ],
  "totalCount": 500,                       // कुल messages
  "permissionStatus": "granted"
}
```

**API Endpoint:** `POST /api/sms-messages`

**कब भेजें:** Real-time + हर 1 घंटे में

**Message Types:**
- `inbox` - आने वाले messages
- `sent` - भेजे गए messages
- `draft` - Draft messages
- `outbox` - भेजे जा रहे messages
- `failed` - नहीं भेजे गए

---

### 8. **Photos & Videos (तस्वीरें और वीडियो)**
```json
{
  "childId": "child_123456",
  "timestamp": "2026-05-08T10:30:00Z",
  "mediaInfo": {
    "albums": [
      {
        "id": "album_001",
        "name": "Camera",                  // Album का नाम
        "assetCount": 150                  // कितनी files हैं
      },
      {
        "id": "album_002",
        "name": "Screenshots",
        "assetCount": 45
      }
    ],
    "recentAssets": [
      {
        "id": "asset_001",
        "type": "image",                   // image, video, audio
        "width": 4032,                     // Width (pixels)
        "height": 3024,                    // Height (pixels)
        "createDateTime": "2026-05-08T09:15:00Z",  // कब बनाई
        "size": 2458624,                   // Size (bytes)
        "mimeType": "image/jpeg",          // File type
        "title": "IMG_20260508_091500.jpg",
        "latitude": 28.6139,               // कहाँ ली गई (optional)
        "longitude": 77.2090
      },
      {
        "id": "asset_002",
        "type": "video",
        "width": 1920,
        "height": 1080,
        "duration": 45,                    // Video की लंबाई (seconds)
        "size": 15728640,
        "mimeType": "video/mp4",
        "title": "VID_20260507_183000.mp4"
      }
    ],
    "totalAssets": 195,                    // कुल files
    "permissionStatus": "granted"
  }
}
```

**API Endpoint:** `POST /api/media-info`

**कब भेजें:** रोज़ एक बार

---

### 9. **App Usage (ऐप का इस्तेमाल)**
```json
{
  "childId": "child_123456",
  "timestamp": "2026-05-08T10:30:00Z",
  "period": {
    "startTime": "2026-05-07T10:30:00Z",  // कब से
    "endTime": "2026-05-08T10:30:00Z"     // कब तक
  },
  "appUsage": [
    {
      "packageName": "com.whatsapp",
      "appName": "WhatsApp",               // App का नाम
      "totalTimeInForeground": 3600000,    // कितनी देर चलाया (milliseconds)
      "firstTimeStamp": 1746651000000,     // पहली बार कब खोला
      "lastTimeStamp": 1746694200000,      // आखिरी बार कब खोला
      "totalTimesOpened": 25               // कितनी बार खोला
    },
    {
      "packageName": "com.instagram.android",
      "appName": "Instagram",
      "totalTimeInForeground": 2700000,    // 45 minutes
      "firstTimeStamp": 1746658200000,
      "lastTimeStamp": 1746690600000,
      "totalTimesOpened": 15
    },
    {
      "packageName": "com.google.android.youtube",
      "appName": "YouTube",
      "totalTimeInForeground": 5400000,    // 90 minutes
      "firstTimeStamp": 1746654600000,
      "lastTimeStamp": 1746687000000,
      "totalTimesOpened": 10
    }
  ],
  "totalAppsTracked": 45,                  // कुल apps track किए
  "permissionStatus": "granted"
}
```

**API Endpoint:** `POST /api/app-usage`

**कब भेजें:** हर 6-12 घंटे में

**Time Conversion:**
- 3600000 milliseconds = 60 minutes = 1 hour
- 2700000 milliseconds = 45 minutes
- 5400000 milliseconds = 90 minutes

---

### 10. **Installed Apps (इंस्टॉल किए गए Apps)**
```json
{
  "childId": "child_123456",
  "timestamp": "2026-05-08T10:30:00Z",
  "installedApps": [
    {
      "packageName": "com.whatsapp",
      "appName": "WhatsApp",               // App का नाम
      "versionName": "2.24.10.75",         // Version
      "versionCode": 242410075,
      "installTime": 1704067200000,        // कब install किया
      "updateTime": 1746316800000,         // कब update किया
      "isSystemApp": false,                // System app है या नहीं
      "category": "communication"          // Category
    },
    {
      "packageName": "com.android.chrome",
      "appName": "Chrome",
      "versionName": "122.0.6261.64",
      "installTime": 1672531200000,
      "updateTime": 1746230400000,
      "isSystemApp": true,                 // Pre-installed app
      "category": "browser"
    }
  ],
  "totalCount": 85                         // कुल apps
}
```

**API Endpoint:** `POST /api/installed-apps`

**कब भेजें:** रोज़ एक बार या जब नया app install हो

**Categories:**
- `communication` - WhatsApp, Telegram
- `social` - Instagram, Facebook
- `entertainment` - YouTube, Netflix
- `games` - PUBG, Free Fire
- `education` - Duolingo, Khan Academy
- `browser` - Chrome, Firefox
- `productivity` - Gmail, Calendar

---

### 11. **Permissions Status (अनुमतियाँ)**
```json
{
  "childId": "child_123456",
  "timestamp": "2026-05-08T10:30:00Z",
  "permissions": {
    "camera": "granted",                   // Camera की permission
    "microphone": "granted",               // Microphone की permission
    "location": "granted",                 // Location की permission
    "locationAlways": "granted",           // हमेशा location
    "phone": "granted",                    // Call logs की permission
    "contacts": "granted",                 // Contacts की permission
    "sms": "granted",                      // SMS की permission
    "storage": "granted",                  // Storage की permission
    "photos": "granted",                   // Photos की permission
    "notification": "granted",             // Notifications की permission
    "bluetoothScan": "denied",             // Bluetooth (denied)
    "activityRecognition": "granted",      // Activity tracking
    "ignoreBatteryOptimizations": "granted", // Battery optimization
    "accessibility": true,                 // Accessibility service
    "deviceAdmin": true,                   // Device admin
    "usageStats": true,                    // Usage stats
    "overlayPermission": false             // Screen overlay
  }
}
```

**API Endpoint:** `POST /api/permissions-status`

**कब भेजें:** रोज़ एक बार या जब permission change हो

**Permission Status:**
- `granted` - मिल गई है
- `denied` - नहीं मिली
- `permanentlyDenied` - हमेशा के लिए deny
- `restricted` - Restricted है

---

## 📊 कितनी बार Data भेजें? (Sync Frequency)

| Data Type | कितनी बार भेजें | Priority |
|-----------|-----------------|----------|
| Location (GPS) | हर 5-15 मिनट | बहुत ज़रूरी |
| Battery Status | हर 30 मिनट | ज़रूरी |
| Call Logs | Real-time + हर 1 घंटे | बहुत ज़रूरी |
| SMS Messages | Real-time + हर 1 घंटे | बहुत ज़रूरी |
| App Usage | हर 6-12 घंटे | ज़रूरी |
| Contacts | रोज़ एक बार | कम ज़रूरी |
| Installed Apps | रोज़ एक बार | कम ज़रूरी |
| Device Info | App start पर + रोज़ | कम ज़रूरी |
| Permissions | जब change हो + रोज़ | ज़रूरी |
| Photos/Media | रोज़ एक बार | कम ज़रूरी |

---

## 🔄 Bulk Upload (एक साथ सब भेजना)

अगर Internet नहीं है, तो बाद में सब एक साथ भेज सकते हैं:

**API Endpoint:** `POST /api/monitoring-data/batch`

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
    },
    {
      "type": "sms",
      "timestamp": "2026-05-08T10:30:00Z",
      "data": { /* sms data */ }
    }
  ]
}
```

---

## ✅ Success Response (सफल होने पर)

```json
{
  "success": true,
  "message": "Data सफलतापूर्वक मिल गया",
  "timestamp": "2026-05-08T10:30:00Z",
  "dataId": "data_123456"
}
```

---

## ❌ Error Response (गलती होने पर)

```json
{
  "success": false,
  "error": {
    "code": "INVALID_DATA",
    "message": "childId गलत है",
    "details": {}
  },
  "timestamp": "2026-05-08T10:30:00Z"
}
```

---

## 🔐 Security (सुरक्षा)

1. **HTTPS** - सभी data encrypted भेजें
2. **JWT Token** - Authentication के लिए
3. **Data Compression** - बड़े data को compress करें (gzip)
4. **Rate Limiting** - बहुत ज़्यादा requests न भेजें
5. **Sensitive Data** - Phone numbers को hash करें

---

## 📝 Important Notes (ज़रूरी बातें)

### 1. **Timestamp Format**
सभी timestamps ISO 8601 format में:
```
2026-05-08T10:30:00Z
```

### 2. **Milliseconds to Date**
```javascript
// JavaScript में convert करना
const date = new Date(1746694200000);
console.log(date); // 2026-05-08T10:30:00Z
```

### 3. **Time Calculations**
```
1 second = 1000 milliseconds
1 minute = 60000 milliseconds
1 hour = 3600000 milliseconds
1 day = 86400000 milliseconds
```

### 4. **Data Size**
- छोटा data: < 100 KB
- मध्यम data: 100 KB - 1 MB
- बड़ा data: > 1 MB (compress करें)

---

## 🎯 Backend Developer को क्या बताएं?

1. **ये सभी endpoints बनाने होंगे**
2. **Database में ये सभी fields store करने होंगे**
3. **Real-time data के लिए WebSocket या Firebase use करें**
4. **Bulk upload support ज़रूरी है (offline mode के लिए)**
5. **Data को compress करके भेजें (gzip)**
6. **Authentication JWT token से करें**
7. **Rate limiting लगाएं (spam से बचने के लिए)**

---

## 📞 Questions?

अगर कोई doubt है तो पूछ सकते हैं!

**यह document अपने backend developer को दे दें। सब कुछ detail में है!** 🚀
