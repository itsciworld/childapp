import 'package:flutter/material.dart';
import 'package:vigil1/core/appColor/app_theme/app_gradient.dart';
import 'package:vigil1/core/widgets/custom_button.dart';

import '../navigation_helper.dart';

/// Lists the device permissions Vigil needs and, on confirmation, kicks off
/// the step-by-step activation flow.
class AllowPermissionsPage extends StatelessWidget {
  final String childId;
  final String token;

  const AllowPermissionsPage(
      {super.key, required this.childId, required this.token});

  /// The permissions shown to the user, in the order they are activated.
  static const List<_Permission> _permissions = [
    _Permission(Icons.shield_outlined, 'Disable Google Play Protect'),
    _Permission(Icons.accessibility_new, 'Activate Accessibility'),
    _Permission(Icons.supervisor_account_outlined, 'Activate Supervision'),
    _Permission(
        Icons.notifications_active_outlined, 'Activate Notification Access'),
    _Permission(
        Icons.admin_panel_settings_outlined, 'Activate Administrative Access'),
    _Permission(Icons.storage_outlined, 'Activate Data Access'),
    _Permission(
        Icons.battery_charging_full_outlined, 'Ignore Battery Optimization'),
    _Permission(Icons.autorenew, 'Enable Background Running / AutoStart'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        centerTitle: true,
        title: const Text(
          'Allow Permissions',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.verified_user_outlined,
                    size: 48,
                    color: Colors.teal.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'A few permissions to get started',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'To help protect your child, Vigil needs access to the '
                'following features on this device.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.15),
                        spreadRadius: 1,
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _permissions.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      indent: 64,
                      color: Colors.grey.shade200,
                    ),
                    itemBuilder: (context, index) {
                      final permission = _permissions[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal.withValues(alpha: 0.1),
                          child: Icon(
                            permission.icon,
                            color: Colors.teal.shade600,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          permission.label,
                          style: const TextStyle(fontSize: 15),
                        ),
                        trailing: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // SizedBox(
              //   width: double.infinity,
              //   child: ElevatedButton(
              //     onPressed: () => _showConfirmationDialog(context),
              //     style: ElevatedButton.styleFrom(
              //       backgroundColor: Colors.black,
              //       padding: const EdgeInsets.symmetric(vertical: 16),
              //       shape: RoundedRectangleBorder(
              //         borderRadius: BorderRadius.circular(12),
              //       ),
              //     ),
              //     child: const Text(
              //       'Continue',
              //       style: TextStyle(color: Colors.white, fontSize: 18),
              //     ),
              //   ),
              // ),
              CustomButton(
                isLoading: false,
                label: 'Continue',
                onTap: () => _showConfirmationDialog(context),
                height: 50,
                gradient: AppGradients.primaryButton,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Allow permissions?'),
          content: const Text(
            'You are about to allow this application to appear over other '
            'apps during setup. Are you sure?',
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('No'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Close the dialog first, then start the setup flow.
                      Navigator.of(dialogContext).pop();
                      Nav.toPermissions(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Yes',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// A single permission row: an icon and its label.
class _Permission {
  const _Permission(this.icon, this.label);

  final IconData icon;
  final String label;
}
