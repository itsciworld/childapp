import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env_config.dart';
import '../../features/call_logs/viewmodel/call_log_sync_service.dart';
import '../../features/contacts/viewmodel/contact_sync_service.dart';
import '../../features/sms/viewmodel/sms_sync_service.dart';

class BackgroundService {
  static const notificationId = 888;
  static const notificationChannelId = 'my_foreground';

  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    // 1. Setup Local Notifications for Android Foreground Service
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId,
      'Vigil Service',
      description: 'This channel is used for vital monitoring.',
      importance: Importance.low, // low so it doesn't pop up every time
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 2. Configure the Service
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart, // Entry point function
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'Vigil Active',
        initialNotificationContent: 'Monitoring is running in background',
        foregroundServiceNotificationId: notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    service.startService();
  }
}

// Top-level (isolate-static) guards. `onStart` can be invoked more than once in
// the service's lifetime (foreground/background transitions, service restarts).
// Each invocation previously created its OWN Timer.periodic, so two loops ran in
// parallel and queried the fragile `call_log` plugin at the same time —
// crashing it with ALREADY_RUNNING / "Reply already submitted". These flags live
// at the isolate's top level so a second `onStart` can't spin up a second loop,
// and so only one sync pass is ever in flight.
bool _loopStarted = false;
bool _isSyncing = false;

// This function runs in a separate isolate (background)
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  service.on('stopService').listen((event) {
    _loopStarted = false;
    service.stopSelf();
  });

  // Guard against a duplicate onStart spinning up a second 5s loop.
  if (_loopStarted) return;
  _loopStarted = true;

  // This isolate doesn't inherit the main isolate's dotenv / Riverpod state,
  // so load env (for the API base URL) and build a local container here.
  await EnvConfig.load();
  final container = ProviderContainer();
  final smsSync = container.read(smsSyncServiceProvider);
  final callLogSync = container.read(callLogSyncServiceProvider);
  final contactSync = container.read(contactSyncServiceProvider);

  // This isolate is the SINGLE owner of all device-plugin reads. The UI never
  // reads them directly — it sends a 'syncNow' event (see ChildHomePage) which
  // we handle here, so plugin access stays in one isolate and serialized.
  Future<void> runSyncPass() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      await smsSync.sync();
      await callLogSync.sync();
      await contactSync.sync();

      if (service is AndroidServiceInstance &&
          await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: "Vigil Protection Active",
          content:
              "Last synced: ${DateTime.now().hour}:${DateTime.now().minute}",
        );
      }
    } finally {
      _isSyncing = false;
    }
  }

  // Foreground "sync on open" routes through here so plugin access stays in one
  // isolate.
  service.on('syncNow').listen((event) {
    runSyncPass();
  });

  // The recurring background upload — every 5 seconds.
  Timer.periodic(const Duration(seconds: 5), (timer) => runSyncPass());
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}
