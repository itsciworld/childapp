import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/env_config.dart';
import '../../features/call_logs/viewmodel/call_log_sync_service.dart';
import '../../features/contacts/viewmodel/contact_sync_service.dart';
import '../../features/live_status/viewmodel/live_status_sync_service.dart';
import '../../features/location/viewmodel/location_sync_service.dart';
import '../../features/sms/viewmodel/sms_sync_service.dart';

/// How often each monitored stream uploads. Each stream runs on its OWN timer,
/// so you can change any one of these independently without affecting the
/// others — e.g. sync contacts far less often than messages.
class SyncIntervals {
  SyncIntervals._();

  static const Duration sms = Duration(seconds: 5);
  static const Duration callLogs = Duration(seconds: 5);
  static const Duration contacts = Duration(seconds: 5);

  /// Live status (battery + connectivity) is a current snapshot, not a backlog
  /// to drain, so it pushes less often than the message/call streams to avoid
  /// hammering the server with near-identical payloads.
  static const Duration liveStatus = Duration(seconds: 30);

  /// How often we *check* the current location. The actual upload is gated by a
  /// distance filter + heartbeat in [LocationSyncService], so a frequent check
  /// stays cheap (it only POSTs when the child actually moves).
  static const Duration location = Duration(seconds: 20);

  /// How often the foreground notification's "last synced" line refreshes.
  static const Duration notification = Duration(seconds: 30);
}

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

    // Only start if it isn't already running. `autoStart: true` already brings
    // the service up after configure / on boot, so calling startService()
    // unconditionally spawned a SECOND background isolate — and two isolates
    // each ran their own 5s loop, querying the `call_log` plugin concurrently
    // (it allows only one query at a time → ALREADY_RUNNING / "Reply already
    // submitted"). Guarding on isRunning() keeps it to a single isolate.
    if (!await service.isRunning()) {
      await service.startService();
    }
  }
}

// Guards against a duplicate `onStart` wiring up a second set of timers in the
// SAME isolate.
bool _loopStarted = false;

// A unique id for THIS isolate, used for cross-isolate leader election (below).
final String _isolateId =
    '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';

// This function runs in a separate isolate (background)
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  service.on('stopService').listen((event) {
    _loopStarted = false;
    service.stopSelf();
  });

  // Guard against a duplicate onStart wiring up a second set of timers.
  if (_loopStarted) return;
  _loopStarted = true;

  // This isolate doesn't inherit the main isolate's dotenv / Riverpod state,
  // so load env (for the API base URL) and build a local container here.
  await EnvConfig.load();
  final container = ProviderContainer();
  final smsSync = container.read(smsSyncServiceProvider);
  final callLogSync = container.read(callLogSyncServiceProvider);
  final contactSync = container.read(contactSyncServiceProvider);
  final liveStatusSync = container.read(liveStatusSyncServiceProvider);
  final locationSync = container.read(locationSyncServiceProvider);

  // Each stream gets its OWN timer + interval + in-flight guard, so they're
  // fully independent: change any interval in [SyncIntervals] without touching
  // the others, and a stream never overlaps itself. Different streams talk to
  // different native plugins, so running on separate timers is safe — the only
  // plugin that can't tolerate a concurrent call (`call_log`) is protected from
  // ITSELF by its job's in-flight guard and from OTHER isolates by leader
  // election (see [_SyncJob] / [_claimLeadership]).
  final jobs = <_SyncJob>[
    _SyncJob('sms', SyncIntervals.sms, smsSync.sync),
    _SyncJob('callLogs', SyncIntervals.callLogs, callLogSync.sync),
    _SyncJob('contacts', SyncIntervals.contacts, contactSync.sync),
    _SyncJob('liveStatus', SyncIntervals.liveStatus, liveStatusSync.sync),
    _SyncJob('location', SyncIntervals.location, locationSync.sync),
  ];
  for (final job in jobs) {
    job.start();
  }

  // Foreground "sync on open" (ChildHomePage sends 'syncNow') → run every stream
  // immediately, subject to the same leader / in-flight guards.
  service.on('syncNow').listen((event) {
    for (final job in jobs) {
      job.runNow();
    }
  });

  // Keep the foreground notification's "last synced" line fresh.
  Timer.periodic(SyncIntervals.notification, (_) async {
    if (service is AndroidServiceInstance &&
        await service.isForegroundService()) {
      final now = DateTime.now();
      final hh = now.hour.toString().padLeft(2, '0');
      final mm = now.minute.toString().padLeft(2, '0');
      service.setForegroundNotificationInfo(
        title: 'Vigil Protection Active',
        content: 'Last active: $hh:$mm',
      );
    }
  });
}

/// One independently-scheduled upload stream (SMS, call logs, or contacts).
///
/// - Runs [_run] on its own [interval].
/// - `_busy` prevents a slow pass from overlapping the next tick (so a single
///   stream never queries its plugin twice at once).
/// - Every run is gated by [_claimLeadership], so when more than one background
///   isolate happens to be alive only ONE actually uploads — which is what keeps
///   the fragile `call_log` plugin from being hit by two isolates at once, and
///   also avoids duplicate uploads.
class _SyncJob {
  _SyncJob(this.name, this.interval, this._run);

  final String name;
  final Duration interval;
  final Future<void> Function() _run;

  bool _busy = false;
  Timer? _timer;

  void start() => _timer = Timer.periodic(interval, (_) => _tick());

  void stop() => _timer?.cancel();

  /// Trigger an immediate run (used by 'syncNow'); same guards as a timer tick.
  Future<void> runNow() => _tick();

  Future<void> _tick() async {
    if (_busy) return;
    _busy = true;
    try {
      if (!await _claimLeadership()) return; // another isolate owns syncing
      await _run();
    } catch (_) {
      // The sync services already swallow + log their own errors; this is just
      // a final guard so a timer tick never crashes the isolate.
    } finally {
      _busy = false;
    }
  }
}

// ── Cross-isolate leader election ──────────────────────────────────────────
// Top-level isolate guards don't span isolates (separate memory), and the OS
// can keep more than one background isolate alive. The one piece of state both
// isolates CAN see is SharedPreferences, so we elect a single leader through it:
// only the leader runs the syncs. The leader renews its lease each run; if it
// dies, another isolate takes over after [_leaderStaleMs].
const String _leaderIdKey = 'sync_leader_id';
const String _leaderBeatKey = 'sync_leader_beat_ms';
const int _leaderStaleMs = 12000;

Future<bool> _claimLeadership() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final now = DateTime.now().millisecondsSinceEpoch;
  final leader = prefs.getString(_leaderIdKey) ?? '';
  final beat = prefs.getInt(_leaderBeatKey) ?? 0;

  final iAmLeader = leader == _isolateId;
  final vacant = leader.isEmpty || (now - beat) > _leaderStaleMs;
  if (!iAmLeader && !vacant) return false;

  // Claim / renew the lease, then re-read to shrink the startup race where two
  // isolates both see a vacant lease and write at the same time.
  await prefs.setString(_leaderIdKey, _isolateId);
  await prefs.setInt(_leaderBeatKey, now);
  await prefs.reload();
  return prefs.getString(_leaderIdKey) == _isolateId;
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}
