import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ActivateAdministratorAccess extends StatefulWidget {
  final String childId;
  final String token;

  const ActivateAdministratorAccess(
      {super.key, required this.childId, required this.token});

  @override
  _ActivateAdministratorAccessState createState() =>
      _ActivateAdministratorAccessState();
}

class _ActivateAdministratorAccessState
    extends State<ActivateAdministratorAccess> {
  bool administratorAccess = false;

  @override
  void initState() {
    super.initState();
    _fetchAdministratorAccessStatus();
  }

  Future<void> _fetchAdministratorAccessStatus() async {
    final url = Uri.parse(
        'https://vigil-admin-backend.onrender.com/api/children/${widget.childId}/administrator-access-status');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        setState(() {
          administratorAccess = responseBody['administratorAccess'];
        });
      } else {
        print('Error fetching administrator access status');
      }
    } catch (error) {
      print('Error during HTTP request: $error');
    }
  }

  Future<void> _updateAdministratorAccessStatus(bool status) async {
    final url = Uri.parse(
        'https://vigil-admin-backend.onrender.com/api/children/${widget.childId}/administrator-access-status');

    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode({
          'administratorAccess': status,
        }),
      );

      if (response.statusCode != 200) {
        print('Error updating administrator access status');
      } else {
        setState(() {
          administratorAccess = status;
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
                    'Allow Permission',
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
                'Activate Administrator Access',
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
                'Activate "Administrator Access" for Vigil 1 to enable real-time phone monitoring.',
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
                  const ListTile(
                    leading: Icon(Icons.security),
                    title: Text(
                      'Device Administrator',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(),
                  const ListTile(
                    leading: Icon(Icons.system_update),
                    title: Text(
                      'System Update Service',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Activating this admin app will allow System Update Service to perform the following actions:',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const ListTile(
                    leading: Icon(Icons.delete_forever),
                    title: Text(
                      'Erase all data',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Erase the phone\'s data without warning by performing a factory data reset.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const ListTile(
                    leading: Icon(Icons.lock),
                    title: Text(
                      'Change the screen lock',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Change the screen lock.',
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: administratorAccess
                              ? null
                              : () {
                                  _updateAdministratorAccessStatus(true);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: administratorAccess
                                ? Colors.grey[200]
                                : Colors.teal,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'ACTIVATE',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: !administratorAccess
                              ? null
                              : () {
                                  _updateAdministratorAccessStatus(false);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: !administratorAccess
                                ? Colors.grey[200]
                                : Colors.teal,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'CANCEL',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
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
                      onPressed: () {
                        Navigator.pushNamed(context, '/activatedataaccess',
                            arguments: {
                              'childId': widget.childId,
                              'token': widget.token,
                            });
                      },
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
}
