import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class WelcomePage extends StatefulWidget {
  final String? childId;
  final String? token;

  const WelcomePage({super.key, this.childId, this.token});

  @override
  _WelcomePageState createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  late String name = '';
  late String email = '';
  late int age = 0;
  bool isLoading = true;
  String? childId;
  String? token;

  @override
  void initState() {
    super.initState();
    _loadLoginState();
  }

  Future<void> _loadLoginState() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    childId = prefs.getString('childId') ?? widget.childId;
    token = prefs.getString('token') ?? widget.token;

    if (childId != null && token != null) {
      _fetchChildDetails();
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fetchChildDetails() async {
    final url = Uri.parse(
        'https://vigil-admin-backend.onrender.com/api/children/$childId');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print(data);
        setState(() {
          name = data['name'];
          age = data['age'];
          isLoading = false;
        });

        // Save the login state
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('childId', childId!);
        await prefs.setString('token', token!);
      } else {
        // Handle error
        print('Error fetching child details');
        setState(() {
          isLoading = false;
        });
      }
    } catch (error) {
      print('Error during HTTP request: $error');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('childId');
    await prefs.remove('token');
    setState(() {
      childId = null;
      token = null;
      name = '';
      age = 0;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : childId == null || token == null
                ? const Center(child: Text('Please log in'))
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/logo.png', // replace with your actual logo asset path
                          width: 150,
                          height: 160,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Welcome, $name',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Age: $age',
                          style: const TextStyle(
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 40),
                        const Text(
                          'Vigil1 Kids App',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _logout,
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
