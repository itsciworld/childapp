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

  /// Navigate to OTP page
  static void toOtp(BuildContext context, String email, String token) {
    Navigator.pushNamed(
      context,
      RouteNames.otp,
      arguments: {'email': email, 'token': token},
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

  /// Navigate to disable play protect
  static void toDisablePlayProtect(
      BuildContext context, String childId, String token) {
    Navigator.pushNamed(
      context,
      RouteNames.disablePlayProtect,
      arguments: {'childId': childId, 'token': token},
    );
  }

  /// Navigate to activate accessibility
  static void toActivateAccessibility(
      BuildContext context, String childId, String token) {
    Navigator.pushNamed(
      context,
      RouteNames.activateAccessibility,
      arguments: {'childId': childId, 'token': token},
    );
  }

  /// Navigate to activate supervision
  static void toActivateSupervision(
      BuildContext context, String childId, String token) {
    Navigator.pushNamed(
      context,
      RouteNames.activateSupervision,
      arguments: {'childId': childId, 'token': token},
    );
  }

  /// Navigate to activate notification access
  static void toActivateNotificationAccess(
      BuildContext context, String childId, String token) {
    Navigator.pushNamed(
      context,
      RouteNames.activateNotificationAccess,
      arguments: {'childId': childId, 'token': token},
    );
  }

  /// Navigate to activate administrator access
  static void toActivateAdministratorAccess(
      BuildContext context, String childId, String token) {
    Navigator.pushNamed(
      context,
      RouteNames.activateAdministratorAccess,
      arguments: {'childId': childId, 'token': token},
    );
  }

  /// Navigate to activate data access
  static void toActivateDataAccess(
      BuildContext context, String childId, String token) {
    Navigator.pushNamed(
      context,
      RouteNames.activateDataAccess,
      arguments: {'childId': childId, 'token': token},
    );
  }

  /// Navigate to battery optimization
  static void toBatteryOptimization(
      BuildContext context, String childId, String token) {
    Navigator.pushNamed(
      context,
      RouteNames.batteryOptimization,
      arguments: {'childId': childId, 'token': token},
    );
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
