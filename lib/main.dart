import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil1/services/background_services/background_services.dart';
import 'package:vigil1/services/background_services/service_watchdog.dart';
import 'package:vigil1/services/background_services/work_manager_service.dart';
import 'package:permission_handler/permission_handler.dart';

import 'core/config/env_config.dart';
import 'route_names.dart';
import 'routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables before anything that reads them.
  await EnvConfig.load();

  // Request all critical background permissions
  await _setupBackgroundPermissions();

  // Initialize the foreground service
  await BackgroundService.initializeService();

  // Start the in-process watchdog (restarts the service while the app process
  // is alive — every 2 min).
  await ServiceWatchdog.startWatchdog();

  // Register the OS-level keep-alive worker. This is what survives a FULL
  // process kill and device reboot: Android's JobScheduler persists it and
  // re-fires it (~every 15 min) to restart the service even if the app is never
  // reopened. Without this, an OEM/Doze process kill leaves nothing to bring
  // the service back until the user manually opens the app.
  await WorkManagerService.initialize();

  // ProviderScope makes Riverpod providers available to the whole app.
  runApp(const ProviderScope(child: MyApp()));
}

/// Sets up all permissions required for reliable background operation.
/// This is CRITICAL for production - without these exemptions, Android will
/// aggressively kill the background service to save battery.
Future<void> _setupBackgroundPermissions() async {
  // 1. Battery Optimization Exemption
  // This is the MOST IMPORTANT permission for background service survival.
  // Without it, Android will kill the service within minutes on most devices.
  try {
    final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
    if (!batteryStatus.isGranted) {
      debugPrint(
          '[BackgroundPermissions] ⚠️ Requesting battery optimization exemption...');
      final result = await Permission.ignoreBatteryOptimizations.request();
      if (result.isGranted) {
        debugPrint(
            '[BackgroundPermissions] ✅ Battery optimization exemption granted');
      } else {
        debugPrint(
            '[BackgroundPermissions] ❌ Battery optimization exemption DENIED');
        debugPrint(
            '[BackgroundPermissions] ⚠️ Background service reliability will be severely compromised');
      }
    } else {
      debugPrint(
          '[BackgroundPermissions] ✅ Battery optimization exemption already granted');
    }
  } catch (e) {
    debugPrint(
        '[BackgroundPermissions] ❌ Error requesting battery optimization: $e');
  }

  // 2. Exact Alarm Permission (Android 12+)
  // Required for exact/repeating timers in background. Without this, timers
  // may be batched/delayed by the system.
  try {
    if (await Permission.scheduleExactAlarm.isDenied) {
      debugPrint(
          '[BackgroundPermissions] ⚠️ Requesting exact alarm permission...');
      final result = await Permission.scheduleExactAlarm.request();
      if (result.isGranted) {
        debugPrint('[BackgroundPermissions] ✅ Exact alarm permission granted');
      } else {
        debugPrint(
            '[BackgroundPermissions] ⚠️ Exact alarm permission denied - timers may be less precise');
      }
    } else {
      debugPrint(
          '[BackgroundPermissions] ✅ Exact alarm permission already granted');
    }
  } catch (e) {
    // This permission might not exist on older Android versions
    debugPrint(
        '[BackgroundPermissions] ℹ️ Exact alarm permission not available (likely Android < 12)');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vigil - Parental Control App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: RouteNames.home,
      routes: AppRoutes.routes,
    );
  }
}
