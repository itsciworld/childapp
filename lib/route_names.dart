/// Route name constants for the app
class RouteNames {
  RouteNames._(); // Prevent instantiation

  // Main routes
  static const String home = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String welcome = '/welcome';

  /// The child's landing screen shown after setup is complete.
  static const String childHome = '/childHome';

  // Setup flow
  static const String otp = '/otp';
  static const String verifyOtp = '/verifyOtp';
  static const String pairing = '/pairing';
  static const String childProfile = '/childProfile';
  static const String allowPermission = '/allowPermission';
  static const String permissions = '/permissions';
  static const String permissionsSettings = '/permissionsSettings';

  // Final step
  static const String finalMonitoring = '/finalMonitoring';
}
