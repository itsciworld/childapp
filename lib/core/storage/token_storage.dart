import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the authentication tokens across app launches.
///
/// Two tokens are stored: the short-lived **access token** sent as
/// `Authorization: Bearer` on every authenticated call, and the long-lived
/// **refresh token** used at cold start to mint a new access token
/// (`POST /api/auth/refresh-token`) so a returning child never has to redo the
/// OTP flow.
class TokenStorage {
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _signedOutKey = 'session_signed_out';

  /// Writes whichever tokens the caller has. A null / empty value leaves the
  /// stored one untouched — so a refresh response that rotates only the access
  /// token does not wipe the refresh token.
  Future<void> saveTokens({String? accessToken, String? refreshToken}) async {
    final prefs = await SharedPreferences.getInstance();
    if (accessToken != null && accessToken.isNotEmpty) {
      await prefs.setString(_tokenKey, accessToken);
    }
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await prefs.setString(_refreshTokenKey, refreshToken);
    }
  }

  Future<void> saveToken(String token) => saveTokens(accessToken: token);

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    // The background isolate caches prefs from app boot; reload so it picks up
    // a token rotated by the main isolate (e.g. after a silent refresh).
    await prefs.reload();
    return prefs.getString(_tokenKey);
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getString(_refreshTokenKey);
  }

  /// True when a refresh token is stored — i.e. the launch flow can restore the
  /// session silently instead of sending the child through the OTP screens.
  Future<bool> hasRefreshToken() async {
    final token = await getRefreshToken();
    return token != null && token.isNotEmpty;
  }

  /// Drops only the access token, keeping the refresh token.
  ///
  /// This is what a normal logout does: the child is signed out of the app but
  /// the device stays paired, so signing back in restores the session silently
  /// instead of emailing another OTP.
  Future<void> clearAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  /// Marks the session as *deliberately* signed out.
  ///
  /// The refresh token survives a logout, so without this flag the next cold
  /// start would silently restore the session and walk straight past the login
  /// screen — undoing the logout. While it is set the splash always shows
  /// login; signing in again clears it.
  Future<void> setSignedOut(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_signedOutKey, value);
  }

  Future<bool> isSignedOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getBool(_signedOutKey) ?? false;
  }

  /// Wipes both tokens and the signed-out flag. Called when the device is
  /// unpaired and when the backend rejects the refresh token, so the next
  /// launch starts the OTP flow from scratch.
  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_signedOutKey);
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());
