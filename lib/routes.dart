import 'package:flutter/material.dart';
import 'route_names.dart';
import 'pages/splash_view.dart';
import 'features/auth/view/login_page.dart';
import 'features/verify_otp/view/verify_otp_page.dart';
import 'features/pairing/view/pairing_page.dart';
import 'features/permissions/view/permissions_page.dart';
import 'features/permissions/view/permissions_settings_page.dart';
import 'features/home/view/child_home_page.dart';
import 'pages/terms_page.dart';
import 'pages/welcome_page.dart';
import 'pages/allowpermission_page.dart';
import 'services/finalmonitoring_page.dart';

class AppRoutes {
  AppRoutes._(); // Prevent instantiation

  static Map<String, WidgetBuilder> get routes => {
        // Main routes
        RouteNames.home: (context) => const SplashView(),
        RouteNames.login: (context) => const LoginPage(),
        RouteNames.terms: (context) => const TermsPage(),
        RouteNames.welcome: (context) => _buildWelcomePage(context),

        // Setup flow
        RouteNames.verifyOtp: (context) => const VerifyOtpPage(),
        RouteNames.pairing: (context) => const PairingPage(),
        RouteNames.allowPermission: (context) =>
            _buildAllowPermissionPage(context),
        RouteNames.permissions: (context) => const PermissionsPage(),
        RouteNames.permissionsSettings: (context) =>
            const PermissionsSettingsPage(),
        RouteNames.childHome: (context) => const ChildHomePage(),

        // Final step
        RouteNames.finalMonitoring: (context) =>
            _buildFinalMonitoringPage(context),
      };

  // Helper to get arguments
  static Map<String, dynamic>? _getArgs(BuildContext context) {
    return ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
  }

  // Error page
  static Widget _errorPage(String message) {
    return Scaffold(
      body: Center(child: Text(message)),
    );
  }

  static Widget _buildAllowPermissionPage(BuildContext context) {
    final args = _getArgs(context);
    if (args == null || args['childId'] == null || args['token'] == null) {
      return _errorPage('Missing childId or token');
    }
    return AllowPermissionsPage(
      childId: args['childId']!,
      token: args['token']!,
    );
  }

  static Widget _buildFinalMonitoringPage(BuildContext context) {
    final args = _getArgs(context);
    if (args == null || args['childId'] == null || args['token'] == null) {
      return _errorPage('Missing childId or token');
    }
    return StartMonitoring(
      childId: args['childId']!,
      token: args['token']!,
    );
  }

  static Widget _buildWelcomePage(BuildContext context) {
    final args = _getArgs(context);
    if (args == null || args['childId'] == null || args['token'] == null) {
      return _errorPage('Missing childId or token');
    }
    return const WelcomePage();
  }

}
