import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A lightweight watchdog that monitors background service health and
/// automatically restarts it if it dies unexpectedly.
///
/// **How it works:**
/// 1. The foreground service writes a heartbeat timestamp every minute
/// 2. A separate timer (in the main app) checks this heartbeat
/// 3. If heartbeat is stale (no update for 5+ minutes), restarts the service
///
/// **Why this approach:**
/// - No WorkManager dependency (avoiding compatibility issues)
/// - Simple and reliable
/// - Works with existing SharedPreferences infrastructure
/// - Low overhead (just timestamp checks)
class ServiceWatchdog {
  static const String _heartbeatKey = 'service_heartbeat_ms';
  static const String _lastCheckKey = 'watchdog_last_check_ms';
  
  /// How often the watchdog checks the service health (from the main app)
  static const Duration _checkInterval = Duration(minutes: 2);
  
  /// How old the heartbeat can be before we consider the service dead
  static const Duration _heartbeatStaleThreshold = Duration(minutes: 5);
  
  static Timer? _watchdogTimer;

  /// Start the watchdog from the main app.
  /// This should be called once in main() after initializing the service.
  static Future<void> startWatchdog() async {
    // Cancel any existing watchdog
    _watchdogTimer?.cancel();

    debugPrint('[ServiceWatchdog] 🐕 Starting watchdog - will check service health every ${_checkInterval.inMinutes} minutes');

    // Initial check after 1 minute
    Timer(const Duration(minutes: 1), _checkServiceHealth);

    // Then periodic checks
    _watchdogTimer = Timer.periodic(_checkInterval, (_) => _checkServiceHealth());
  }

  /// Stop the watchdog (useful for cleanup)
  static void stopWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    debugPrint('[ServiceWatchdog] 🐕 Watchdog stopped');
  }

  /// Timer target for the in-process watchdog. Delegates to
  /// [ensureServiceHealthy] so the exact same check-and-restart logic is shared
  /// with the out-of-process [WorkManager] keep-alive worker.
  static Future<void> _checkServiceHealth() => ensureServiceHealthy();

  /// Check if the background service is alive by examining its heartbeat.
  /// If the service appears dead, attempt to restart it.
  ///
  /// This is safe to call from ANY isolate (the in-process watchdog timer OR the
  /// WorkManager background isolate). It only touches [SharedPreferences] and the
  /// [FlutterBackgroundService] method channel, both of which work cross-isolate.
  static Future<void> ensureServiceHealthy() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      
      final now = DateTime.now().millisecondsSinceEpoch;
      final lastHeartbeat = prefs.getInt(_heartbeatKey) ?? 0;
      final timeSinceHeartbeat = Duration(milliseconds: now - lastHeartbeat);

      // Record that we performed a check
      await prefs.setInt(_lastCheckKey, now);

      debugPrint('[ServiceWatchdog] 🔍 Health check: Last heartbeat was ${timeSinceHeartbeat.inMinutes} minutes ago');

      // Check if service is actually running via the API
      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning();

      if (!isRunning) {
        debugPrint('[ServiceWatchdog] ⚠️ Service is NOT running - attempting restart...');
        await _restartService();
        return;
      }

      // Service claims to be running, but check if heartbeat is stale
      if (lastHeartbeat > 0 && timeSinceHeartbeat > _heartbeatStaleThreshold) {
        debugPrint('[ServiceWatchdog] ⚠️ Service is running but heartbeat is stale (${timeSinceHeartbeat.inMinutes}min) - restarting...');
        await _restartService();
        return;
      }

      debugPrint('[ServiceWatchdog] ✅ Service is healthy');
    } catch (e, st) {
      debugPrint('[ServiceWatchdog] ❌ Error during health check: $e\n$st');
    }
  }

  /// Attempt to restart the background service
  static Future<void> _restartService() async {
    try {
      final service = FlutterBackgroundService();
      
      // First try to stop it if it's in a bad state
      try {
        service.invoke('stopService');
        await Future.delayed(const Duration(seconds: 2));
      } catch (e) {
        // Ignore stop errors - service might already be stopped
      }

      // Start the service
      await service.startService();
      await Future.delayed(const Duration(seconds: 3));

      // Verify it started
      final isRunningNow = await service.isRunning();
      if (isRunningNow) {
        debugPrint('[ServiceWatchdog] ✅ Service successfully restarted');
      } else {
        debugPrint('[ServiceWatchdog] ❌ Failed to restart service - will retry in ${_checkInterval.inMinutes} minutes');
      }
    } catch (e, st) {
      debugPrint('[ServiceWatchdog] ❌ Error restarting service: $e\n$st');
    }
  }

  /// Called FROM the background service to update the heartbeat.
  /// This should be called periodically (every ~1 minute) from the service.
  static Future<void> updateHeartbeat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(_heartbeatKey, now);
      // Don't log on every heartbeat to avoid log spam
    } catch (e) {
      debugPrint('[ServiceWatchdog] ❌ Failed to update heartbeat: $e');
    }
  }

  /// Get the last recorded heartbeat time (for debugging)
  static Future<DateTime?> getLastHeartbeat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final ms = prefs.getInt(_heartbeatKey);
      if (ms == null || ms == 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (e) {
      return null;
    }
  }
}
