import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Typed access to values loaded from the `.env` file.
///
/// Every getter has a sensible fallback so the app keeps working even if the
/// `.env` file is missing or a key is not set.
class EnvConfig {
  EnvConfig._();

  /// Loads the `.env` file. Call once at app startup before [runApp].
  static Future<void> load() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // No .env bundled — fall back to the defaults below.
    }
  }

  static String get apiBaseUrl =>
      dotenv.maybeGet('API_BASE_URL') ?? 'http://160-153-179-249.sslip.io';

  static int get connectTimeoutMs =>
      int.tryParse(dotenv.maybeGet('CONNECT_TIMEOUT') ?? '') ?? 35000;

  // The backends run on Render's free tier, which spins instances down after
  // ~15 min idle and can take up to a minute to cold-start. A short receive
  // timeout aborts that first (waking) request — so allow 60s for the server
  // to respond before giving up.
  static int get receiveTimeoutMs =>
      int.tryParse(dotenv.maybeGet('RECEIVE_TIMEOUT') ?? '') ?? 60000;
}
