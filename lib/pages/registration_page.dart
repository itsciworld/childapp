import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:vigil1/navigation_helper.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  RegistrationPageState createState() => RegistrationPageState();
}

class RegistrationPageState extends State<RegistrationPage> {
  bool _obscureText = true;
  bool _isLoading = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // // Default values for testing as requested
    // _nameController.text = "Test Parent";
    // _emailController.text = "vigil1964io@gmail.com";
    // _passwordController.text = "Vigil@1234";
  }

  Future<void> _register() async {
    final String name = _nameController.text.trim();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    debugPrint('[REGISTER] ───────────────────────────────────────');
    debugPrint('[REGISTER] Sign Up button tapped');
    debugPrint('[REGISTER] Name: "$name"');
    debugPrint('[REGISTER] Email: "$email"');
    debugPrint('[REGISTER] Password length: ${password.length}');

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      debugPrint('[REGISTER] STOP: name, email or password is empty');
      return;
    }

    setState(() => _isLoading = true);
    debugPrint('[REGISTER] Loading started');

    // TODO: Update this with the URL you provide
    final url =
        Uri.parse('https://vigil-backend-jays.onrender.com/api/auth/register');

    debugPrint('[REGISTER] POST → $url');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'name': name,
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 35));

      debugPrint('[REGISTER] ── Response received ──');
      debugPrint('[REGISTER] Status code : ${response.statusCode}');
      debugPrint('[REGISTER] Response body: ${response.body}');

      if (!mounted) {
        debugPrint('[REGISTER] Widget unmounted — aborting');
        return;
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseBody = json.decode(response.body);
        debugPrint('[REGISTER] Parsed keys: ${responseBody.keys.toList()}');

        debugPrint('[REGISTER] Navigating back to login / OTP');
        if (mounted) {
          setState(() => _isLoading = false);
          debugPrint('[REGISTER] Loading stopped');
          debugPrint('[REGISTER] ───────────────────────────────────────');
          // Return to the previous screen (e.g., Login) upon successful registration
          Nav.toWelcome(context);
        }
      } else {
        debugPrint('[REGISTER] ERROR: non-2xx status ${response.statusCode}');
        debugPrint('[REGISTER] Error body: ${response.body}');

        try {
          final Map<String, dynamic> err =
              json.decode(response.body) as Map<String, dynamic>;
          debugPrint(
              '[REGISTER] Parsed error msg: ${err['msg'] ?? err['message'] ?? 'no msg field'}');
        } catch (_) {
          debugPrint('[REGISTER] Could not parse error body as JSON');
        }
      }
    } on http.ClientException catch (e) {
      debugPrint('[REGISTER] ClientException: ${e.message}');
    } catch (error, stackTrace) {
      debugPrint('[REGISTER] Unexpected error: $error');
      debugPrint('[REGISTER] Stack trace:\n$stackTrace');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint('[REGISTER] Loading stopped');
        debugPrint('[REGISTER] ───────────────────────────────────────');
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 40),
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
                'Sign up to get started.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: _nameController,
                        keyboardType: TextInputType.name,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          hintText: 'John Doe',
                          border: OutlineInputBorder(),
                        ),
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
                              _obscureText
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() => _obscureText = !_obscureText);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
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
                            'Sign Up',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                  ),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: () {
                    Nav.back(context);
                  },
                  child: const Text(
                    'Already have an account? Sign in.',
                    style: TextStyle(color: Colors.black),
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
