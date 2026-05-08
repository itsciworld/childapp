import 'package:flutter/material.dart';
import 'package:vigil1/route_names.dart';

class TermsPage extends StatefulWidget {
  const TermsPage({super.key});

  @override
  _TermsPageState createState() => _TermsPageState();
}

class _TermsPageState extends State<TermsPage> {
  bool _isAccepted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(
                        bottom:
                            60), // Padding to create space from the bottom edge
                  ),
                  const Text(
                    textAlign: TextAlign.center,
                    'Terms and Conditions',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(
                        bottom:
                            60), // Padding to create space from the bottom edge
                  ),
                  const Text(
                    'Terms and Conditions for Vigil1 Kids App:\n'
                    '1. Introduction: Welcome to Vigil1 Kids App. These terms and conditions govern your use of the Vigil1 Kids application ("App") provided by Vigil1 ("Company"). By using the App, you agree to these terms. If you do not agree, please do not use the App.\n\n'
                    '2. User Accounts\n'
                    '\u{00A0}\u{00A0}• Eligibility: You must be at least 18 years old to create a parent account. By creating an account, you represent that you are of legal age and agree to these terms.\n'
                    '\u{00A0}\u{00A0}• Account Security: You are responsible for maintaining the confidentiality of your account information, including your password. You agree to notify us immediately of any unauthorized use of your account.\n\n'
                    '3. Services Provided: Vigil1 Kids App provides features that allow parents to monitor and manage their children\'s mobile device usage. These features include but are not limited to:\n'
                    '\u{00A0}\u{00A0}• Usage tracking.\n'
                    '\u{00A0}\u{00A0}• Activity reports.\n'
                    '\u{00A0}\u{00A0}• Screen time limits.\n'
                    '\u{00A0}\u{00A0}• Content filtering.\n'
                    '\u{00A0}\u{00A0}• Notifications and alerts.\n'
                    '\u{00A0}\u{00A0}• Remote control of the device.\n\n'
                    '4. Privacy and Data Collection\n'
                    '\u{00A0}\u{00A0}• Data Collection: We collect and use data as described in our Privacy Policy. This includes information you provide during account creation, as well as data collected from devices linked to your account.\n\n',
                    style: TextStyle(fontSize: 16),
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: _isAccepted,
                        onChanged: (bool? value) {
                          setState(() {
                            _isAccepted = value ?? false;
                          });
                        },
                      ),
                      const Expanded(
                        child: Text(
                          'I accept the terms of use of this application',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: TextButton(
                onPressed: _isAccepted
                    ? () {
                        Navigator.pushNamed(context, RouteNames.login);
                      }
                    : null,
                style: TextButton.styleFrom(
                  backgroundColor: _isAccepted ? Colors.black : Colors.grey,
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text(
                  'I Accept',
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
    );
  }
}
