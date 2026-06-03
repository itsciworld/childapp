import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env_config.dart';
import '../../features/call_logs/viewmodel/call_log_sync_service.dart';
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

// This function runs in a separate isolate (background)
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // This isolate doesn't inherit the main isolate's dotenv / Riverpod state,
  // so load env (for the API base URL) and build a local container here.
  await EnvConfig.load();
  final container = ProviderContainer();
  final smsSync = container.read(smsSyncServiceProvider);
  final callLogSync = container.read(callLogSyncServiceProvider);

  service.on('stopService').listen((event) {
    container.dispose();
    service.stopSelf();
  });

  // 3. The Actual Background Loop — silently upload SMS every 5 seconds.
  var isSyncing = false;
  Timer.periodic(const Duration(seconds: 5), (timer) async {
    // Skip this tick if the previous upload hasn't finished yet.
    if (isSyncing) return;
    isSyncing = true;
    try {
      await smsSync.sync();
      await callLogSync.sync();

      if (service is AndroidServiceInstance &&
          await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: "Vigil Protection Active",
          content:
              "Last synced: ${DateTime.now().hour}:${DateTime.now().minute}",
        );
      }
    } finally {
      isSyncing = false;
    }
  });
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}
