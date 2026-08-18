import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vigil1/core/network/dio_client.dart';
import 'package:vigil1/core/storage/identity_storage.dart';
import 'package:vigil1/core/storage/token_storage.dart';
import 'package:vigil1/features/auth/data/models/auth_tokens.dart';
import 'package:vigil1/features/auth/viewmodel/session_resolver.dart';
import 'package:vigil1/features/verify_otp/data/models/verify_otp_response.dart';

/// Serves canned responses to Dio and records the paths that were called.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respond);

  /// Maps a request to a `(statusCode, body)` pair.
  final (int, Map<String, dynamic>) Function(RequestOptions options) respond;

  final List<String> requestedPaths = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedPaths.add(options.path);
    final (status, body) = respond(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

/// A paired, signed-out device: refresh token kept, access token gone.
Map<String, Object> _signedOutPrefs() => {
      'refresh_token': 'refresh-1',
      'session_signed_out': true,
      'childId': 'child-1',
      'parentId': 'parent-1',
      'parentEmail': 'parent@example.com',
    };

ProviderContainer _containerWith(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..httpClientAdapter = adapter;
  return ProviderContainer(overrides: [dioProvider.overrideWithValue(dio)]);
}

void main() {
  group('AuthTokens.fromJson', () {
    test('reads the flat token / refreshToken shape', () {
      final tokens = AuthTokens.fromJson({
        'token': 'access-1',
        'refreshToken': 'refresh-1',
      });

      expect(tokens.accessToken, 'access-1');
      expect(tokens.refreshToken, 'refresh-1');
    });

    test('reads snake_case and accessToken variants', () {
      final tokens = AuthTokens.fromJson({
        'access_token': 'access-2',
        'refresh_token': 'refresh-2',
      });

      expect(tokens.accessToken, 'access-2');
      expect(tokens.refreshToken, 'refresh-2');
    });

    test('reads tokens nested under data / tokens', () {
      final tokens = AuthTokens.fromJson({
        'msg': 'ok',
        'data': {'accessToken': 'access-3', 'refreshToken': 'refresh-3'},
      });

      expect(tokens.accessToken, 'access-3');
      expect(tokens.refreshToken, 'refresh-3');
    });

    test('is empty when the response carries no tokens', () {
      final tokens = AuthTokens.fromJson({'msg': 'OTP sent to email'});

      expect(tokens.hasAccessToken, isFalse);
      expect(tokens.hasRefreshToken, isFalse);
    });
  });

  test('VerifyOtpResponse keeps the refresh token alongside the child ids', () {
    final response = VerifyOtpResponse.fromJson({
      'msg': 'Device paired successfully',
      'child': {'_id': 'child-1', 'parentId': 'parent-1'},
      'token': 'access-1',
      'refreshToken': 'refresh-1',
      'deviceKey': 'device-key-1',
    });

    expect(response.childId, 'child-1');
    expect(response.parentId, 'parent-1');
    expect(response.token, 'access-1');
    expect(response.refreshToken, 'refresh-1');
    expect(response.deviceKey, 'device-key-1');
  });

  group('TokenStorage', () {
    test('persists both tokens and reports the refresh token', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = TokenStorage();

      await storage.saveTokens(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
      );

      expect(await storage.getToken(), 'access-1');
      expect(await storage.getRefreshToken(), 'refresh-1');
      expect(await storage.hasRefreshToken(), isTrue);
    });

    test('rotating only the access token keeps the refresh token', () async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'access-1',
        'refresh_token': 'refresh-1',
      });
      final storage = TokenStorage();

      await storage.saveTokens(accessToken: 'access-2');

      expect(await storage.getToken(), 'access-2');
      expect(await storage.getRefreshToken(), 'refresh-1');
    });

    test('clearAccessToken keeps the refresh token for the next sign-in',
        () async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'access-1',
        'refresh_token': 'refresh-1',
      });
      final storage = TokenStorage();

      await storage.clearAccessToken();

      expect(await storage.getToken(), isNull);
      expect(await storage.getRefreshToken(), 'refresh-1');
    });

    test('the signed-out flag round-trips and clearTokens resets it', () async {
      SharedPreferences.setMockInitialValues({'refresh_token': 'refresh-1'});
      final storage = TokenStorage();

      expect(await storage.isSignedOut(), isFalse);
      await storage.setSignedOut(true);
      expect(await storage.isSignedOut(), isTrue);

      await storage.clearTokens();
      expect(await storage.isSignedOut(), isFalse);
    });

    test('clearTokens wipes both, so the next launch shows the OTP flow',
        () async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'access-1',
        'refresh_token': 'refresh-1',
      });
      final storage = TokenStorage();

      await storage.clearTokens();

      expect(await storage.getToken(), isNull);
      expect(await storage.hasRefreshToken(), isFalse);
    });
  });

  group('Identity.matchesParentEmail', () {
    test('matches the paired account regardless of case / spacing', () {
      const identity = Identity(parentEmail: 'parent@example.com');

      expect(identity.matchesParentEmail(' Parent@Example.com '), isTrue);
      expect(identity.matchesParentEmail('other@example.com'), isFalse);
    });

    test('never matches when the device predates the stored email', () {
      const identity = Identity();

      expect(identity.matchesParentEmail('parent@example.com'), isFalse);
    });
  });

  group('SessionResolver', () {
    test('resolve() shows login after a logout, despite the refresh token',
        () async {
      SharedPreferences.setMockInitialValues(_signedOutPrefs());
      final adapter = _FakeAdapter((_) => (200, {'token': 'access-2'}));
      final container = _containerWith(adapter);
      addTearDown(container.dispose);

      final destination =
          await container.read(sessionResolverProvider).resolve();

      expect(destination, SessionDestination.login);
      // No silent refresh may run for a deliberately signed-out child.
      expect(adapter.requestedPaths, isEmpty);
    });

    test('signing back in restores the session instead of sending an OTP',
        () async {
      SharedPreferences.setMockInitialValues(_signedOutPrefs());
      final adapter = _FakeAdapter(
        (_) => (200, {'token': 'access-2', 'refreshToken': 'refresh-2'}),
      );
      final container = _containerWith(adapter);
      addTearDown(container.dispose);

      final resumed = await container
          .read(sessionResolverProvider)
          .resumeSession('parent@example.com');

      expect(resumed, isTrue);
      expect(adapter.requestedPaths, ['/api/auth/refresh-token']);

      final storage = TokenStorage();
      expect(await storage.getToken(), 'access-2');
      expect(await storage.getRefreshToken(), 'refresh-2');
      expect(await storage.isSignedOut(), isFalse);

      // With the flag cleared, the next cold start goes straight to the home.
      expect(
        await container.read(sessionResolverProvider).resolve(),
        SessionDestination.childHome,
      );
    });

    test('a different parent account still has to pair through the OTP flow',
        () async {
      SharedPreferences.setMockInitialValues(_signedOutPrefs());
      final adapter = _FakeAdapter((_) => (200, {'token': 'access-2'}));
      final container = _containerWith(adapter);
      addTearDown(container.dispose);

      final resumed = await container
          .read(sessionResolverProvider)
          .resumeSession('someone.else@example.com');

      expect(resumed, isFalse);
      expect(adapter.requestedPaths, isEmpty);
      expect(await TokenStorage().isSignedOut(), isTrue);
    });

    test('a rejected refresh token drops the session and falls back to OTP',
        () async {
      SharedPreferences.setMockInitialValues(_signedOutPrefs());
      final adapter = _FakeAdapter((_) => (401, {'msg': 'Token expired'}));
      final container = _containerWith(adapter);
      addTearDown(container.dispose);

      final resumed = await container
          .read(sessionResolverProvider)
          .resumeSession('parent@example.com');

      expect(resumed, isFalse);
      expect(await TokenStorage().hasRefreshToken(), isFalse);
    });
  });
}
