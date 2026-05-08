import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:vigil1/navigation_helper.dart';

class LinkParentDevicePage extends StatefulWidget {
  final String email;
  final String token;

  const LinkParentDevicePage(
      {super.key, required this.email, required this.token});

  @override
  _LinkParentDevicePageState createState() => _LinkParentDevicePageState();
}

class _LinkParentDevicePageState extends State<LinkParentDevicePage> {
  final List<TextEditingController> _controllers =
      List.generate(6, (index) => TextEditingController());
  final int _codeLength = 6;

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _verifyPairingCode() async {
    String otp = _controllers.map((controller) => controller.text).join();

    final url = Uri.parse(
        'https://vigil-admin-backend.onrender.com/api/children/verify-pairing-code');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      },
      body: json.encode({
        'code': otp,
        'email': widget.email, // Send email instead of parentId
      }),
    );

    if (response.statusCode == 200) {
      Navigator.pushNamed(context, '/childprofile', arguments: {
        'email': widget.email,
        'token': widget.token,
        'otp': otp,
      });
    } else {
      final responseBody = json.decode(response.body);
      _showErrorDialog(responseBody['msg'] ?? 'Invalid OTP');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.arrow_back_ios)),
            const Text(
              'Link Parents Device',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            const Text(
              'Enter Code',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'A unique 6-digit code is displayed on your Vigil1 Parental App. \n Enter the code to pair the two devices.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 40),
            _buildCodeInput(),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  // onPressed: _isCodeComplete() ? _verifyPairingCode : null,
                  onPressed: () {
                    Nav.toWelcome(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeInput() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(_codeLength, (index) {
        return _buildCodeDigitField(index);
      }),
    );
  }

  Widget _buildCodeDigitField(int index) {
    return SizedBox(
      width: 40,
      child: TextField(
        controller: _controllers[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(fontSize: 24),
        decoration: const InputDecoration(
          counterText: '',
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.grey),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.blue),
          ),
        ),
        onChanged: (value) {
          if (value.length == 1 && index < _codeLength - 1) {
            FocusScope.of(context).nextFocus();
          }
          if (value.isEmpty && index > 0) {
            FocusScope.of(context).previousFocus();
          }
          setState(() {});
        },
      ),
    );
  }

  bool _isCodeComplete() {
    for (var controller in _controllers) {
      if (controller.text.isEmpty) return false;
    }
    return true;
  }
}
