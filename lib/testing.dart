// ─────────────────────────────────────────────
//  DATA MODELS
// ─────────────────────────────────────────────
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:call_log/call_log.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:geolocator/geolocator.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usage_stats/usage_stats.dart';

class InfoSection {
  final String title;
  final String packageName;
  final IconData icon;
  final Color color;
  final List<InfoItem> items;
  final bool hasError;
  final String? errorMsg;

  const InfoSection({
    required this.title,
    required this.packageName,
    required this.icon,
    required this.color,
    required this.items,
    this.hasError = false,
    this.errorMsg,
  });
}

class InfoItem {
  final String key;
  final String value;
  const InfoItem(this.key, this.value);
}

// ─────────────────────────────────────────────
//  MAIN SCREEN
// ─────────────────────────────────────────────
class DeviceInfoScreen extends StatefulWidget {
  const DeviceInfoScreen({super.key});
  @override
  State<DeviceInfoScreen> createState() => _DeviceInfoScreenState();
}

class _DeviceInfoScreenState extends State<DeviceInfoScreen>
    with TickerProviderStateMixin {
  List<InfoSection> _sections = [];
  bool _loading = true;
  String _loadingMsg = 'Initializing...';
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _loadAll();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _log(String msg) {
    debugPrint('[DeviceInspector] $msg');
    setState(() => _loadingMsg = msg);
  }

  Future<void> _loadAll() async {
    final sections = <InfoSection>[];

    debugPrint('\n\n');
    debugPrint('╔═══════════════════════════════════════════════════════════╗');
    debugPrint('║         VIGIL DEVICE INSPECTOR - DATA COLLECTION          ║');
    debugPrint('║              Starting Comprehensive Scan...               ║');
    debugPrint('╚═══════════════════════════════════════════════════════════╝');
    debugPrint('\n');

    // 1. DEVICE INFO
    _log('📱 Fetching device info...');
    sections.add(await _getDeviceInfo());

    // 2. BATTERY
    _log('🔋 Fetching battery info...');
    sections.add(await _getBatteryInfo());

    // 3. CONNECTIVITY
    _log('🌐 Fetching connectivity info...');
    sections.add(await _getConnectivityInfo());

    // 4. LOCATION
    _log('📍 Fetching GPS location...');
    sections.add(await _getLocationInfo());

    // 5. CALL LOGS
    _log('📞 Fetching call logs...');
    sections.add(await _getCallLogs());

    // 6. CONTACTS
    _log('👥 Fetching contacts...');
    sections.add(await _getContacts());

    // 7. SMS
    _log('💬 Fetching SMS inbox...');
    sections.add(await _getSmsInfo());

    // 8. PHOTOS / MEDIA
    _log('🖼️ Fetching media info...');
    sections.add(await _getPhotoInfo());

    // 9. USAGE STATS
    _log('📊 Fetching app usage stats...');
    sections.add(await _getUsageStats());

    // 10. APP INFO (package_info_plus)
    _log('📦 Fetching app/package info...');
    sections.add(await _getAppInfo());

    // 11. SHARED PREFERENCES (demo)
    _log('💾 Reading shared preferences...');
    sections.add(await _getSharedPrefs());

    // 12. PERMISSIONS STATUS
    _log('🔐 Checking all permissions...');
    sections.add(await _getPermissions());

    debugPrint('\n');
    debugPrint('╔═══════════════════════════════════════════════════════════╗');
    debugPrint('║              DATA COLLECTION COMPLETED ✅                  ║');
    debugPrint('╚═══════════════════════════════════════════════════════════╝');
    debugPrint('\n📊 SUMMARY:');
    debugPrint('   Total Sections Collected: ${sections.length}');
    int totalItems = 0;
    int errorSections = 0;
    for (final section in sections) {
      totalItems += section.items.length;
      if (section.hasError) errorSections++;
      debugPrint(
          '   ✓ ${section.title}: ${section.items.length} items ${section.hasError ? '(ERROR)' : ''}');
    }
    debugPrint('\n   Total Data Points: $totalItems');
    debugPrint('   Sections with Errors: $errorSections');
    debugPrint(
        '   Success Rate: ${((sections.length - errorSections) / sections.length * 100).toStringAsFixed(1)}%');
    debugPrint(
        '\n═══════════════════════════════════════════════════════════\n\n');

    setState(() {
      _sections = sections;
      _loading = false;
    });
  }

  // ── 1. DEVICE INFO ──────────────────────────
  Future<InfoSection> _getDeviceInfo() async {
    try {
      final plugin = DeviceInfoPlugin();
      final items = <InfoItem>[];

      debugPrint('\n═══════════════════════════════════════════');
      debugPrint('📱 DEVICE INFORMATION');
      debugPrint('═══════════════════════════════════════════');

      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        debugPrint('Brand: ${info.brand}');
        debugPrint('Model: ${info.model}');
        debugPrint('Manufacturer: ${info.manufacturer}');
        debugPrint('Device: ${info.device}');
        debugPrint('Product: ${info.product}');
        debugPrint('Hardware: ${info.hardware}');
        debugPrint('Android Version: ${info.version.release}');
        debugPrint('SDK Int: ${info.version.sdkInt}');
        debugPrint('Security Patch: ${info.version.securityPatch ?? 'N/A'}');
        debugPrint('Build ID: ${info.id}');
        debugPrint('Fingerprint: ${info.fingerprint}');
        debugPrint('Is Physical Device: ${info.isPhysicalDevice}');
        debugPrint('Supported ABIs: ${info.supportedAbis.join(', ')}');

        items.addAll([
          InfoItem('Brand', info.brand),
          InfoItem('Model', info.model),
          InfoItem('Manufacturer', info.manufacturer),
          InfoItem('Device', info.device),
          InfoItem('Product', info.product),
          InfoItem('Hardware', info.hardware),
          InfoItem('Board', info.board),
          InfoItem('Bootloader', info.bootloader),
          InfoItem('Android Version', info.version.release),
          InfoItem('SDK Int', info.version.sdkInt.toString()),
          InfoItem('Security Patch', info.version.securityPatch ?? 'N/A'),
          InfoItem('Build ID', info.id),
          InfoItem('Fingerprint', info.fingerprint),
          InfoItem('Host', info.host),
          InfoItem('Tags', info.tags),
          InfoItem('Type', info.type),
          InfoItem('Is Physical Device', info.isPhysicalDevice.toString()),
          InfoItem('Supported ABIs', info.supportedAbis.join(', ')),
          InfoItem('Display', info.display),
        ]);
      } else if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        debugPrint('Name: ${info.name}');
        debugPrint('Model: ${info.model}');
        debugPrint('System Name: ${info.systemName}');
        debugPrint('System Version: ${info.systemVersion}');
        debugPrint('Identifier: ${info.identifierForVendor ?? 'N/A'}');
        debugPrint('Is Physical Device: ${info.isPhysicalDevice}');

        items.addAll([
          InfoItem('Name', info.name),
          InfoItem('Model', info.model),
          InfoItem('System Name', info.systemName),
          InfoItem('System Version', info.systemVersion),
          InfoItem('Identifier', info.identifierForVendor ?? 'N/A'),
          InfoItem('Is Physical Device', info.isPhysicalDevice.toString()),
          InfoItem('utsname.machine', info.utsname.machine),
          InfoItem('utsname.sysname', info.utsname.sysname),
          InfoItem('utsname.nodename', info.utsname.nodename),
          InfoItem('utsname.release', info.utsname.release),
          InfoItem('utsname.version', info.utsname.version),
        ]);
      }
      debugPrint('═══════════════════════════════════════════\n');

      return InfoSection(
        title: 'Device Information',
        packageName: 'device_info_plus',
        icon: Icons.phone_android,
        color: const Color(0xFF00E5FF),
        items: items,
      );
    } catch (e) {
      debugPrint('❌ ERROR getting device info: $e');
      return _errorSection('Device Information', 'device_info_plus',
          Icons.phone_android, const Color(0xFF00E5FF), e);
    }
  }

  // ── 2. BATTERY ──────────────────────────────
  Future<InfoSection> _getBatteryInfo() async {
    try {
      debugPrint('\n═══════════════════════════════════════════');
      debugPrint('🔋 BATTERY INFORMATION');
      debugPrint('═══════════════════════════════════════════');

      final battery = Battery();
      final level = await battery.batteryLevel;
      final state = await battery.batteryState;
      final isInBatterySaveMode = await battery.isInBatterySaveMode;

      debugPrint('Battery Level: $level%');
      debugPrint('Battery State: ${state.name.toUpperCase()}');
      debugPrint('Battery Save Mode: $isInBatterySaveMode');
      debugPrint('═══════════════════════════════════════════\n');

      return InfoSection(
        title: 'Battery',
        packageName: 'battery_plus',
        icon: Icons.battery_charging_full,
        color: const Color(0xFF69FF47),
        items: [
          InfoItem('Battery Level', '$level%'),
          InfoItem('Battery State', state.name.toUpperCase()),
          InfoItem('Battery Save Mode', isInBatterySaveMode.toString()),
        ],
      );
    } catch (e) {
      debugPrint('❌ ERROR getting battery info: $e');
      return _errorSection('Battery', 'battery_plus',
          Icons.battery_charging_full, const Color(0xFF69FF47), e);
    }
  }

  // ── 3. CONNECTIVITY ─────────────────────────
  Future<InfoSection> _getConnectivityInfo() async {
    try {
      final connectivity = Connectivity();
      final results = await connectivity.checkConnectivity();
      return InfoSection(
        title: 'Connectivity',
        packageName: 'connectivity_plus',
        icon: Icons.wifi,
        color: const Color(0xFF7B61FF),
        items: [
          InfoItem('Connection Type',
              results.map((r) => r.name.toUpperCase()).join(', ')),
          InfoItem('Is Connected',
              results.contains(ConnectivityResult.none) ? 'NO' : 'YES'),
          InfoItem('Has WiFi',
              results.contains(ConnectivityResult.wifi) ? 'YES' : 'NO'),
          InfoItem('Has Mobile',
              results.contains(ConnectivityResult.mobile) ? 'YES' : 'NO'),
          InfoItem('Has Ethernet',
              results.contains(ConnectivityResult.ethernet) ? 'YES' : 'NO'),
          InfoItem('Has Bluetooth',
              results.contains(ConnectivityResult.bluetooth) ? 'YES' : 'NO'),
          InfoItem('Has VPN',
              results.contains(ConnectivityResult.vpn) ? 'YES' : 'NO'),
        ],
      );
    } catch (e) {
      return _errorSection('Connectivity', 'connectivity_plus', Icons.wifi,
          const Color(0xFF7B61FF), e);
    }
  }

  // ── 4. LOCATION ─────────────────────────────
  Future<InfoSection> _getLocationInfo() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission perm = await Geolocator.checkPermission();

      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      final items = <InfoItem>[
        InfoItem('Service Enabled', serviceEnabled.toString()),
        InfoItem('Permission', perm.name.toUpperCase()),
      ];

      if (serviceEnabled &&
          perm != LocationPermission.denied &&
          perm != LocationPermission.deniedForever) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
        items.addAll([
          InfoItem('Latitude', pos.latitude.toStringAsFixed(6)),
          InfoItem('Longitude', pos.longitude.toStringAsFixed(6)),
          InfoItem('Altitude', '${pos.altitude.toStringAsFixed(1)} m'),
          InfoItem('Accuracy', '${pos.accuracy.toStringAsFixed(1)} m'),
          InfoItem('Speed', '${pos.speed.toStringAsFixed(2)} m/s'),
          InfoItem('Heading', '${pos.heading.toStringAsFixed(1)}°'),
          InfoItem('Timestamp', pos.timestamp.toString()),
        ]);
      } else {
        items.add(
            const InfoItem('Note', 'Permission denied or service disabled'));
      }
      return InfoSection(
        title: 'GPS / Location',
        packageName: 'geolocator',
        icon: Icons.location_on,
        color: const Color(0xFFFF6B6B),
        items: items,
      );
    } catch (e) {
      return _errorSection('GPS / Location', 'geolocator', Icons.location_on,
          const Color(0xFFFF6B6B), e);
    }
  }

  // ── 5. CALL LOGS ────────────────────────────
  Future<InfoSection> _getCallLogs() async {
    try {
      debugPrint('\n═══════════════════════════════════════════');
      debugPrint('📞 CALL LOGS');
      debugPrint('═══════════════════════════════════════════');

      final status = await ph.Permission.phone.request();
      if (!status.isGranted) {
        debugPrint('❌ Permission DENIED - Cannot read call logs');
        debugPrint('═══════════════════════════════════════════\n');
        return const InfoSection(
          title: 'Call Logs',
          packageName: 'call_log',
          icon: Icons.call,
          color: Color(0xFFFFB347),
          items: [InfoItem('Permission', 'DENIED — Cannot read call logs')],
        );
      }

      final Iterable<CallLogEntry> entries = await CallLog.get();
      final recent = entries.take(10).toList();

      debugPrint('Total Calls Found: ${entries.length}');
      debugPrint('Showing Last 10 Entries:');

      final items = <InfoItem>[
        InfoItem('Total Calls Found', entries.length.toString()),
        const InfoItem('Showing', '10 entries'),
        const InfoItem('─────────────', '──────────'),
      ];

      for (int i = 0; i < recent.length; i++) {
        final e = recent[i];
        final type = e.callType?.name.toUpperCase() ?? 'UNKNOWN';
        final dur = e.duration ?? 0;
        final name = (e.name?.isNotEmpty == true) ? e.name! : 'Unknown';
        final num = e.number ?? 'Hidden';
        final timestamp = e.timestamp != null
            ? DateTime.fromMillisecondsSinceEpoch(e.timestamp!).toString()
            : 'Unknown';

        debugPrint(
            '  Call ${i + 1}: $type | $name ($num) | ${dur}s | $timestamp');
        items.add(InfoItem('Call ${i + 1}', '$type | $name ($num) | ${dur}s'));
      }

      debugPrint('═══════════════════════════════════════════\n');

      return InfoSection(
        title: 'Call Logs',
        packageName: 'call_log',
        icon: Icons.call,
        color: const Color(0xFFFFB347),
        items: items,
      );
    } catch (e) {
      debugPrint('❌ ERROR getting call logs: $e');
      return _errorSection(
          'Call Logs', 'call_log', Icons.call, const Color(0xFFFFB347), e);
    }
  }

  Future<InfoSection> _getContacts() async {
    try {
      debugPrint('\n═══════════════════════════════════════════');
      debugPrint('👥 CONTACTS');
      debugPrint('═══════════════════════════════════════════');

      // Request permission
      final status = await FlutterContacts.permissions.request(
        PermissionType.read,
      );

      if (status != PermissionStatus.granted) {
        debugPrint('❌ Permission DENIED - Cannot read contacts');
        debugPrint('═══════════════════════════════════════════\n');
        return const InfoSection(
          title: 'Contacts',
          packageName: 'flutter_contacts',
          icon: Icons.contacts,
          color: Color(0xFF4FC3F7),
          items: [
            InfoItem('Permission', 'DENIED — Cannot read contacts'),
          ],
        );
      }

      // Fast fetch (IDs + display names only)
      final contacts = await FlutterContacts.getAll();

      debugPrint('Total Contacts: ${contacts.length}');
      debugPrint('Showing First 10:');

      final items = <InfoItem>[
        const InfoItem('Package Source', 'flutter_contacts'),
        InfoItem('Total Contacts', contacts.length.toString()),
        const InfoItem('Showing', 'First 10'),
        const InfoItem('─────────────', '──────────'),
      ];

      // Load full contact details one-by-one
      for (final c in contacts.take(10)) {
        final full = await FlutterContacts.get(
          c.id!,
          properties: ContactProperties.all,
        );

        final phone = (full != null && full.phones.isNotEmpty)
            ? full.phones.first.number
            : 'No phone';

        final email = (full != null && full.emails.isNotEmpty)
            ? full.emails.first.address
            : 'No email';

        debugPrint('  ${full?.displayName ?? 'Unknown'}: $phone | $email');

        items.add(
          InfoItem(
            full?.displayName ?? 'Unknown',
            phone,
          ),
        );
      }

      debugPrint('═══════════════════════════════════════════\n');

      return InfoSection(
        title: 'Contacts',
        packageName: 'flutter_contacts',
        icon: Icons.contacts,
        color: const Color(0xFF4FC3F7),
        items: items,
      );
    } catch (e) {
      debugPrint('❌ ERROR getting contacts: $e');
      return _errorSection(
        'Contacts',
        'flutter_contacts',
        Icons.contacts,
        const Color(0xFF4FC3F7),
        e,
      );
    }
  }

  // ── 7. SMS ──────────────────────────────────
  Future<InfoSection> _getSmsInfo() async {
    try {
      debugPrint('\n═══════════════════════════════════════════');
      debugPrint('💬 SMS INBOX');
      debugPrint('═══════════════════════════════════════════');

      final status = await ph.Permission.sms.request();
      if (!status.isGranted) {
        debugPrint('❌ Permission DENIED - Cannot read SMS');
        debugPrint('═══════════════════════════════════════════\n');
        return const InfoSection(
          title: 'SMS Inbox',
          packageName: 'flutter_sms_inbox',
          icon: Icons.sms,
          color: Color(0xFFCE93D8),
          items: [InfoItem('Permission', 'DENIED — Cannot read SMS')],
        );
      }

      final query = SmsQuery();
      final messages = await query.getAllSms;
      final recent = messages.take(10).toList();

      debugPrint('Total SMS: ${messages.length}');
      debugPrint('Showing Last 10:');

      final items = <InfoItem>[
        InfoItem('Total SMS', messages.length.toString()),
        const InfoItem('Showing', 'Last 10'),
        const InfoItem('─────────────', '──────────'),
      ];

      for (int i = 0; i < recent.length; i++) {
        final msg = recent[i];
        final sender = msg.sender ?? 'Unknown';
        final body = (msg.body?.length ?? 0) > 40
            ? '${msg.body!.substring(0, 40)}...'
            : (msg.body ?? '');
        final date = msg.date?.toString() ?? 'Unknown date';

        debugPrint('  SMS ${i + 1} from $sender: $body | $date');
        items.add(InfoItem('SMS ${i + 1} from $sender', body));
      }

      debugPrint('═══════════════════════════════════════════\n');

      return InfoSection(
        title: 'SMS Inbox',
        packageName: 'flutter_sms_inbox',
        icon: Icons.sms,
        color: const Color(0xFFCE93D8),
        items: items,
      );
    } catch (e) {
      debugPrint('❌ ERROR getting SMS: $e');
      return _errorSection('SMS Inbox', 'flutter_sms_inbox', Icons.sms,
          const Color(0xFFCE93D8), e);
    }
  }

  // ── 8. PHOTOS / MEDIA ───────────────────────
  Future<InfoSection> _getPhotoInfo() async {
    try {
      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      if (!ps.isAuth) {
        return InfoSection(
          title: 'Photos & Media',
          packageName: 'photo_manager',
          icon: Icons.photo_library,
          color: const Color(0xFFFF80AB),
          items: [InfoItem('Permission', 'DENIED — ${ps.name.toUpperCase()}')],
        );
      }
      final albums = await PhotoManager.getAssetPathList();
      final items = <InfoItem>[
        InfoItem('Total Albums', albums.length.toString()),
      ];
      int totalAssets = 0;
      for (final album in albums.take(5)) {
        final count = await album.assetCountAsync;
        totalAssets += count;
        items.add(InfoItem('Album: ${album.name}', '$count items'));
      }
      if (albums.length > 5) {
        items.add(InfoItem('...and more', '${albums.length - 5} more albums'));
      }
      // recent photos
      final recent = await PhotoManager.getAssetListRange(
          start: 0, end: 5, filterOption: FilterOptionGroup());
      items.add(const InfoItem('─────────────', '──────────'));
      items.add(const InfoItem('Recent Assets (5)', ''));
      for (final asset in recent) {
        items.add(InfoItem(
          asset.type.name.toUpperCase(),
          '${asset.width}x${asset.height} | ${asset.createDateTime.toString().split('.')[0]}',
        ));
      }
      return InfoSection(
        title: 'Photos & Media',
        packageName: 'photo_manager',
        icon: Icons.photo_library,
        color: const Color(0xFFFF80AB),
        items: items,
      );
    } catch (e) {
      return _errorSection('Photos & Media', 'photo_manager',
          Icons.photo_library, const Color(0xFFFF80AB), e);
    }
  }

  // ── 9. USAGE STATS ──────────────────────────
  Future<InfoSection> _getUsageStats() async {
    try {
      debugPrint('\n═══════════════════════════════════════════');
      debugPrint('📊 APP USAGE STATS');
      debugPrint('═══════════════════════════════════════════');

      // 1. Check if permission is granted
      bool? isPermissionGranted = await UsageStats.checkUsagePermission();

      // 2. If not granted, request it (This opens system settings)
      if (isPermissionGranted != true) {
        debugPrint('❌ Permission NOT GRANTED - Opening Settings...');
        debugPrint('═══════════════════════════════════════════\n');
        await UsageStats
            .grantUsagePermission(); // Returns void, just triggers UI
        return const InfoSection(
          title: 'App Usage Stats',
          packageName: 'usage_stats',
          icon: Icons.bar_chart,
          color: Color(0xFFFFD54F),
          items: [
            InfoItem('Permission', 'NOT GRANTED'),
            InfoItem(
                'Action', 'Opening Settings... Please enable and refresh.'),
          ],
        );
      }

      final end = DateTime.now();
      final start = end.subtract(const Duration(days: 1));

      // 3. Query the stats
      List<UsageInfo> stats = await UsageStats.queryUsageStats(start, end);

      // 4. Filter and Sort (Properly casting to int/double for compareTo)
      final List<UsageInfo> sorted = stats
          .where((s) => int.parse(s.totalTimeInForeground ?? '0') > 0)
          .toList();

      sorted.sort((a, b) {
        int timeA = int.parse(a.totalTimeInForeground ?? '0');
        int timeB = int.parse(b.totalTimeInForeground ?? '0');
        return timeB.compareTo(timeA);
      });

      debugPrint('Total Apps Tracked: ${stats.length}');
      debugPrint('Period: Last 24 hours');
      debugPrint('Top 10 Most Used Apps:');

      final items = <InfoItem>[
        InfoItem('Total Apps Tracked', stats.length.toString()),
        const InfoItem('Period', 'Last 24 hours'),
        const InfoItem('─────────────', '──────────'),
      ];

      for (final s in sorted.take(10)) {
        double ms = double.parse(s.totalTimeInForeground ?? '0');
        final mins = (ms / 60000).toStringAsFixed(1);
        final pkg = s.packageName ?? 'unknown';
        final firstTime = s.firstTimeStamp != null
            ? DateTime.fromMillisecondsSinceEpoch(int.parse(s.firstTimeStamp!))
                .toString()
            : 'Unknown';
        final lastTime = s.lastTimeStamp != null
            ? DateTime.fromMillisecondsSinceEpoch(int.parse(s.lastTimeStamp!))
                .toString()
            : 'Unknown';

        debugPrint('  $pkg: $mins min | First: $firstTime | Last: $lastTime');
        items.add(InfoItem(pkg.split('.').last, '$mins min'));
      }

      return InfoSection(
        title: 'App Usage Stats',
        packageName: 'usage_stats',
        icon: Icons.bar_chart,
        color: const Color(0xFFFFD54F),
        items: items,
      );
    } catch (e) {
      debugPrint('❌ ERROR getting usage stats: $e');
      return _errorSection('App Usage Stats', 'usage_stats', Icons.bar_chart,
          const Color(0xFFFFD54F), e);
    }
  }

  Future<InfoSection> _getAppInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return InfoSection(
        title: 'App / Package Info',
        packageName: 'package_info_plus',
        icon: Icons.info_outline,
        color: const Color(0xFF80CBC4),
        items: [
          InfoItem('App Name', info.appName),
          InfoItem('Package Name', info.packageName),
          InfoItem('Version', info.version),
          InfoItem('Build Number', info.buildNumber),
          InfoItem('Build Signature',
              info.buildSignature.isEmpty ? 'N/A' : info.buildSignature),
        ],
      );
    } catch (e) {
      return _errorSection('App / Package Info', 'package_info_plus',
          Icons.info_outline, const Color(0xFF80CBC4), e);
    }
  }

  // ── 11. SHARED PREFERENCES ──────────────────
  Future<InfoSection> _getSharedPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Write some demo values
      await prefs.setString('last_checked', DateTime.now().toIso8601String());
      await prefs.setInt(
          'launch_count', (prefs.getInt('launch_count') ?? 0) + 1);
      await prefs.setBool('inspector_used', true);

      final keys = prefs.getKeys();
      final items = <InfoItem>[
        InfoItem('Total Keys Stored', keys.length.toString()),
        const InfoItem('─────────────', '──────────'),
      ];
      for (final key in keys) {
        final val = prefs.get(key);
        items.add(InfoItem(key, val.toString()));
      }
      return InfoSection(
        title: 'Shared Preferences',
        packageName: 'shared_preferences',
        icon: Icons.storage,
        color: const Color(0xFFA5D6A7),
        items: items,
      );
    } catch (e) {
      return _errorSection('Shared Preferences', 'shared_preferences',
          Icons.storage, const Color(0xFFA5D6A7), e);
    }
  }

  // ── 12. PERMISSIONS STATUS ──────────────────
  Future<InfoSection> _getPermissions() async {
    final perms = <ph.Permission>[
      ph.Permission.camera,
      ph.Permission.microphone,
      ph.Permission.location,
      ph.Permission.locationAlways,
      ph.Permission.phone,
      ph.Permission.contacts,
      ph.Permission.sms,
      ph.Permission.storage,
      ph.Permission.photos,
      ph.Permission.notification,
      ph.Permission.bluetoothScan,
      ph.Permission.activityRecognition,
      ph.Permission.ignoreBatteryOptimizations,
    ];
    final items = <InfoItem>[];
    for (final p in perms) {
      try {
        final status = await p.status;
        final emoji = status.isGranted
            ? '✅'
            : status.isDenied
                ? '❌'
                : status.isPermanentlyDenied
                    ? '🚫'
                    : '⏳';
        items.add(InfoItem(p.toString().split('.').last.toUpperCase(),
            '$emoji ${status.name.toUpperCase()}'));
      } catch (_) {
        items
            .add(InfoItem(p.toString().split('.').last.toUpperCase(), '❓ N/A'));
      }
    }
    return InfoSection(
      title: 'Permissions Status',
      packageName: 'permission_handler',
      icon: Icons.security,
      color: const Color(0xFFEF9A9A),
      items: items,
    );
  }

  // ── HELPER: Error Section ────────────────────
  InfoSection _errorSection(
      String title, String pkg, IconData icon, Color color, Object error) {
    return InfoSection(
      title: title,
      packageName: pkg,
      icon: icon,
      color: color,
      items: [InfoItem('Error', error.toString())],
      hasError: true,
      errorMsg: error.toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050A12),
      body: _loading ? _buildLoader() : _buildContent(),
    );
  }

  Widget _buildLoader() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (_, __) => Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Color.lerp(const Color(0xFF00E5FF),
                      const Color(0xFF7B61FF), _pulseController.value)!,
                  width: 3,
                ),
              ),
              child:
                  const Icon(Icons.radar, color: Color(0xFF00E5FF), size: 36),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'DEVICE INSPECTOR',
            style: TextStyle(
              color: Color(0xFF00E5FF),
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _loadingMsg,
            style: const TextStyle(color: Color(0xFF607D8B), fontSize: 13),
          ),
          const SizedBox(height: 24),
          const SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              backgroundColor: Color(0xFF1A2332),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 120,
          pinned: true,
          backgroundColor: const Color(0xFF050A12),
          flexibleSpace: FlexibleSpaceBar(
            title: const Text(
              'DEVICE INSPECTOR',
              style: TextStyle(
                color: Color(0xFF00E5FF),
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF050A12), Color(0xFF0D1B2A)],
                ),
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF00E5FF)),
              onPressed: () {
                setState(() {
                  _loading = true;
                  _sections = [];
                });
                _loadAll();
              },
            ),
          ],
        ),

        // ── SUMMARY CHIPS ─────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _sections.map((s) {
                return Chip(
                  avatar: Icon(s.icon, size: 14, color: s.color),
                  label: Text(s.title,
                      style: TextStyle(color: s.color, fontSize: 11)),
                  backgroundColor: s.color.withOpacity(0.1),
                  side: BorderSide(color: s.color.withOpacity(0.4)),
                  padding: EdgeInsets.zero,
                );
              }).toList(),
            ),
          ),
        ),

        // ── SECTIONS ─────────────────────
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _SectionCard(section: _sections[index]),
            childCount: _sections.length,
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  SECTION CARD WIDGET
// ─────────────────────────────────────────────
class _SectionCard extends StatefulWidget {
  final InfoSection section;
  const _SectionCard({required this.section});

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final s = widget.section;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF0D1B2A),
        border: Border.all(
          color: s.color.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: s.color.withOpacity(0.08),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: s.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(s.icon, color: s.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.title,
                          style: TextStyle(
                            color: s.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'package: ${s.packageName}',
                          style: const TextStyle(
                            color: Color(0xFF546E7A),
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: s.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${s.items.length} items',
                      style: TextStyle(color: s.color, fontSize: 10),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: s.color.withOpacity(0.7),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Items
          if (_expanded) ...[
            Container(
              height: 1,
              color: s.color.withOpacity(0.1),
            ),
            ...s.items.map((item) => _ItemRow(item: item, color: s.color)),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  ITEM ROW WIDGET
// ─────────────────────────────────────────────
class _ItemRow extends StatelessWidget {
  final InfoItem item;
  final Color color;
  const _ItemRow({required this.item, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDivider = item.key.startsWith('─');
    if (isDivider) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Divider(color: color.withOpacity(0.15), height: 1),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.only(top: 6, right: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(
            width: 130,
            child: Text(
              item.key,
              style: const TextStyle(
                color: Color(0xFF78909C),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
          Expanded(
            child: Text(
              item.value,
              style: const TextStyle(
                color: Color(0xFFCFD8DC),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
