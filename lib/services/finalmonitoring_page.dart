import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class StartMonitoring extends StatefulWidget {
  final String childId;
  final String token;

  const StartMonitoring(
      {super.key, required this.childId, required this.token});

  @override
  _StartMonitoringState createState() => _StartMonitoringState();
}

class _StartMonitoringState extends State<StartMonitoring> {
  String deviceName = 'Loading...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getDeviceName();
    });
  }

  Future<void> _getDeviceName() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    String? deviceName;

    try {
      final isAndroid = Theme.of(context).platform == TargetPlatform.android;
      final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

      if (isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        deviceName = _getAndroidDeviceName(androidInfo);
      } else if (isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        deviceName = iosInfo.name;
      } else {
        deviceName = 'Unknown Device';
      }
    } catch (e) {
      deviceName = 'Failed to get device name: $e';
    }

    setState(() {
      this.deviceName = deviceName!;
    });
  }

  String _getAndroidDeviceName(AndroidDeviceInfo androidInfo) {
    if (androidInfo.isPhysicalDevice == false) {
      // Handle emulator names
      switch (androidInfo.model) {
        case 'sdk_gphone64_arm64':
          return 'Pixel 7 Pro (Emulator)';
        // Add other cases if needed
        default:
          return 'Android Emulator';
      }
    } else {
      return androidInfo.model;
    }
  }

  Future<void> _sendDeviceName() async {
    final url = Uri.parse(
        'https://vigil-admin-backend.onrender.com/api/children/${widget.childId}/update-device-name');
    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      },
      body: json.encode({'deviceName': deviceName}),
    );

    if (response.statusCode == 200) {
      // Successfully updated device name, navigate to the next screen
      Navigator.pushNamed(context, '/welcomepage', arguments: {
        'childId': widget.childId,
        'token': widget.token,
      });
    } else {
      // Handle error
      print('Failed to update device name: ${response.body}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/logo.png', // replace with your actual logo asset path
                width: 150,
                height: 160,
              ),
              const SizedBox(height: 20),
              const Text(
                'Vigil1 Kids\nApp',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF2BA0CC), Color(0xFF15BEB5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: const Text(
                  'Setup Complete!',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors
                        .white, // This color will be masked by the gradient
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BulletListItem(
                      text:
                          'Tap "Start Monitoring" below. The app icon on this device will disappear shortly. Avoid using the phone during this process.',
                    ),
                    BulletListItem(
                      text:
                          'Vigil1 will operate in stealth mode and begin uploading data to your parental account.',
                    ),
                    BulletListItem(
                      text:
                          'Now, access the Vigil1 dashboard or parental app to monitor your child’s cell phone.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 40.0),
                child: ElevatedButton(
                  onPressed: _sendDeviceName,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: Colors.black, // Updated parameter
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  child: const Text(
                    'Start Monitoring',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BulletListItem extends StatelessWidget {
  final String text;

  const BulletListItem({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '•',
            style: TextStyle(fontSize: 20, height: 1.55),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16, height: 1.55),
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  runApp(const MaterialApp(
    home: StartMonitoring(childId: 'childId', token: 'token'),
  ));
}
