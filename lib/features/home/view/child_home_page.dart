import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/appColor/app_theme/app_gradient.dart';
import '../../../core/appimages/app_images.dart';
import '../../../core/storage/device_storage.dart';
import '../../../core/storage/identity_storage.dart';
import '../../../navigation_helper.dart';
import '../../../route_names.dart';
import '../../call_logs/viewmodel/call_log_state.dart';
import '../../call_logs/viewmodel/call_log_viewmodel.dart';
import '../../contacts/viewmodel/contact_state.dart';
import '../../contacts/viewmodel/contact_viewmodel.dart';
import '../../logout/viewmodel/logout_state.dart';
import '../../logout/viewmodel/logout_viewmodel.dart';
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

  // Drives the one-shot staggered entrance of the cards. Started the moment
  // the profile data finishes loading (not at mount), so the reveal plays in
  // sync with the data actually appearing on screen.
  late final AnimationController _entrance;
  bool _entranceStarted = false;
  // Drives the continuous "live monitoring" pulse on the hero shield + dots.
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();

    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
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

  /// Confirms intent, then asks the [LogoutViewModel] to log out. The success /
  /// error handling (snackbar + navigation) happens in the [ref.listen] below.
  Future<void> _confirmAndLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'This device will stop monitoring and you will need to pair it '
          'again to resume.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFD92D20)),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(logoutViewModelProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final identityAsync = ref.watch(identityProvider);
    final deviceAsync = ref.watch(storedDeviceProvider);
    final smsState = ref.watch(smsViewModelProvider);
    final callLogState = ref.watch(callLogViewModelProvider);
    final contactState = ref.watch(contactViewModelProvider);
    final logoutState = ref.watch(logoutViewModelProvider);

    // React to logout results: show the server message (or error) in a
    // snackbar and, on success, drop the user back to the onboarding flow.
    ref.listen<LogoutState>(logoutViewModelProvider, (prev, next) {
      if (next.status == LogoutStatus.success) {
        final messenger = ScaffoldMessenger.of(context);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(next.message ?? 'Logged out successfully.'),
            ),
          );
        Navigator.of(context).pushNamedAndRemoveUntil(
          RouteNames.terms,
          (route) => false,
        );
        ref.read(logoutViewModelProvider.notifier).reset();
      } else if (next.status == LogoutStatus.error) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(next.errorMessage ?? 'Could not log out.'),
            ),
          );
        ref.read(logoutViewModelProvider.notifier).reset();
      }
    });

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
            IconButton(
              tooltip: 'Log out',
              icon: logoutState.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout),
              onPressed: logoutState.isLoading ? null : _confirmAndLogout,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: identityAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load profile: $e')),
          data: (identity) {
            // Kick off the entrance the first time real data is available, so
            // the cards animate in exactly when the data does — covering both
            // the async-resolve and the already-cached cases.
            if (!_entranceStarted) {
              _entranceStarted = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _entrance.forward(from: 0);
              });
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              children: [
                _Entrance(
                  animation: _entrance,
                  index: 0,
                  child: _WelcomeCard(
                    identity: identity,
                    device: deviceAsync.asData?.value,
                    pulse: _pulse,
                    entrance: _entrance,
                  ),
                ),
                const SizedBox(height: 16),
                _Entrance(
                  animation: _entrance,
                  index: 1,
                  child: _MonitoringCard(
                    state: smsState,
                    callLogState: callLogState,
                    contactState: contactState,
                  ),
                ),
              ],
            );
          },
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
      builder: (context, child) {
        final t = curved.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 32 * (1 - t)),
            child: Transform.scale(
              scale: 0.96 + 0.04 * t,
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// Reveals [child] with a fade + small rise as [animation] sweeps its
/// [start]–[end] sub-interval. Lets the welcome-card values cascade in just
/// after the card frame itself has appeared.
class _RevealItem extends StatelessWidget {
  const _RevealItem({
    required this.animation,
    required this.start,
    required this.end,
    required this.child,
  });

  final Animation<double> animation;
  final double start;
  final double end;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) => Opacity(
        opacity: curved.value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - curved.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// The gradient hero card holding every child detail in one place:
/// greeting + name, an animated pulsing shield, and an age · device · OS
/// stat row whose values cascade in (driven by [entrance]) as the data loads.
class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({
    required this.identity,
    required this.device,
    required this.pulse,
    required this.entrance,
  });

  final Identity identity;
  final StoredDevice? device;
  final Animation<double> pulse;
  final Animation<double> entrance;

  @override
  Widget build(BuildContext context) {
    final rawName = identity.childName;
    final displayName =
        (rawName == null || rawName.isEmpty) ? 'there' : rawName;
    final age = identity.childAge;
    final deviceName =
        (device?.name?.isNotEmpty ?? false) ? device!.name! : 'This device';
    final osLabel = _platformLabel();
    final osIcon = Platform.isIOS ? Icons.apple : Icons.android;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppGradients.primaryButton,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: AppGradients.shadowColor(AppGradients.primaryButton),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting + name (left); pulsing shield with a live badge (right).
          Row(
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
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _PulsingShield(pulse: pulse),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 16),
          // Detail columns: age · device · system. Device gets the widest
          // share and may wrap onto two lines so longer hardware names stay
          // readable.
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _RevealItem(
                    animation: entrance,
                    start: 0.45,
                    end: 0.72,
                    child: _HeroStat(
                      icon: Icons.cake_outlined,
                      label: 'AGE',
                      value: (age != null && age > 0) ? '$age yrs' : '—',
                    ),
                  ),
                ),
                const _StatDivider(),
                Expanded(
                  flex: 6,
                  child: _RevealItem(
                    animation: entrance,
                    start: 0.55,
                    end: 0.82,
                    child: _HeroStat(
                      icon: Icons.smartphone_outlined,
                      label: 'DEVICE',
                      value: deviceName,
                      maxLines: 2,
                    ),
                  ),
                ),
                const _StatDivider(),
                Expanded(
                  flex: 4,
                  child: _RevealItem(
                    animation: entrance,
                    start: 0.65,
                    end: 0.92,
                    child: _HeroStat(
                      icon: osIcon,
                      label: 'OS',
                      value: osLabel,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The running platform name only — "Android" / "iOS" (no version).
  static String _platformLabel() {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    final os = Platform.operatingSystem;
    return os.isEmpty ? 'Device' : '${os[0].toUpperCase()}${os.substring(1)}';
  }
}

/// One labelled detail column for the hero stats row.
class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.value,
    this.icon,
    this.maxLines = 1,
  });

  final String label;
  final String value;
  final IconData? icon;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    const valueStyle = TextStyle(
      color: Colors.white,
      fontSize: 14.5,
      fontWeight: FontWeight.w700,
      height: 1.15,
    );

    final Widget valueWidget = Text(
      value,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: valueStyle,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Label row: small icon + caption, leaving the value its full width.
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.65)),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        valueWidget,
      ],
    );
  }
}

/// A thin vertical separator between hero stat columns.
class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.white.withValues(alpha: 0.15),
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
// class _LiveDot extends StatelessWidget {
//   const _LiveDot({required this.pulse, required this.color});

//   final Animation<double> pulse;
//   final Color color;

//   @override
//   Widget build(BuildContext context) {
//     return AnimatedBuilder(
//       animation: pulse,
//       builder: (context, _) {
//         return Container(
//           width: 9,
//           height: 9,
//           decoration: BoxDecoration(
//             shape: BoxShape.circle,
//             color: color,
//             boxShadow: [
//               BoxShadow(
//                 color: color.withValues(alpha: 0.5 + 0.5 * pulse.value),
//                 blurRadius: 6 * pulse.value,
//                 spreadRadius: 1.5 * pulse.value,
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }
// }

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
