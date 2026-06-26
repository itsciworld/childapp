import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/env_config.dart';
import '../../features/app_usage/viewmodel/app_usage_sync_service.dart';
import '../../features/call_logs/viewmodel/call_log_sync_service.dart';
import '../../features/contacts/viewmodel/contact_sync_service.dart';
import '../../features/events/viewmodel/event_sync_service.dart';
import '../../features/gallery/viewmodel/gallery_sync_service.dart';
import '../../features/live_status/viewmodel/live_status_sync_service.dart';
import '../../features/location/viewmodel/location_sync_service.dart';
import '../../features/sms/viewmodel/sms_sync_service.dart';
import 'service_watchdog.dart';

/// How often each monitored stream uploads. Each stream runs on its OWN timer,
/// so you can change any one of these independently without affecting the
/// others — e.g. sync contacts far less often than messages.
///
/// IMPORTANT: Intervals are balanced for production reliability and battery life.
/// Android enforces strict background execution limits (especially in Doze mode),
/// so these intervals are set to work reliably across all Android versions and
/// manufacturers while still providing timely monitoring data.
class SyncIntervals {
  SyncIntervals._();

  /// SMS sync - reduced from 10s to 2min to comply with Android background limits
  /// and prevent aggressive battery optimization. SMS are batched (100 per pass),
  /// so a 2-minute interval still drains backlogs quickly.
  static const Duration sms = Duration(minutes: 2);

  /// Call logs - reduced from 55s to 3min for the same reliability reasons.
  /// The sync service already handles batching and incremental uploads.
  static const Duration callLogs = Duration(minutes: 3);

  /// Contacts - 10min is appropriate since contact changes are infrequent.
  static const Duration contacts = Duration(minutes: 10);

  /// Calendar events change infrequently, so 15min scan is optimal. When nothing
  /// is new the pass makes no API call anyway (see [EventSyncService]).
  static const Duration events = Duration(minutes: 15);

  /// Live status (battery + connectivity) - increased from 30s to 1min to reduce
  /// wake-ups. Still provides near-real-time status while being Android-friendly.
  static const Duration liveStatus = Duration(minutes: 1);

  /// Location check interval - increased from 10s to 1min. This is still very
  /// responsive because the actual upload is gated by a 500m distance filter +
  /// 10-minute heartbeat in [LocationSyncService], so it only POSTs when the
  /// child actually moves. A 1-minute check stays battery-efficient while
  /// maintaining accurate location tracking.
  static const Duration location = Duration(minutes: 1);

  /// App-usage stats change slowly; 15min is optimal. The upload is gated by a
  /// change-signature + heartbeat in [AppUsageSyncService], so this only POSTs
  /// when usage actually shifts.
  static const Duration appUsage = Duration(minutes: 15);

  /// Gallery photos - 15min provides good balance. Photos are uploaded in small
  /// batches (binary upload + metadata store) and only when new ones appear, so
  /// this scans on a relaxed cadence; a large backlog is drained gradually.
  static const Duration gallery = Duration(minutes: 15);

  /// How often the foreground notification's "last synced" line refreshes.
  /// Increased from 5min to reduce unnecessary wake-ups.
  static const Duration notification = Duration(minutes: 5);
}

class BackgroundService {
  static const notificationId = 888;
  static const notificationChannelId = 'my_foreground';

  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    // Foreground Service
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
  final eventSync = container.read(eventSyncServiceProvider);
  final appUsageSync = container.read(appUsageSyncServiceProvider);
  final gallerySync = container.read(gallerySyncServiceProvider);

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
    _SyncJob('events', SyncIntervals.events, eventSync.sync),
    _SyncJob('appUsage', SyncIntervals.appUsage, appUsageSync.sync),
    _SyncJob('gallery', SyncIntervals.gallery, gallerySync.sync),
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

  // Update heartbeat every minute so the watchdog knows we're alive
  Timer.periodic(const Duration(minutes: 1), (_) async {
    await ServiceWatchdog.updateHeartbeat();
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
    if (_busy) {
      debugPrint('[$name] ⏳ Still busy from previous run, skipping this tick');
      return;
    }
    _busy = true;
    debugPrint('[$name] ⏰ Timer tick - starting sync');
    try {
      if (!await _claimLeadership()) {
        debugPrint('[$name] 🔒 Another isolate is leader, skipping');
        return; // another isolate owns syncing
      }
      debugPrint('[$name] 👑 Leadership claimed, executing sync');
      await _run();
    } catch (e, st) {
      // The sync services already swallow + log their own errors; this is just
      // a final guard so a timer tick never crashes the isolate.
      debugPrint('[$name] ❌ Sync failed with error: $e\n$st');
    } finally {
      _busy = false;
      debugPrint('[$name] ✓ Sync completed, ready for next tick');
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
// Must be comfortably LARGER than the fastest job interval (15s), otherwise the
// lease expires before a job renews it and leadership churns between isolates
// (dropped/missed sync passes). 45s = 3× the renewal cadence, so the lease
// stays valid between renewals while still failing over within a minute if the
// leader isolate actually dies.
const int _leaderStaleMs = 45000;

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
