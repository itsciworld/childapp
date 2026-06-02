import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/appColor/app_theme/app_gradient.dart';
import '../../../core/storage/device_storage.dart';
import '../../../core/storage/identity_storage.dart';
import '../../../navigation_helper.dart';
import '../../sms/viewmodel/sms_state.dart';
import '../../sms/viewmodel/sms_viewmodel.dart';

/// The child's landing screen after setup.
///
/// Responsibilities:
/// - Greets the child and shows their basic details.
/// - Settings icon (top-right) → device permissions screen.
/// - Press-back-twice-to-exit guard.
/// - Triggers an immediate (foreground) SMS sync on open; the recurring
///   background upload keeps running via the background service.
class ChildHomePage extends ConsumerStatefulWidget {
  const ChildHomePage({super.key});

  @override
  ConsumerState<ChildHomePage> createState() => _ChildHomePageState();
}

class _ChildHomePageState extends ConsumerState<ChildHomePage> {
  static const Color _darkNavy = Color(0xFF1A237E);

  DateTime? _lastBackPress;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    // Fire an immediate sync as soon as the home screen is shown — this fetches
    // SMS and posts them right away (and logs the result), on top of the
    // every-5-seconds background upload.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(smsViewModelProvider.notifier).sync();
    });
    // While the screen is visible, poll the last-run time the background
    // isolate writes so "Last sync" ticks live without re-uploading.
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      ref.read(smsViewModelProvider.notifier).refreshStatus();
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  void _onPopInvoked(bool didPop, Object? result) {
    if (didPop) return;
    final now = DateTime.now();
    final withinWindow = _lastBackPress != null &&
        now.difference(_lastBackPress!) < const Duration(seconds: 2);

    if (withinWindow) {
      // Second press in time — leave the app.
      SystemNavigator.pop();
      return;
    }

    _lastBackPress = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final identityAsync = ref.watch(identityProvider);
    final deviceAsync = ref.watch(storedDeviceProvider);
    final smsState = ref.watch(smsViewModelProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPopInvoked,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: AppBar(
          title: const Text(
            'Vigil',
            style: TextStyle(fontWeight: FontWeight.w800, color: _darkNavy),
          ),
          backgroundColor: Colors.white,
          foregroundColor: _darkNavy,
          elevation: 0,
          centerTitle: false,
          actions: [
            IconButton(
              tooltip: 'Device permissions',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Nav.toPermissions(context),
            ),
          ],
        ),
        body: identityAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load profile: $e')),
          data: (identity) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _WelcomeCard(name: identity.childName),
              const SizedBox(height: 16),
              _InfoCard(identity: identity),
              const SizedBox(height: 16),
              _DeviceCard(device: deviceAsync.asData?.value),
              const SizedBox(height: 16),
              _MonitoringCard(state: smsState),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final displayName = (name == null || name!.isEmpty) ? 'there' : name!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppGradients.primaryButton,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppGradients.shadowColor(AppGradients.primaryButton),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.waving_hand_outlined,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, $displayName!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Vigil is keeping this device protected.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.identity});

  final Identity identity;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: 'Profile',
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.person_outline,
            label: 'Name',
            value: identity.childName ?? '—',
          ),
          _InfoRow(
            icon: Icons.cake_outlined,
            label: 'Age',
            value: identity.childAge?.toString() ?? '—',
          ),
          _InfoRow(
            icon: Icons.badge_outlined,
            label: 'Child ID',
            value: identity.childId ?? '—',
          ),
          _InfoRow(
            icon: Icons.family_restroom_outlined,
            label: 'Parent ID',
            value: identity.parentId ?? '—',
          ),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({this.device});

  final StoredDevice? device;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: 'Device',
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.smartphone_outlined,
            label: 'Device name',
            value: (device?.name?.isNotEmpty ?? false) ? device!.name! : '—',
          ),
          _InfoRow(
            icon: Icons.fingerprint_outlined,
            label: 'Device ID',
            value: (device?.id?.isNotEmpty ?? false) ? device!.id! : '—',
          ),
        ],
      ),
    );
  }
}

class _MonitoringCard extends StatelessWidget {
  const _MonitoringCard({required this.state});

  final SmsState state;

  @override
  Widget build(BuildContext context) {
    final last = state.lastResponse;
    final syncedAt = state.lastSyncedAt;
    final statusText = switch (state.status) {
      SmsSyncStatus.syncing => 'Syncing…',
      SmsSyncStatus.synced => 'Active',
      SmsSyncStatus.error => 'Active (retrying)',
      SmsSyncStatus.idle => 'Starting…',
    };

    return _CardShell(
      title: 'Monitoring',
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.sync_outlined,
            label: 'SMS sync',
            value: statusText,
          ),
          _InfoRow(
            icon: Icons.schedule_outlined,
            label: 'Last sync',
            value: syncedAt == null ? '—' : _formatTime(syncedAt),
          ),
          if (last != null)
            _InfoRow(
              icon: Icons.upload_outlined,
              label: 'Last upload',
              value: 'saved ${last.saved ?? 0}, '
                  'dup ${last.duplicates ?? 0}, total ${last.total ?? 0}',
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF15BEB5)),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
