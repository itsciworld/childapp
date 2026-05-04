import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class BatteryOptimization extends StatefulWidget {
  final String childId;
  final String token;

  const BatteryOptimization(
      {super.key, required this.childId, required this.token});

  @override
  _BatteryOptimizationState createState() => _BatteryOptimizationState();
}

class _BatteryOptimizationState extends State<BatteryOptimization> {
  bool batteryOptimizationAllowed = false;

  Future<void> _updateBatteryOptimizationStatus() async {
    final url = Uri.parse(
        'https://vigil-admin-backend.onrender.com/api/children/${widget.childId}/battery-optimization-status');

    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode({
          'batteryOptimizationAllowed': batteryOptimizationAllowed,
        }),
      );

      if (response.statusCode != 200) {
        // Handle error
        print('Error updating battery optimization status');
      } else {
        // Navigate to the next screen if needed
        Navigator.pushNamed(context, '/finalmonitoring', arguments: {
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
                'Turn Off Battery Optimization',
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
                'Turn off battery optimization to ensure that app runs normally in the background',
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
                  const ListTile(
                    leading: Icon(Icons.battery_0_bar),
                    title: Text(
                      'Battery Optimization',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const ListTile(
                    leading: Icon(Icons.system_update),
                    subtitle: Text(
                      'System Update Service will be able to run in the background without battery usage restrictions',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: batteryOptimizationAllowed
                              ? null
                              : () {
                                  setState(() {
                                    batteryOptimizationAllowed = true;
                                  });
                                  _updateBatteryOptimizationStatus();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: batteryOptimizationAllowed
                                ? Colors.grey[200]
                                : Colors.teal,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'ALLOW',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: batteryOptimizationAllowed
                              ? () {
                                  setState(() {
                                    batteryOptimizationAllowed = false;
                                  });
                                  _updateBatteryOptimizationStatus();
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: batteryOptimizationAllowed
                                ? Colors.teal
                                : Colors.grey[200],
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'DENY',
                            style: TextStyle(color: Colors.black),
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
                      onPressed: _updateBatteryOptimizationStatus,
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
