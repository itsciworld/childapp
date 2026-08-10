import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil1/services/background_services/background_services.dart';
import 'package:vigil1/services/background_services/service_watchdog.dart';
import 'package:vigil1/services/background_services/work_manager_service.dart';

import 'core/config/env_config.dart';
import 'route_names.dart';
import 'routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables before anything that reads them.
  await EnvConfig.load();

  // NOTE: The background permission popups (e.g. "Allow app to always run in the
  // background?") are intentionally NOT requested here — they are triggered from
  // the splash flow AFTER the splash screen renders (see SplashView), so they no
  // longer flash over a blank screen at cold start.

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
