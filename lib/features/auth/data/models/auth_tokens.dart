/// The token pair the backend issues for a paired device.
///
/// [accessToken] is the short-lived credential sent as `Authorization: Bearer`;
/// [refreshToken] is the long-lived one exchanged at launch via
/// `POST /api/auth/refresh-token` so the child skips the OTP flow.
class AuthTokens {
  const AuthTokens({this.accessToken, this.refreshToken});

  final String? accessToken;
  final String? refreshToken;

  bool get hasAccessToken => accessToken?.isNotEmpty ?? false;
  bool get hasRefreshToken => refreshToken?.isNotEmpty ?? false;

  /// Pulls the tokens out of any auth response, tolerating the naming the
  /// backend uses across endpoints (`token` / `accessToken` / `access_token`,
  /// `refreshToken` / `refresh_token`) and a nested `data` / `tokens` wrapper.
  factory AuthTokens.fromJson(Map<dynamic, dynamic> json) {
    final sources = <Map<dynamic, dynamic>>[json];
    for (final key in const ['data', 'tokens', 'token', 'child']) {
      final nested = json[key];
      if (nested is Map) sources.add(nested);
    }

    return AuthTokens(
      accessToken: _pick(
        sources,
        const ['token', 'accessToken', 'access_token', 'authToken'],
      ),
      refreshToken: _pick(
        sources,
        const ['refreshToken', 'refresh_token'],
      ),
    );
  }

  /// First non-empty string found for any of [keys] across [sources].
  static String? _pick(List<Map<dynamic, dynamic>> sources, List<String> keys) {
    for (final source in sources) {
      for (final key in keys) {
        final value = source[key];
        if (value is String && value.isNotEmpty) return value;
      }
    }
    return null;
  }
}
