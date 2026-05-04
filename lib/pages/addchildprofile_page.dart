import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddChildProfilePage extends StatefulWidget {
  final String email;
  final String token;
  final String otp;

  const AddChildProfilePage(
      {super.key, required this.email, required this.token, required this.otp});

  @override
  _AddChildProfilePageState createState() => _AddChildProfilePageState();
}

class _AddChildProfilePageState extends State<AddChildProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();

  Future<void> _submitChildProfile() async {
    final String name = _nameController.text;
    final int age = int.tryParse(_ageController.text) ?? 0;

    // final url = Uri.parse('https://vigil-admin-backend.onrender.com/api/children/verify-otp-and-pair-device');
    final url = Uri.parse(
        'https://vigil-admin-backend.onrender.com/api/children/verify-otp-and-pair-device');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode({
          'email': widget.email,
          'code': widget.otp,
          'name': name,
          'age': age,
        }),
      );

      if (response.statusCode == 200) {
        // Parse the response body to extract childId
        final responseBody = json.decode(response.body);
        final String childId = responseBody['child']['_id'];

        // Navigate to AllowPermissionsPage with childId and token
        Navigator.pushNamed(
          context,
          '/allowpermission',
          arguments: {'childId': childId, 'token': widget.token},
        );
      } else {
        // Handle error
        final responseBody = json.decode(response.body);
        _showErrorDialog(responseBody['msg'] ?? 'Unknown error');
      }
    } catch (error) {
      print('Error during HTTP request: $error');
      _showErrorDialog('An error occurred. Please try again.');
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 60), // Add some space at the top
            const Text(
              'Add Child Profile',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Child’s Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _ageController,
              decoration: const InputDecoration(
                labelText: 'Child’s Age',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const Spacer(), // This will push the button to the bottom
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: SizedBox(
                width: double.infinity, // Make the button full-width
                child: ElevatedButton(
                  onPressed: _submitChildProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Submit',
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
}
