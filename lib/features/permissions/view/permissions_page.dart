import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/appColor/app_theme/app_gradient.dart';
import '../../../core/appimages/app_images.dart';
import '../../../navigation_helper.dart';
import '../viewmodel/permissions_state.dart';
import '../viewmodel/permissions_viewmodel.dart';

/// Single, toggle-based permissions screen. Replaces the eight individual
/// service pages — each row requests one OS permission via
/// [PermissionsViewModel].
class PermissionsPage extends ConsumerWidget {
  const PermissionsPage({super.key});

  static const Color _darkNavy = Color(0xFF1A237E);
  static const Color _accentGreen = Color(0xFF15BEB5);

  /// Minimum permissions the child must grant before they can continue.
  static const int _minGrantedToContinue = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(permissionsViewModelProvider);
    final notifier = ref.read(permissionsViewModelProvider.notifier);
    final grantedCount = state.granted.values.where((g) => g).length;
    final total = PermissionKey.values.length;
    final canContinue = grantedCount >= _minGrantedToContinue;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      // Only surfaces once the child has granted at least
      // [_minGrantedToContinue] permissions.
      bottomNavigationBar: canContinue
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppGradients.primaryButton,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Nav.toChildHome(context),
                      child: const Center(
                        child: Text(
                          'Continue',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
      appBar: AppBar(
        title: const Text(
          'Device Permissions',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: _darkNavy,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: _darkNavy,
        elevation: 0,
        centerTitle: false,
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: _accentGreen,
              onRefresh: notifier.refreshAll,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _HeaderCard(granted: grantedCount, total: total),
                  const _SectionTitle('Required permissions'),
                  for (final key in PermissionKey.values)
                    _PermissionTile(
                      info: _info[key]!,
                      granted: state.isGranted(key),
                      busy: state.isBusy(key),
                      onTap: () => notifier.toggle(key, !state.isGranted(key)),
                    ),
                ],
              ),
            ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.granted, required this.total});

  final int granted;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : granted / total;
    final allGranted = granted == total;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.all(18),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.asset(
                  AppImages.slogoWhite,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.shield_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vigil Protection Setup',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Enable access so Vigil can keep your child safe.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF15BEB5)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                allGranted
                    ? 'All set — your device is protected.'
                    : '$granted of $total enabled',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6B7280),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.info,
    required this.granted,
    required this.busy,
    required this.onTap,
  });

  final _PermissionInfo info;
  final bool granted;
  final bool busy;
  final VoidCallback onTap;

  static const Color _accentGreen = Color(0xFF15BEB5);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: granted ? _accentGreen.withValues(alpha: 0.4) : Colors.grey.shade200,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: busy ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: granted
                        ? _accentGreen.withValues(alpha: 0.12)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    info.icon,
                    color: granted ? _accentGreen : Colors.grey.shade600,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.label,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        info.description,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                busy
                    ? const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(_accentGreen),
                        ),
                      )
                    : Switch.adaptive(
                        value: granted,
                        onChanged: (_) => onTap(),
                        activeThumbColor: _accentGreen,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionInfo {
  const _PermissionInfo(this.label, this.description, this.icon);
  final String label;
  final String description;
  final IconData icon;
}

const Map<PermissionKey, _PermissionInfo> _info = {
  PermissionKey.location: _PermissionInfo(
    'Location',
    'See where this device is in real time.',
    Icons.location_on_outlined,
  ),
  PermissionKey.contacts: _PermissionInfo(
    'Contacts',
    'View who your child saves on this phone.',
    Icons.contacts_outlined,
  ),
  PermissionKey.sms: _PermissionInfo(
    'SMS',
    'Monitor incoming and outgoing text messages.',
    Icons.sms_outlined,
  ),
  PermissionKey.phone: _PermissionInfo(
    'Call Log',
    'See incoming and outgoing call history.',
    Icons.call_outlined,
  ),
  PermissionKey.photos: _PermissionInfo(
    'Photos & Media',
    'Access photos and videos stored on the device.',
    Icons.photo_library_outlined,
  ),
  PermissionKey.notification: _PermissionInfo(
    'Notifications',
    'Show the ongoing protection notification.',
    Icons.notifications_outlined,
  ),
  PermissionKey.usageAccess: _PermissionInfo(
    'App Usage Access',
    'Track which apps your child uses and for how long.',
    Icons.bar_chart_outlined,
  ),
  PermissionKey.ignoreBatteryOptimizations: _PermissionInfo(
    'Ignore Battery Optimization',
    'Keep Vigil running reliably in the background.',
    Icons.battery_charging_full_outlined,
  ),
};
