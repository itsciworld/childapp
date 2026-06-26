import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// A guide page that helps users disable manufacturer-specific battery
/// optimizations that can kill the background service.
///
/// Different Android manufacturers (Xiaomi, Huawei, OnePlus, Samsung, etc.)
/// add their own aggressive battery optimization on top of standard Android,
/// which can kill background services even when all standard permissions are
/// granted. This page provides step-by-step instructions specific to the
/// user's device manufacturer.
class BatteryOptimizationGuidePage extends StatefulWidget {
  const BatteryOptimizationGuidePage({super.key});

  @override
  State<BatteryOptimizationGuidePage> createState() =>
      _BatteryOptimizationGuidePageState();
}

class _BatteryOptimizationGuidePageState
    extends State<BatteryOptimizationGuidePage> {
  String _manufacturer = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _detectManufacturer();
  }

  Future<void> _detectManufacturer() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      setState(() {
        _manufacturer = androidInfo.manufacturer.toLowerCase();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _manufacturer = 'unknown';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Background Service Setup'),
        backgroundColor: Colors.deepPurple,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildManufacturerSpecificGuide(),
                  const SizedBox(height: 24),
                  _buildGeneralTips(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.orange.shade700, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Important Setup Required',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'To ensure continuous monitoring, please follow these steps to prevent your device from killing the background service.',
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildManufacturerSpecificGuide() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings for $_manufacturer devices'.toUpperCase(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 16),
          _getManufacturerGuide(),
        ],
      ),
    );
  }

  Widget _getManufacturerGuide() {
    if (_manufacturer.contains('xiaomi') ||
        _manufacturer.contains('redmi') ||
        _manufacturer.contains('poco')) {
      return _buildXiaomiGuide();
    } else if (_manufacturer.contains('huawei') ||
        _manufacturer.contains('honor')) {
      return _buildHuaweiGuide();
    } else if (_manufacturer.contains('oneplus') ||
        _manufacturer.contains('oppo') ||
        _manufacturer.contains('realme')) {
      return _buildOnePlusGuide();
    } else if (_manufacturer.contains('samsung')) {
      return _buildSamsungGuide();
    } else if (_manufacturer.contains('vivo')) {
      return _buildVivoGuide();
    } else {
      return _buildGenericGuide();
    }
  }

  Widget _buildXiaomiGuide() {
    return _buildStepsList([
      'Open Settings → Apps → Manage Apps',
      'Find and tap "Vigil-Child"',
      'Tap "Battery Saver" → Select "No restrictions"',
      'Go back and tap "Autostart" → Enable it',
      'Open Recent Apps (square button)',
      'Find Vigil-Child and pull down to lock it',
      'You should see a lock icon on the app card',
    ]);
  }

  Widget _buildHuaweiGuide() {
    return _buildStepsList([
      'Open Settings → Battery → App Launch',
      'Find "Vigil-Child" → Tap to manage manually',
      'Enable ALL three toggles:',
      '  • Auto-launch',
      '  • Secondary launch',
      '  • Run in background',
      'Go to Settings → Apps → Apps',
      'Find "Vigil-Child" → Battery',
      'Select "Manual manage" and enable all toggles',
    ]);
  }

  Widget _buildOnePlusGuide() {
    return _buildStepsList([
      'Open Settings → Battery → Battery Optimization',
      'Tap "Apps not optimized" → Select "All apps"',
      'Find "Vigil-Child" → Select "Don\'t optimize"',
      'Go to Settings → Apps → Vigil-Child',
      'Tap "Battery" → Enable "Background activity"',
      'Open Recent Apps',
      'Tap the three dots on Vigil-Child card',
      'Select "Lock" to prevent it from closing',
    ]);
  }

  Widget _buildSamsungGuide() {
    return _buildStepsList([
      'Open Settings → Apps → Vigil-Child',
      'Tap "Battery" → Turn OFF "Optimize battery usage"',
      'Go back to Settings → Battery',
      'Tap "Background usage limits"',
      'Tap "Never sleeping apps"',
      'Tap "+" and add "Vigil-Child"',
      'Open Settings → Device Care → Battery',
      'Tap "App power management"',
      'Ensure "Vigil-Child" is NOT in "Sleeping apps"',
    ]);
  }

  Widget _buildVivoGuide() {
    return _buildStepsList([
      'Open Settings → Battery → Background power consumption',
      'Find "Vigil-Child" → Enable "High background power consumption"',
      'Go to Settings → Apps & notifications',
      'Find "Vigil-Child" → Battery',
      'Enable "Allow background activity"',
      'Open Recent Apps',
      'Pull down on Vigil-Child to lock it',
    ]);
  }

  Widget _buildGenericGuide() {
    return _buildStepsList([
      'Open Settings → Apps → Vigil-Child',
      'Look for "Battery" or "Battery optimization"',
      'Disable battery optimization for this app',
      'Enable "Background activity" if available',
      'Look for "Autostart" or "Run in background"',
      'Enable these options if available',
      'Lock the app in Recent Apps if your device supports it',
    ]);
  }

  Widget _buildStepsList(List<String> steps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  step,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGeneralTips() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tips_and_updates, color: Colors.green.shade700),
              const SizedBox(width: 8),
              const Text(
                'General Tips',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '• Keep the app running (don\'t force close it)\n'
            '• Avoid using task killer or battery saver apps\n'
            '• Keep your device charged or on power saving whitelist\n'
            '• Check that you granted all permissions when first opening the app\n'
            '• Restart the device after changing these settings',
            style: TextStyle(fontSize: 14, height: 1.6),
          ),
        ],
      ),
    );
  }
}
