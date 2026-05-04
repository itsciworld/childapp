import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ActivateDataAccess extends StatefulWidget {
  final String childId;
  final String token;

  const ActivateDataAccess(
      {super.key, required this.childId, required this.token});

  @override
  _ActivateDataAccessState createState() => _ActivateDataAccessState();
}

class _ActivateDataAccessState extends State<ActivateDataAccess> {
  bool messages = false;
  bool contacts = false;
  bool callLog = false;
  bool calendar = false;
  bool location = false;

  Future<void> _updateDataAccessStatus() async {
    final url = Uri.parse(
        'https://vigil-admin-backend.onrender.com/api/children/${widget.childId}/data-access-status');

    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode({
          'messages': messages,
          'contacts': contacts,
          'call_log': callLog,
          'calendar': calendar,
          'location': location,
        }),
      );

      if (response.statusCode != 200) {
        print('Error updating data access status');
      } else {
        Navigator.pushNamed(context, '/batteryoptimization', arguments: {
          'childId': widget.childId,
          'token': widget.token,
        });
      }
    } catch (error) {
      print('Error during HTTP request: $error');
    }
  }

  void _allowAll() {
    setState(() {
      messages = true;
      contacts = true;
      callLog = true;
      calendar = true;
      location = true;
    });
    _updateDataAccessStatus();
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
                'Activate Data Access',
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
                'Select "Allow All" to enable the application to access the following data:',
                textAlign: TextAlign.center,
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
                  _buildSettingsOption(
                    Icons.message,
                    'Messages',
                    'Allow Vigil1 to read Messages',
                    (value) {
                      setState(() {
                        messages = value;
                      });
                    },
                    messages,
                  ),
                  _buildSettingsOption(
                    Icons.contacts,
                    'Contacts',
                    'Allow Vigil1 to access contacts',
                    (value) {
                      setState(() {
                        contacts = value;
                      });
                    },
                    contacts,
                  ),
                  _buildSettingsOption(
                    Icons.call,
                    'Call Log',
                    'Allow Vigil1 to access Call logs',
                    (value) {
                      setState(() {
                        callLog = value;
                      });
                    },
                    callLog,
                  ),
                  _buildSettingsOption(
                    Icons.calendar_today,
                    'Calendar',
                    'Allow Vigil1 to access calendar',
                    (value) {
                      setState(() {
                        calendar = value;
                      });
                    },
                    calendar,
                  ),
                  _buildSettingsOption(
                    Icons.location_on,
                    'Location',
                    'Allow Vigil1 to access location',
                    (value) {
                      setState(() {
                        location = value;
                      });
                    },
                    location,
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _allowAll,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Allow All',
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

  Widget _buildSettingsOption(IconData icon, String title, String subtitle,
      Function(bool) onChanged, bool value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          Icon(icon, size: 30, color: Colors.teal),
          const SizedBox(width: 10),
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
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
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
