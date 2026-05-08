import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // 3. The Actual Background Loop
  Timer.periodic(const Duration(seconds: 15), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        // Here is where you call your Tracking APIs
        print("Background Service: Fetching data/Checking logs...");

        service.setForegroundNotificationInfo(
          title: "Vigil Protection Active",
          content:
              "Last synced: ${DateTime.now().hour}:${DateTime.now().minute}",
        );
      }
    }
  });
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}
