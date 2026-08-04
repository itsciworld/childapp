import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'service_watchdog.dart';

/// OS-level ("out-of-process") keep-alive for the monitoring service.
///
/// The in-process [ServiceWatchdog] can only restart the foreground service
/// while the *app process itself* is still alive — so when Android or an
/// aggressive OEM battery manager kills the WHOLE process (or after a reboot),
/// nothing is left running to bring the service back until the user manually
/// reopens the app.
///
/// This is the missing safety net. [WorkManager] schedules a periodic job with
/// Android's [JobScheduler], which the OS persists in its own database. That job
/// is rescheduled automatically across process death and reboots and, when it
/// fires, spins up a background Dart isolate that runs
/// [_workManagerCallbackDispatcher] — restarting the service if it isn't
/// running. No user interaction required.
///
/// Layering (defence in depth):
/// - [ServiceWatchdog]  → every 2 min, only while the app process is alive.
/// - [WorkManagerService] → every ~15 min (Android's minimum periodic cadence),
///   survives full-process kills and reboots.
class WorkManagerService {
  WorkManagerService._();

  /// Unique work name — WorkManager keys the persisted job on this, so a single
  /// keep-alive job exists no matter how many times we (re)register it.
  static const String _uniqueName = 'vigil-service-keepalive-periodic';

  /// Task name handed back to the callback dispatcher (for logging / routing).
  static const String _taskName = 'vigil_service_keepalive';

  /// Android enforces a hard minimum of 15 minutes for periodic work. Anything
  /// smaller is silently clamped to 15 min, so we set it explicitly.
  static const Duration _frequency = Duration(minutes: 15);

  /// Registers the periodic keep-alive job. Call once from `main()` after the
  /// foreground service and in-process watchdog are set up. Idempotent:
  /// [ExistingPeriodicWorkPolicy.update] refreshes the existing job in place
  /// instead of stacking duplicates.
  static Future<void> initialize() async {
    try {
      await Workmanager().initialize(_workManagerCallbackDispatcher);

      await Workmanager().registerPeriodicTask(
        _uniqueName,
        _taskName,
        frequency: _frequency,
        // First check ~15 min after launch; the in-process watchdog already
        // covers the window before that.
        initialDelay: _frequency,
        // Keep firing regardless of connectivity/battery — we must be able to
        // restart the service even offline or on low battery.
        constraints: Constraints(networkType: NetworkType.notRequired),
        // Update-in-place so re-running main() never duplicates the job.
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        backoffPolicy: BackoffPolicy.linear,
        backoffPolicyDelay: const Duration(minutes: 1),
      );
      debugPrint(
          '[WorkManagerService] ✅ Periodic keep-alive registered (every ${_frequency.inMinutes} min)');
    } catch (e, st) {
      debugPrint('[WorkManagerService] ❌ Failed to register keep-alive: $e\n$st');
    }
  }

  /// Cancels the keep-alive job. Only needed on a genuine logout/uninstall flow
  /// where monitoring should stop entirely.
  static Future<void> cancel() async {
    try {
      await Workmanager().cancelByUniqueName(_uniqueName);
      debugPrint('[WorkManagerService] 🛑 Keep-alive cancelled');
    } catch (e) {
      debugPrint('[WorkManagerService] ❌ Failed to cancel keep-alive: $e');
    }
  }
}

/// Entry point for the WorkManager background isolate.
///
/// MUST be a top-level (or static) function annotated with `vm:entry-point` so
/// the Dart VM can locate it by name when the OS spins up the isolate — even
/// after the app process was killed or the device rebooted.
@pragma('vm:entry-point')
void _workManagerCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    // This runs in a fresh isolate with no Flutter bindings or plugin
    // registrations yet — set both up before touching any method channel.
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    try {
      debugPrint('[WorkManagerService] ⏰ Keep-alive fired ($taskName) — checking service health');
      await ServiceWatchdog.ensureServiceHealthy();
      return true;
    } catch (e, st) {
      debugPrint('[WorkManagerService] ❌ Keep-alive task failed: $e\n$st');
      // Returning false asks WorkManager to retry with the backoff policy.
      return false;
    }
  });
}
