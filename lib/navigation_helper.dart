import 'package:flutter/material.dart';
import 'route_names.dart';

/// Simple navigation helper for the app
class Nav {
  Nav._(); // Prevent instantiation

  /// Navigate to home
  static void toHome(BuildContext context) {
    Navigator.pushReplacementNamed(context, RouteNames.home);
  }

  /// Navigate to login
  static void toLogin(BuildContext context) {
    Navigator.pushNamed(context, RouteNames.login);
  }

  /// Navigate to register
  static void toRegister(BuildContext context) {
    Navigator.pushNamed(context, RouteNames.register);
  }

  /// Navigate to terms
  static void toTerms(BuildContext context) {
    Navigator.pushNamed(context, RouteNames.terms);
  }

  /// Navigate to OTP page.
  ///
  /// [token] is optional — the login-and-send-otp step does not return one;
  /// a token is only issued later, after OTP verification.
  static void toOtp(BuildContext context, String email,
      [String token = '']) {
    Navigator.pushNamed(
      context,
      RouteNames.otp,
      arguments: {'email': email, 'token': token},
    );
  }

  /// Navigate to the verify-OTP screen.
  ///
  /// The parent enters the emailed OTP plus the child's name and age here;
  /// [email] is carried over from the login screen.
  static void toVerifyOtp(BuildContext context, String email) {
    Navigator.pushNamed(
      context,
      RouteNames.verifyOtp,
      arguments: {'email': email},
    );
  }

  /// Navigate to the pairing screen.
  ///
  /// Alternative to the verify-OTP flow — the parent enters a pairing code
  /// generated on their Vigil app. [email] is carried over from login.
  static void toPairing(BuildContext context, String email) {
    Navigator.pushNamed(
      context,
      RouteNames.pairing,
      arguments: {'email': email},
    );
  }

  /// Navigate to child profile
  static void toChildProfile(
      BuildContext context, String email, String token, String otp) {
    Navigator.pushNamed(
      context,
      RouteNames.childProfile,
      arguments: {'email': email, 'token': token, 'otp': otp},
    );
  }

  /// Navigate to allow permission
  static void toAllowPermission(
      BuildContext context, String childId, String token) {
    Navigator.pushNamed(
      context,
      RouteNames.allowPermission,
      arguments: {'childId': childId, 'token': token},
    );
  }

  /// Enter the child's home screen, clearing the whole setup stack so the
  /// hardware back button hits the home screen's press-twice-to-exit guard
  /// instead of walking back through the onboarding flow.
  static void toChildHome(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      RouteNames.childHome,
      (route) => false,
    );
  }

  /// Navigate to the combined permissions screen.
  ///
  /// Single page with one toggle per OS permission — replaces the old
  /// per-service screens (disable Play Protect, accessibility, battery, ...).
  static void toPermissions(BuildContext context) {
    Navigator.pushNamed(context, RouteNames.permissions);
  }

  /// Navigate to final monitoring
  static void toFinalMonitoring(
      BuildContext context, String childId, String token) {
    Navigator.pushNamed(
      context,
      RouteNames.finalMonitoring,
      arguments: {'childId': childId, 'token': token},
    );
  }

  /// Navigate to welcome
  // static void toWelcome(BuildContext context, String childId, String token) {
  //   Navigator.pushNamed(
  //     context,
  //     RouteNames.welcome,
  //     arguments: {'childId': childId, 'token': token},
  //   );
  // }
  static void toWelcome(
    BuildContext context,
  ) {
    Navigator.pushNamed(
      context,
      RouteNames.welcome,
      // arguments: {'childId': childId, 'token': token},
    );
  }

  /// Go back
  static void back(BuildContext context) {
    Navigator.pop(context);
  }

  /// Go back to home
  static void backToHome(BuildContext context) {
    Navigator.popUntil(context, ModalRoute.withName(RouteNames.home));
  }
}
