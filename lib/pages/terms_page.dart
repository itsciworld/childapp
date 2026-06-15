import 'package:flutter/material.dart';
import 'package:vigil1/core/appColor/app_theme/app_gradient.dart';
import 'package:vigil1/core/widgets/custom_button.dart';
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
    final mq = MediaQuery.of(context);
    final screenH = mq.size.height;
    final screenW = mq.size.width;

    final hPad = screenW * 0.06;
    final topPad = screenH * 0.06;
    final vGapMd = screenH * 0.022;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: EdgeInsets.only(
          left: hPad,
          right: hPad,
          top: topPad + MediaQuery.of(context).padding.top,
          bottom: MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  SizedBox(height: vGapMd * 2),
                  const Text(
                    textAlign: TextAlign.center,
                    'Terms and Conditions',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                  SizedBox(height: vGapMd * 2.5),
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
                    style: TextStyle(fontSize: 16, height: 1.5),
                  ),
                  SizedBox(height: vGapMd),
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
                  SizedBox(height: vGapMd),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: vGapMd, bottom: vGapMd),
              child: CustomButton(
                isLoading: false,
                label: 'I Accept',
                onTap: _isAccepted
                    ? () {
                        Navigator.pushNamed(context, RouteNames.login);
                      }
                    : null,
                height: screenH * 0.055,
                gradient: _isAccepted
                    ? AppGradients.primaryButton
                    : const LinearGradient(
                        colors: [Colors.grey, Colors.grey],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
