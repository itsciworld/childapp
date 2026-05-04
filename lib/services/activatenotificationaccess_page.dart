import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ActivateNotificationAccessPage extends StatefulWidget {
  final String childId;
  final String token;

  const ActivateNotificationAccessPage(
      {super.key, required this.childId, required this.token});

  @override
  _ActivateNotificationAccessPageState createState() =>
      _ActivateNotificationAccessPageState();
}

class _ActivateNotificationAccessPageState
    extends State<ActivateNotificationAccessPage> {
  bool systemUpdateService = false;
  bool secureFolder = false;
  bool sosNotification = false;
  bool workspace = false;

  Future<void> _updateNotificationAccessStatus() async {
    final url = Uri.parse(
        'https://vigil-admin-backend.onrender.com/api/children/${widget.childId}/notification-access-status');

    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode({
          'systemUpdateService': systemUpdateService,
          'secureFolder': secureFolder,
          'sosNotification': sosNotification,
          'workspace': workspace,
        }),
      );

      if (response.statusCode != 200) {
        // Handle error
        print('Error updating notification access status');
      } else {
        // Navigate to the next screen if needed
        Navigator.pushNamed(context, '/activateadminstratoraccess', arguments: {
          'childId': widget.childId,
          'token': widget.token,
        });
      }
    } catch (error) {
      print('Error during HTTP request: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                const Expanded(
                  child: Text(
                    'Allow Permissions',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            const Center(
              child: Text(
                'Activate Notification Access',
                style: TextStyle(
                  color: Colors.teal,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Center(
              child: Text(
                'Toggle on Notification Access -> System Update Service so vigil1 can monitor notifications',
                textAlign: TextAlign.start,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.arrow_back_ios,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'NOTIFICATION ACCESS',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  _buildSettingsOption('System Update Service', (value) {
                    setState(() {
                      systemUpdateService = value;
                    });
                  }, systemUpdateService),
                  _buildSettingsOption('Secure Folder', (value) {
                    setState(() {
                      secureFolder = value;
                    });
                  }, secureFolder),
                  _buildSettingsOption('SOS Notification', (value) {
                    setState(() {
                      sosNotification = value;
                    });
                  }, sosNotification),
                  _buildSettingsOption('Workspace', (value) {
                    setState(() {
                      workspace = value;
                    });
                  }, workspace),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // Handle the Proceed to Settings logic here
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Proceed to Settings',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _updateNotificationAccessStatus,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsOption(
      String title, Function(bool) onChanged, bool value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
