import 'package:flutter/material.dart';
import 'package:vigil1/pages/registration_page.dart';
import 'route_names.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/terms_page.dart';
import 'pages/welcome_page.dart';
import 'pages/linkparent_page.dart';
import 'pages/addchildprofile_page.dart';
import 'pages/allowpermission_page.dart';
import 'services/disableplayprotect_page.dart';
import 'services/activateaccessibility_page.dart';
import 'services/activateappsupervision_page.dart';
import 'services/activatenotificationaccess_page.dart';
import 'services/activateadministratoraccess_page.dart';
import 'services/activatedataaccess_page.dart';
import 'services/batteryoptimization_page.dart';
import 'services/finalmonitoring_page.dart';

class AppRoutes {
  AppRoutes._(); // Prevent instantiation

  static Map<String, WidgetBuilder> get routes => {
        // Main routes
        RouteNames.home: (context) => const HomePage(),
        RouteNames.register: (context) => const RegistrationPage(),
        RouteNames.login: (context) => const LoginPage(),
        RouteNames.terms: (context) => const TermsPage(),
        RouteNames.welcome: (context) => _buildWelcomePage(context),

        // Setup flow
        RouteNames.otp: (context) => _buildOtpPage(context),
        RouteNames.childProfile: (context) => _buildChildProfilePage(context),
        RouteNames.allowPermission: (context) =>
            _buildAllowPermissionPage(context),

        // Service activation
        RouteNames.disablePlayProtect: (context) =>
            _buildDisablePlayProtectPage(context),
        RouteNames.activateAccessibility: (context) =>
            _buildActivateAccessibilityPage(context),
        RouteNames.activateSupervision: (context) =>
            _buildActivateSupervisionPage(context),
        RouteNames.activateNotificationAccess: (context) =>
            _buildActivateNotificationAccessPage(context),
        RouteNames.activateAdministratorAccess: (context) =>
            _buildActivateAdministratorAccessPage(context),
        RouteNames.activateDataAccess: (context) =>
            _buildActivateDataAccessPage(context),
        RouteNames.batteryOptimization: (context) =>
            _buildBatteryOptimizationPage(context),
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

  // Route builders
  static Widget _buildOtpPage(BuildContext context) {
    final args = _getArgs(context);
    if (args == null || args['email'] == null || args['token'] == null) {
      return _errorPage('Missing email or token');
    }
    return LinkParentDevicePage(
      email: args['email']!,
      token: args['token']!,
    );
  }

  static Widget _buildChildProfilePage(BuildContext context) {
    final args = _getArgs(context);
    if (args == null ||
        args['email'] == null ||
        args['token'] == null ||
        args['otp'] == null) {
      return _errorPage('Missing required arguments');
    }
    return AddChildProfilePage(
      email: args['email']!,
      token: args['token']!,
      otp: args['otp']!,
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

  static Widget _buildDisablePlayProtectPage(BuildContext context) {
    final args = _getArgs(context);
    if (args == null || args['childId'] == null || args['token'] == null) {
      return _errorPage('Missing childId or token');
    }
    return DisablePlayProtectPage(
      childId: args['childId']!,
      token: args['token']!,
    );
  }

  static Widget _buildActivateAccessibilityPage(BuildContext context) {
    final args = _getArgs(context);
    if (args == null || args['childId'] == null || args['token'] == null) {
      return _errorPage('Missing childId or token');
    }
    return ActivateAccessibilityPage(
      childId: args['childId']!,
      token: args['token']!,
    );
  }

  static Widget _buildActivateSupervisionPage(BuildContext context) {
    final args = _getArgs(context);
    if (args == null || args['childId'] == null || args['token'] == null) {
      return _errorPage('Missing childId or token');
    }
    return ActivateAppSuperVisionPage(
      childId: args['childId']!,
      token: args['token']!,
    );
  }

  static Widget _buildActivateNotificationAccessPage(BuildContext context) {
    final args = _getArgs(context);
    if (args == null || args['childId'] == null || args['token'] == null) {
      return _errorPage('Missing childId or token');
    }
    return ActivateNotificationAccessPage(
      childId: args['childId']!,
      token: args['token']!,
    );
  }

  static Widget _buildActivateAdministratorAccessPage(BuildContext context) {
    final args = _getArgs(context);
    if (args == null || args['childId'] == null || args['token'] == null) {
      return _errorPage('Missing childId or token');
    }
    return ActivateAdministratorAccess(
      childId: args['childId']!,
      token: args['token']!,
    );
  }

  static Widget _buildActivateDataAccessPage(BuildContext context) {
    final args = _getArgs(context);
    if (args == null || args['childId'] == null || args['token'] == null) {
      return _errorPage('Missing childId or token');
    }
    return ActivateDataAccess(
      childId: args['childId']!,
      token: args['token']!,
    );
  }

  static Widget _buildBatteryOptimizationPage(BuildContext context) {
    final args = _getArgs(context);
    if (args == null || args['childId'] == null || args['token'] == null) {
      return _errorPage('Missing childId or token');
    }
    return BatteryOptimization(
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
    return WelcomePage(
        // childId: args['childId']!,
        // token: args['token']!,
        );
  }
}
