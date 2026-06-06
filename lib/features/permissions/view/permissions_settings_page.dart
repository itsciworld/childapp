import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/appColor/app_theme/app_gradient.dart';
import '../../../core/utils/app_toast.dart';
import '../viewmodel/permissions_settings_viewmodel.dart';
import '../viewmodel/permissions_state.dart';

/// Full permissions settings screen. Loads the child's current permission
/// configuration from the backend, lets it be edited, and saves it back —
/// all via [PermissionsSettingsViewModel] (Repository + Dio + EnvConfig),
/// like the rest of the app.
class PermissionsSettingsPage extends ConsumerStatefulWidget {
  const PermissionsSettingsPage({super.key});

  @override
  ConsumerState<PermissionsSettingsPage> createState() =>
      _PermissionsSettingsPageState();
}

class _PermissionsSettingsPageState
    extends ConsumerState<PermissionsSettingsPage>
    with WidgetsBindingObserver {
  static const Color _darkNavy = Color(0xFF1A237E);
  static const Color _accent = Color(0xFF15BEB5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(permissionsSettingsViewModelProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Data Access permissions granted/revoked on the system settings screen
    // return no callback, so re-read every permission's real status when the
    // app comes back to the foreground — flipping the toggles to match.
    if (state == AppLifecycleState.resumed) {
      ref.read(permissionsSettingsViewModelProvider.notifier).refreshOsState();
    }
  }

  Future<void> _save() async {
    final notifier = ref.read(permissionsSettingsViewModelProvider.notifier);
    final ok = await notifier.save();
    if (!mounted) return;
    if (ok) {
      final serverMessage =
          ref.read(permissionsSettingsViewModelProvider).successMessage;
      showAppToast(
        context: context,
        title: 'Success',
        subtitle: (serverMessage != null && serverMessage.isNotEmpty)
            ? serverMessage
            : 'Permissions updated successfully',
        type: ToastType.success,
      );
    } else {
      showAppToast(
        context: context,
        title: 'Error',
        subtitle: ref.read(permissionsSettingsViewModelProvider).errorMessage ??
            'Failed to update permissions',
        type: ToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Surface load failures as a toast.
    ref.listen(permissionsSettingsViewModelProvider, (prev, next) {
      final wasLoading = prev?.loading ?? false;
      if (wasLoading && !next.loading && next.errorMessage != null) {
        showAppToast(
          context: context,
          title: 'Error',
          subtitle: next.errorMessage!,
          type: ToastType.error,
        );
      }
    });

    final state = ref.watch(permissionsSettingsViewModelProvider);
    final notifier = ref.read(permissionsSettingsViewModelProvider.notifier);
    final config = state.config;
    final notif = config.notificationAccess;
    final data = config.dataAccess;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Permissions Settings',
          style: TextStyle(
            color: _darkNavy,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: _darkNavy,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: _darkNavy),
      ),
      // Render the UI immediately; the backend config loads in the background
      // and fills the toggles in. A thin top bar signals the refresh instead
      // of hiding the page behind a full-screen spinner.
      body: Column(
        children: [
          SizedBox(
            height: 2,
            child: state.loading
                ? const LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation(_accent),
                  )
                : null,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Permissions Section
                  _buildSectionHeader(
                    'Main Permissions',
                    Icons.security_rounded,
                  ),
                  const SizedBox(height: 12),
                  _buildPermissionCard([
                    _buildToggleTile(
                      title: 'Scan Device for Security',
                      subtitle: 'Allow scanning device for security threats',
                      value: config.scanDeviceForSecurity,
                      onChanged: (val) => notifier
                          .update(config.copyWith(scanDeviceForSecurity: val)),
                      icon: Icons.security_update_good_rounded,
                    ),
                    _buildDivider(),
                    _buildToggleTile(
                      title: 'Improve Harmful Detection',
                      subtitle: 'Help improve harmful content detection',
                      value: config.improveHarmfulDetection,
                      onChanged: (val) => notifier
                          .update(config.copyWith(improveHarmfulDetection: val)),
                      icon: Icons.shield_rounded,
                    ),
                    _buildDivider(),
                    _buildToggleTile(
                      title: 'System Update Service',
                      subtitle: 'Enable system update service',
                      value: config.systemUpdateService,
                      onChanged: (val) => notifier
                          .update(config.copyWith(systemUpdateService: val)),
                      icon: Icons.system_update_rounded,
                    ),
                    _buildDivider(),
                    _buildToggleTile(
                      title: 'Allow Usage Tracking',
                      subtitle: 'Track app usage statistics',
                      value: config.allowUsageTracking,
                      onChanged: (val) => notifier
                          .update(config.copyWith(allowUsageTracking: val)),
                      icon: Icons.analytics_rounded,
                    ),
                    _buildDivider(),
                    _buildToggleTile(
                      title: 'Administrator Access',
                      subtitle: 'Grant administrator privileges',
                      value: config.administratorAccess,
                      onChanged: (val) => notifier
                          .update(config.copyWith(administratorAccess: val)),
                      icon: Icons.admin_panel_settings_rounded,
                    ),
                    _buildDivider(),
                    _buildToggleTile(
                      title: 'Battery Optimization',
                      subtitle: 'Allow battery optimization',
                      value: config.batteryOptimizationAllowed,
                      onChanged: (val) => notifier.update(
                          config.copyWith(batteryOptimizationAllowed: val)),
                      icon: Icons.battery_charging_full_rounded,
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // Notification Access Section
                  _buildSectionHeader(
                    'Notification Access',
                    Icons.notifications_rounded,
                  ),
                  const SizedBox(height: 12),
                  _buildPermissionCard([
                    _buildToggleTile(
                      title: 'System Update Service',
                      subtitle: 'Receive system update notifications',
                      value: notif.systemUpdateService,
                      onChanged: (val) => notifier.update(config.copyWith(
                          notificationAccess:
                              notif.copyWith(systemUpdateService: val))),
                      icon: Icons.notification_important_rounded,
                    ),
                    _buildDivider(),
                    _buildToggleTile(
                      title: 'Secure Folder',
                      subtitle: 'Access secure folder notifications',
                      value: notif.secureFolder,
                      onChanged: (val) => notifier.update(config.copyWith(
                          notificationAccess:
                              notif.copyWith(secureFolder: val))),
                      icon: Icons.folder_special_rounded,
                    ),
                    _buildDivider(),
                    _buildToggleTile(
                      title: 'SOS Notification',
                      subtitle: 'Enable emergency SOS notifications',
                      value: notif.sosNotification,
                      onChanged: (val) => notifier.update(config.copyWith(
                          notificationAccess:
                              notif.copyWith(sosNotification: val))),
                      icon: Icons.sos_rounded,
                    ),
                    _buildDivider(),
                    _buildToggleTile(
                      title: 'Workspace',
                      subtitle: 'Access workspace notifications',
                      value: notif.workspace,
                      onChanged: (val) => notifier.update(config.copyWith(
                          notificationAccess: notif.copyWith(workspace: val))),
                      icon: Icons.work_rounded,
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // Data Access Section
                  _buildSectionHeader(
                    'Data Access',
                    Icons.storage_rounded,
                  ),
                  const SizedBox(height: 12),
                  _buildPermissionCard([
                    _buildToggleTile(
                      title: 'Messages',
                      subtitle: 'Access SMS and messaging data',
                      value: data.messages,
                      onChanged: (val) =>
                          notifier.toggleDataPermission(PermissionKey.sms, val),
                      icon: Icons.message_rounded,
                    ),
                    _buildDivider(),
                    _buildToggleTile(
                      title: 'Contacts',
                      subtitle: 'Access contact list',
                      value: data.contacts,
                      onChanged: (val) => notifier.toggleDataPermission(
                          PermissionKey.contacts, val),
                      icon: Icons.contacts_rounded,
                    ),
                    _buildDivider(),
                    _buildToggleTile(
                      title: 'Call Log',
                      subtitle: 'Access call history',
                      value: data.callLog,
                      onChanged: (val) => notifier.toggleDataPermission(
                          PermissionKey.phone, val),
                      icon: Icons.call_rounded,
                    ),
                    _buildDivider(),
                    _buildToggleTile(
                      title: 'Calendar',
                      subtitle: 'Access calendar events',
                      value: data.calendar,
                      onChanged: (val) => notifier.update(config.copyWith(
                          dataAccess: data.copyWith(calendar: val))),
                      icon: Icons.calendar_today_rounded,
                    ),
                    _buildDivider(),
                    _buildToggleTile(
                      title: 'Location',
                      subtitle: 'Access GPS location',
                      value: data.location,
                      onChanged: (val) => notifier.toggleDataPermission(
                          PermissionKey.location, val),
                      icon: Icons.location_on_rounded,
                    ),
                    _buildDivider(),
                    _buildToggleTile(
                      title: 'App Usage',
                      subtitle: 'Track which apps are used and for how long',
                      value: data.appUsage,
                      onChanged: (val) => notifier.toggleDataPermission(
                          PermissionKey.usageAccess, val),
                      icon: Icons.bar_chart_rounded,
                    ),
                  ]),

                  const SizedBox(height: 32),

                  // Save Button — app's standard navy→green gradient.
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: state.saving
                            ? AppGradients.disabled
                            : AppGradients.primaryButton,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppGradients.shadowColor(
                                AppGradients.primaryButton),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: state.saving ? null : _save,
                          child: Center(
                            child: state.saving
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor:
                                          AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'Save Permissions',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: _accent,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildToggleTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: value
                  ? _accent.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: value ? _accent : Colors.grey,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.9,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: _accent,
              activeTrackColor: _accent.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
        height: 1,
        color: Colors.grey[200],
      ),
    );
  }
}
