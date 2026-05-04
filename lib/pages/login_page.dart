import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:vigil1/route_names.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  bool _obscureText = true;
  bool _isLoading = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _loginAndSendOTP() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    debugPrint('[LOGIN] ───────────────────────────────────────');
    debugPrint('[LOGIN] Sign In button tapped');
    debugPrint('[LOGIN] Email: "$email"');
    debugPrint('[LOGIN] Password length: ${password.length}');

    if (email.isEmpty || password.isEmpty) {
      debugPrint('[LOGIN] STOP: email or password is empty');
      return;
    }

    setState(() => _isLoading = true);
    debugPrint('[LOGIN] Loading started');

    final url =
        Uri.parse('https://vigil-admin-backend.onrender.com/api/auth/login');

    debugPrint('[LOGIN] POST → $url');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('[LOGIN] ── Response received ──');
      debugPrint('[LOGIN] Status code : ${response.statusCode}');
      debugPrint('[LOGIN] Response body: ${response.body}');

      if (!mounted) {
        debugPrint('[LOGIN] Widget unmounted — aborting');
        return;
      }

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        debugPrint('[LOGIN] Parsed keys: ${responseBody.keys.toList()}');

        final String? token = responseBody['token'] as String?;

        if (token == null || token.isEmpty) {
          debugPrint('[LOGIN] ERROR: token missing in 200 response');
          debugPrint('[LOGIN] Full body: ${response.body}');
          return;
        }

        debugPrint(
            '[LOGIN] Token OK (first 20): ${token.substring(0, token.length.clamp(0, 20))}...');
        debugPrint('[LOGIN] Navigating to /otp');

        Navigator.pushNamed(
          context,
          RouteNames.otp,
          arguments: {'email': email, 'token': token},
        );
      } else {
        debugPrint('[LOGIN] ERROR: non-200 status ${response.statusCode}');
        debugPrint('[LOGIN] Error body: ${response.body}');

        try {
          final Map<String, dynamic> err =
              json.decode(response.body) as Map<String, dynamic>;
          debugPrint(
              '[LOGIN] Parsed error msg: ${err['msg'] ?? err['message'] ?? 'no msg field'}');
        } catch (_) {
          debugPrint('[LOGIN] Could not parse error body as JSON');
        }
      }
    } on http.ClientException catch (e) {
      debugPrint('[LOGIN] ClientException: ${e.message}');
    } catch (error, stackTrace) {
      debugPrint('[LOGIN] Unexpected error: $error');
      debugPrint('[LOGIN] Stack trace:\n$stackTrace');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint('[LOGIN] Loading stopped');
        debugPrint('[LOGIN] ───────────────────────────────────────');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 60),
            const Text(
              'Protect Your Child With',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Vigil 1',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.lightBlue,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Sign in to get started.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'jhondoe@gmail.com',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              obscureText: _obscureText,
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() => _obscureText = !_obscureText);
                  },
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _loginAndSendOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    disabledBackgroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Sign In',
                          style: TextStyle(color: Colors.white, fontSize: 18),
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
