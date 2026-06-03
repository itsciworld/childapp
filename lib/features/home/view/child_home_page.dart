import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/appColor/app_theme/app_gradient.dart';
import '../../../core/appimages/app_images.dart';
import '../../../core/storage/device_storage.dart';
import '../../../core/storage/identity_storage.dart';
import '../../../navigation_helper.dart';
import '../../call_logs/viewmodel/call_log_state.dart';
import '../../call_logs/viewmodel/call_log_viewmodel.dart';
import '../../contacts/viewmodel/contact_state.dart';
import '../../contacts/viewmodel/contact_viewmodel.dart';
import '../../sms/viewmodel/sms_state.dart';
import '../../sms/viewmodel/sms_viewmodel.dart';

/// The child's landing screen after setup.
///
/// Responsibilities:
/// - Greets the child and shows their basic details.
/// - Settings icon (top-right) → device permissions screen.
/// - Press-back-twice-to-exit guard.
/// - Asks the background service for an immediate sync pass on open; the
///   recurring upload keeps running every 5s via the background service.
class ChildHomePage extends ConsumerStatefulWidget {
  const ChildHomePage({super.key});

  @override
  ConsumerState<ChildHomePage> createState() => _ChildHomePageState();
}

class _ChildHomePageState extends ConsumerState<ChildHomePage>
    with TickerProviderStateMixin {
  static const Color _darkNavy = Color(0xFF1A237E);

  DateTime? _lastBackPress;
  Timer? _statusTimer;

  // Drives the one-shot staggered entrance of the cards.
  late final AnimationController _entrance;
  // Drives the continuous "live monitoring" pulse on the hero shield + dots.
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();

    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Ask the background isolate to run an immediate sync pass as soon as the
    // home screen is shown, on top of its every-5-seconds loop. We trigger it
    // via the service channel instead of reading the SMS / call-log / contacts
    // plugins here, because those native plugins (notably `call_log`) crash if
    // queried from two isolates at once — the background isolate is the single
    // owner of all device-plugin reads.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterBackgroundService().invoke('syncNow');
    });
    // While the screen is visible, poll the last-run time the background
    // isolate writes so "Last sync" ticks live without re-uploading.
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      ref.read(smsViewModelProvider.notifier).refreshStatus();
      ref.read(callLogViewModelProvider.notifier).refreshStatus();
      ref.read(contactViewModelProvider.notifier).refreshStatus();
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _entrance.dispose();
    _pulse.dispose();
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
          behavior: SnackBarBehavior.floating,
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
    final callLogState = ref.watch(callLogViewModelProvider);
    final contactState = ref.watch(contactViewModelProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPopInvoked,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        appBar: AppBar(
          titleSpacing: 20,
          title: Row(
            children: [
              Image.asset(
                AppImages.logo1,
                width: 32,
                height: 32,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: AppGradients.primaryButton,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child:
                      const Icon(Icons.shield, color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Vigil Child',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _darkNavy,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.white,
          foregroundColor: _darkNavy,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          centerTitle: false,
          actions: [
            IconButton(
              tooltip: 'Device permissions',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Nav.toPermissions(context),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: identityAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load profile: $e')),
          data: (identity) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
            children: [
              _Entrance(
                animation: _entrance,
                index: 0,
                child: _HeroCard(name: identity.childName, pulse: _pulse),
              ),
              const SizedBox(height: 16),
              _Entrance(
                animation: _entrance,
                index: 1,
                child: _ProfileCard(identity: identity),
              ),
              const SizedBox(height: 16),
              _Entrance(
                animation: _entrance,
                index: 2,
                child: _MonitoringCard(
                  state: smsState,
                  callLogState: callLogState,
                  contactState: contactState,
                ),
              ),
              const SizedBox(height: 16),
              _Entrance(
                animation: _entrance,
                index: 3,
                child: _DeviceCard(device: deviceAsync.asData?.value),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wraps [child] in a staggered fade + slide-up entrance, sequenced by [index].
class _Entrance extends StatelessWidget {
  const _Entrance({
    required this.animation,
    required this.index,
    required this.child,
  });

  final Animation<double> animation;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.12).clamp(0.0, 0.6);
    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(start, (start + 0.55).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) => Opacity(
        opacity: curved.value,
        child: Transform.translate(
          offset: Offset(0, 28 * (1 - curved.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// The gradient "protection active" hero with an animated pulsing shield.
class _HeroCard extends StatelessWidget {
  const _HeroCard({this.name, required this.pulse});

  final String? name;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final displayName = (name == null || name!.isEmpty) ? 'there' : name!;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppGradients.primaryButton,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppGradients.shadowColor(AppGradients.primaryButton),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WELCOME BACK',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _PulsingShield(pulse: pulse),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LiveDot(pulse: pulse, color: const Color(0xFF6EE7B7)),
                    const SizedBox(width: 8),
                    const Text(
                      'Protection active',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Icon(Icons.lock_outline,
                  color: Colors.white60, size: 18),
            ],
          ),
        ],
      ),
    );
  }
}

class _PulsingShield extends StatelessWidget {
  const _PulsingShield({required this.pulse});

  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        final t = pulse.value; // 0 → 1 → 0
        return SizedBox(
          width: 58,
          height: 58,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Expanding glow ring.
              Container(
                width: 44 + 14 * t,
                height: 44 + 14 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.18 * (1 - t)),
                ),
              ),
              child!,
            ],
          ),
        );
      },
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Icon(Icons.verified_user_outlined,
            color: Colors.white, size: 26),
      ),
    );
  }
}

/// A small blinking status dot.
class _LiveDot extends StatelessWidget {
  const _LiveDot({required this.pulse, required this.color});

  final Animation<double> pulse;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        return Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5 + 0.5 * pulse.value),
                blurRadius: 6 * pulse.value,
                spreadRadius: 1.5 * pulse.value,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Profile card — name + age only (IDs are intentionally hidden).
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.identity});

  final Identity identity;

  @override
  Widget build(BuildContext context) {
    final name = (identity.childName?.isNotEmpty ?? false)
        ? identity.childName!
        : 'Your profile';
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    final age = identity.childAge;
    final subtitle = (age != null && age > 0)
        ? 'Child account  •  $age yrs'
        : 'Child account';

    return _CardShell(
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AppGradients.secondary,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppGradients.shadowColor(AppGradients.secondary),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.verified,
                        size: 15, color: Color(0xFF2BA0CC)),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shield_outlined,
                size: 19, color: Color(0xFF16A34A)),
          ),
        ],
      ),
    );
  }
}

/// Normalised view of one sync stream's status for the monitoring tiles.
class _SyncView {
  const _SyncView(this.label, this.color, this.live, this.lastSyncedAt);

  final String label;
  final Color color;
  final bool live;
  final DateTime? lastSyncedAt;
}

class _MonitoringCard extends StatelessWidget {
  const _MonitoringCard({
    required this.state,
    required this.callLogState,
    required this.contactState,
  });

  final SmsState state;
  final CallLogState callLogState;
  final ContactState contactState;

  static const Color _green = Color(0xFF16A34A);
  static const Color _amber = Color(0xFFD97706);
  static const Color _grey = Color(0xFF9CA3AF);

  _SyncView _sms() {
    final (label, color, live) = switch (state.status) {
      SmsSyncStatus.syncing => ('Syncing…', _amber, false),
      SmsSyncStatus.synced => ('Active', _green, true),
      SmsSyncStatus.error => ('Retrying', _amber, false),
      SmsSyncStatus.idle => ('Starting…', _grey, false),
    };
    return _SyncView(label, color, live, state.lastSyncedAt);
  }

  _SyncView _calls() {
    final (label, color, live) = switch (callLogState.status) {
      CallLogSyncStatus.syncing => ('Syncing…', _amber, false),
      CallLogSyncStatus.synced => ('Active', _green, true),
      CallLogSyncStatus.error => ('Retrying', _amber, false),
      CallLogSyncStatus.idle => ('Starting…', _grey, false),
    };
    return _SyncView(label, color, live, callLogState.lastSyncedAt);
  }

  _SyncView _contacts() {
    final (label, color, live) = switch (contactState.status) {
      ContactSyncStatus.syncing => ('Syncing…', _amber, false),
      ContactSyncStatus.synced => ('Active', _green, true),
      ContactSyncStatus.error => ('Retrying', _amber, false),
      ContactSyncStatus.idle => ('Starting…', _grey, false),
    };
    return _SyncView(label, color, live, contactState.lastSyncedAt);
  }

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(icon: Icons.shield_outlined, title: 'Monitoring'),
          const SizedBox(height: 14),
          _MonitorTile(
            icon: Icons.sms_outlined,
            accent: const Color(0xFF2BA0CC),
            title: 'Messages',
            view: _sms(),
          ),
          const SizedBox(height: 10),
          _MonitorTile(
            icon: Icons.call_outlined,
            accent: const Color(0xFF16A34A),
            title: 'Call logs',
            view: _calls(),
          ),
          const SizedBox(height: 10),
          _MonitorTile(
            icon: Icons.contacts_outlined,
            accent: const Color(0xFF7C3AED),
            title: 'Contacts',
            view: _contacts(),
          ),
        ],
      ),
    );
  }
}

class _MonitorTile extends StatelessWidget {
  const _MonitorTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.view,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final _SyncView view;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEF0F4)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 21, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  view.lastSyncedAt == null
                      ? 'Waiting for first sync'
                      : 'Last sync ${_formatTime(view.lastSyncedAt!)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _StatusChip(view: view),
        ],
      ),
    );
  }

  static String _formatTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.view});

  final _SyncView view;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: view.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: view.color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            view.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: view.color,
            ),
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
    final name = (device?.name?.isNotEmpty ?? false) ? device!.name! : '—';
    final id = (device?.id?.isNotEmpty ?? false) ? device!.id! : '—';
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
              icon: Icons.smartphone_outlined, title: 'Device'),
          const SizedBox(height: 14),
          _DeviceRow(icon: Icons.devices_outlined, label: 'Name', value: name),
          const SizedBox(height: 12),
          _DeviceRow(
              icon: Icons.fingerprint_outlined, label: 'Device ID', value: id),
        ],
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
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
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
        ),
      ],
    );
  }
}

/// A small section heading with a leading icon.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: const Color(0xFF6B7280)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF374151),
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

/// White rounded card container with a soft shadow.
class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEF0F4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
