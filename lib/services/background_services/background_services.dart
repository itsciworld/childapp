import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
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
import '../../features/social_accessibility/viewmodel/screen_capture_sync_service.dart';
import '../../features/social_notifications/viewmodel/notification_sync_service.dart';
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
  static const Duration sms = Duration(seconds: 10);

  /// Call logs - reduced from 55s to 3min for the same reliability reasons.
  /// The sync service already handles batching and incremental uploads.
  static const Duration callLogs = Duration(seconds: 8);

  /// Contacts - 10min is appropriate since contact changes are infrequent.
  static const Duration contacts = Duration(minutes: 1);

  /// Calendar events change infrequently, so 15min scan is optimal. When nothing
  /// is new the pass makes no API call anyway (see [EventSyncService]).
  static const Duration events = Duration(minutes: 15);

  /// Live status (battery + connectivity) - increased from 30s to 1min to reduce
  /// wake-ups. Still provides near-real-time status while being Android-friendly.
  static const Duration liveStatus = Duration(seconds: 13);

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
  static const Duration gallery = Duration(minutes: 2);

  /// Social notification capture (FEATURE A) - drains the native notification
  /// queue on a short cadence. The native listener captures in real time; this
  /// just ships what's queued.
  ///
  /// WHY 15s AND NOT 2min: uploads run only in whichever background isolate
  /// currently holds the leader lease (see [_claimLeadership]). More than one
  /// isolate can be alive at once, so a job's tick only actually runs if it
  /// lands on the leader. A frequent stream like `sms` (10s) catches a
  /// leader-aligned tick often and stays healthy; a 2-min stream almost never
  /// did — its sparse ticks kept landing on non-leader isolates and skipping, so
  /// the queue grew without ever draining. A short interval gives these drains
  /// the same steady stream of chances the working streams get. The drain itself
  /// is cheap (an empty queue just no-ops), so this is battery-safe.
  static const Duration socialNotifications = Duration(seconds: 15);

  /// Social on-screen capture (FEATURE B) - drains the native accessibility
  /// queue on the same short cadence, for the same leader-election reason as
  /// [socialNotifications]. Accessibility can produce many lines, so frequent
  /// small drains also beat occasional large ones.
  static const Duration socialAccessibility = Duration(seconds: 15);

  /// How often the foreground notification's "last synced" line refreshes.
  /// Increased from 5min to reduce unnecessary wake-ups.
  static const Duration notification = Duration(minutes: 5);
}

class BackgroundService {
  static const notificationId = 888;
  static const notificationChannelId = 'my_foreground';

  /// Remembers which foreground-service types the service was last configured
  /// with, so [refreshForegroundServiceTypes] only recycles it when they change.
  static const _fgsTypesKey = 'fgs_types_signature';

  /// Which foreground-service types to claim, based on what the child has
  /// actually granted right now.
  ///
  /// WHY THIS EXISTS — this was the cause of the
  /// `ForegroundServiceDidNotStartInTimeException` crash loop:
  ///
  /// The manifest declares `android:foregroundServiceType="location|specialUse"`,
  /// and when no types are passed here the plugin falls back to
  /// `FOREGROUND_SERVICE_TYPE_MANIFEST` — i.e. it claims *both*. On Android 14
  /// (targetSdk 34) `startForeground()` verifies each claimed type against a
  /// granted runtime permission, and `location` requires ACCESS_FINE_LOCATION /
  /// ACCESS_COARSE_LOCATION. On a fresh install the service starts from `main()`
  /// long before the permissions screen, so that check failed with a
  /// SecurityException — which flutter_background_service *swallows* (see
  /// `BackgroundService.updateNotificationInfo`). The service therefore kept
  /// running but never entered the foreground, and ~5s later Android killed the
  /// process. The plugin's own `WatchdogReceiver` alarm then restarted it, which
  /// is why it crashed again and again.
  ///
  /// Claiming only the types we can back with a permission keeps
  /// `startForeground()` succeeding at every stage of onboarding. `specialUse`
  /// is always safe: it needs no runtime permission, only the
  /// PROPERTY_SPECIAL_USE_FGS_SUBTYPE declaration already in the manifest.
  static Future<List<AndroidForegroundType>> _foregroundServiceTypes() async {
    final types = <AndroidForegroundType>[AndroidForegroundType.specialUse];
    try {
      if (await Permission.location.isGranted) {
        types.insert(0, AndroidForegroundType.location);
      }
    } catch (e) {
      // Never let a permission lookup stop the service from starting — the
      // specialUse-only list below is always valid.
      debugPrint('[BackgroundService] ⚠️ Location permission check failed: $e');
    }
    return types;
  }

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
    final types = await _foregroundServiceTypes();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart, // Entry point function
        // `autoStart: true` made configure() bring the service up itself, which
        // raced with the explicit startService() below and could spawn a SECOND
        // background isolate — and two isolates each ran their own loop,
        // querying the `call_log` plugin concurrently (it allows only one query
        // at a time → ALREADY_RUNNING / "Reply already submitted"). Starting it
        // from exactly one place keeps it to a single isolate.
        autoStart: false,
        // Reboots are covered by the plugin's BootReceiver, which reads this
        // flag and not `autoStart` — so turning autoStart off costs nothing.
        autoStartOnBoot: true,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'Vigil Active',
        initialNotificationContent: 'Monitoring is running in background',
        foregroundServiceNotificationId: notificationId,
        // Only the types we can back with a granted permission — see
        // [_foregroundServiceTypes] for why omitting this crashed the app.
        foregroundServiceTypes: types,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    // Record what we just configured so [refreshForegroundServiceTypes] can tell
    // whether a later permission grant actually changed anything.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fgsTypesKey, _signature(types));

    if (!await service.isRunning()) {
      try {
        await service.startService();
      } catch (e) {
        // Android 12+ can refuse a foreground start made from the background
        // (ForegroundServiceStartNotAllowedException). That must not take the
        // whole app down at launch — the watchdog retries later.
        debugPrint('[BackgroundService] ❌ startService failed: $e');
      }
    }
  }

  /// Re-applies the foreground-service types after the child grants (or revokes)
  /// location, so the service can start claiming the `location` type and keep
  /// reading position while the app is backgrounded on Android 14+.
  ///
  /// The native side reads the type list once, in `Service.onCreate`, so
  /// re-running `configure()` alone has no effect on the live service — it has
  /// to be recycled. This no-ops when the types are unchanged, so it is safe to
  /// call after any permission toggle.
  static Future<void> refreshForegroundServiceTypes() async {
    final signature = _signature(await _foregroundServiceTypes());
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (prefs.getString(_fgsTypesKey) == signature) return;

    debugPrint(
        '[BackgroundService] 🔄 Foreground service types changed → $signature, recycling service');

    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke('stopService');
      // onDestroy tears the isolate down asynchronously; wait for it so the
      // restart below creates a fresh Service (onCreate re-reads the types).
      await Future.delayed(const Duration(seconds: 2));
    }
    await initializeService();
  }

  static String _signature(List<AndroidForegroundType> types) =>
      types.map((t) => t.name).join(',');
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
  final notificationSync = container.read(notificationSyncServiceProvider);
  final screenCaptureSync = container.read(screenCaptureSyncServiceProvider);

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
    _SyncJob('socialNotif', SyncIntervals.socialNotifications,
        notificationSync.sync),
    _SyncJob('socialScreen', SyncIntervals.socialAccessibility,
        screenCaptureSync.sync),
  ];
  // Only ONE isolate should actually run the jobs at a time — on some OEMs more
  // than one background isolate stays alive, and if their long-interval ticks
  // land on non-leader isolates the stream STARVES (observed: social capture
  // ticked repeatedly, always skipped on the leader gate, and never uploaded).
  // The coordinator ties job execution to the leader lease: whoever holds it
  // promotes and runs every stream on every tick; the rest stay demoted and
  // idle instead of ticking-and-skipping. That is what keeps a single active
  // leader firing all streams reliably.
  final coordinator = _JobCoordinator(jobs);

  // Claim once up front so a fresh boot doesn't wait a full renewal cycle for
  // its first drain; the renewal timer drives promote/demote from here on.
  // Promotion itself does the boot `runNow` kick (so long-interval streams like
  // gallery / app-usage don't sit idle for a full interval before first sync).
  final bootLeader = await _claimLeadership();
  _startLeadershipRenewal(coordinator);
  if (bootLeader) coordinator.promote();

  // Foreground "sync on open" (ChildHomePage sends 'syncNow') → kick every
  // stream immediately. Harmless on a standby isolate: the per-tick leader gate
  // in [_SyncJob._tick] makes a non-leader's run a no-op.
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
    var ran = false;
    try {
      if (!await _claimLeadership()) {
        debugPrint('[$name] 🔒 Another isolate is leader, skipping');
        return; // another isolate owns syncing
      }
      ran = true;
      debugPrint('[$name] 👑 Leadership claimed, executing sync');
      await _run();
    } catch (e, st) {
      // The sync services already swallow + log their own errors; this is just
      // a final guard so a timer tick never crashes the isolate.
      debugPrint('[$name] ❌ Sync failed with error: $e\n$st');
    } finally {
      _busy = false;
      // Don't claim a sync "completed" when it was skipped — that line made the
      // logs read as if every stream was healthy while nothing was uploading.
      debugPrint(ran
          ? '[$name] ✓ Sync completed, ready for next tick'
          : '[$name] ⤼ Tick ended without syncing');
    }
  }
}

// ── Cross-isolate leader election ──────────────────────────────────────────
// Top-level isolate guards don't span isolates (separate memory), and the OS
// can keep more than one background isolate alive. The one piece of state both
// isolates CAN see is SharedPreferences, so we elect a single leader through it:
// only the leader runs the syncs. The leader renews its lease on a dedicated
// timer; if it dies, another isolate takes over after [_leaderStaleMs].
const String _leaderIdKey = 'sync_leader_id';
const String _leaderBeatKey = 'sync_leader_beat_ms';

/// How often the leader refreshes its lease, on its own timer.
///
/// Renewal used to ride on job execution, which coupled the lease to how long a
/// job took. That is why the window below had to be so generous — and the
/// generous window is what made every isolate death cost a long blackout: a
/// surviving isolate logged `🔒 Another isolate is leader, skipping` and sent
/// NOTHING until the dead leader's lease finally expired. Live status has no
/// backlog to catch up on, so that blackout is visible to the parent directly
/// as the child dropping offline and coming back.
const int _leaderRenewMs = 5000;

/// How long a lease survives without renewal before another isolate may seize
/// it — i.e. the worst-case gap after the leader dies. 3× [_leaderRenewMs], so
/// two renewals can be missed before failover, and takeover happens in seconds
/// instead of the 45s this used to be.
const int _leaderStaleMs = 15000;

/// Renews (or seizes) the lease on a fixed cadence, independently of the jobs.
Timer? _leaderRenewTimer;

/// Renews (or seizes) the lease on a fixed cadence, independently of the jobs,
/// and drives the [coordinator]: hold the lease → promote (run jobs); lose it →
/// demote (stand down). This is what converges job execution onto a single
/// active isolate while preserving fast failover if that isolate dies.
void _startLeadershipRenewal(_JobCoordinator coordinator) {
  _leaderRenewTimer?.cancel();
  _leaderRenewTimer = Timer.periodic(
    const Duration(milliseconds: _leaderRenewMs),
    (_) async {
      try {
        if (await _claimLeadership()) {
          coordinator.promote();
        } else {
          coordinator.demote();
        }
      } catch (e) {
        debugPrint('[leader] ⚠️ lease renewal failed: $e');
      }
    },
  );
}

/// Starts/stops the whole job set as this isolate gains or loses the leader
/// lease, so exactly one isolate runs the streams at a time. Idempotent: a
/// promote while already active (or demote while already idle) is a no-op, so
/// the 5-second renewal timer can call it every tick cheaply.
class _JobCoordinator {
  _JobCoordinator(this._jobs);

  final List<_SyncJob> _jobs;
  bool _active = false;

  void promote() {
    if (_active) return;
    _active = true;
    debugPrint('[coordinator] 👑 promoted — starting ${_jobs.length} streams');
    for (final job in _jobs) {
      job.start();
    }
    // Boot/takeover kick so long-interval streams drain now instead of waiting
    // a full interval; the per-tick leader gate keeps this safe.
    for (final job in _jobs) {
      job.runNow();
    }
  }

  void demote() {
    if (!_active) return;
    _active = false;
    debugPrint('[coordinator] 💤 demoted — standing down streams');
    for (final job in _jobs) {
      job.stop();
    }
  }
}

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
