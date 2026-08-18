import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/device_storage.dart';
import '../../../core/storage/identity_storage.dart';
import '../../../core/storage/token_storage.dart';
import '../data/repositories/auth_repository.dart';

/// Where the splash should send the child once the stored session has been
/// evaluated.
enum SessionDestination {
  /// A session was restored (or is still valid) — go straight to the dashboard.
  childHome,

  /// No usable session — start onboarding at the login / OTP flow.
  login,
}

/// Restores the stored session — at cold start (see [resolve]) and when the
/// child signs in again after a logout (see [resumeSession]).
///
/// Order of checks at launch:
/// 1. The child logged out deliberately → login screen, no silent refresh.
/// 2. A refresh token is stored → call `POST /api/auth/refresh-token` silently.
///    On success the child goes straight to the dashboard — the OTP screen is
///    never shown.
/// 3. The refresh is rejected (401/403 — expired or revoked) → the local
///    session is wiped and the child starts the OTP flow again.
/// 4. The refresh could not be attempted (offline / timeout / server down) →
///    fall back to the stored access token so an already-paired device still
///    opens its dashboard without a network round-trip.
/// 5. Nothing stored → login.
class SessionResolver {
  SessionResolver(this._ref);

  final Ref _ref;

  Future<SessionDestination> resolve() async {
    final tokenStorage = _ref.read(tokenStorageProvider);

    // A logout keeps the refresh token so the next sign-in can skip the OTP —
    // but the child still has to sign in, so never restore it on our own here.
    if (await tokenStorage.isSignedOut()) {
      debugPrint('[SessionResolver] signed out → login');
      return SessionDestination.login;
    }

    if (await tokenStorage.hasRefreshToken()) {
      try {
        await _ref.read(authRepositoryProvider).refreshSession();
        // The dashboard also needs the child/parent ids; without them the
        // device was never fully paired on this install, so fall through to
        // the paired-state check below rather than opening a broken home.
        if (await _hasPairedIdentity()) {
          debugPrint('[SessionResolver] silent refresh OK → dashboard');
          return SessionDestination.childHome;
        }
        debugPrint('[SessionResolver] refreshed but no stored identity');
      } on ApiException catch (e) {
        if (_isAuthFailure(e)) {
          debugPrint('[SessionResolver] refresh token rejected '
              '(${e.statusCode}) → clearing session');
          await _clearSession();
          return SessionDestination.login;
        }
        // Network / server problem: keep the tokens and fall back below.
        debugPrint('[SessionResolver] refresh unavailable (${e.kind}): '
            '${e.message}');
      } catch (e, st) {
        debugPrint('[SessionResolver] unexpected refresh error: $e\n$st');
      }
    }

    // No refresh token, or the refresh could not complete: treat a stored
    // access token plus a complete identity as "already paired".
    final token = await tokenStorage.getToken();
    final isPaired =
        (token != null && token.isNotEmpty) && await _hasPairedIdentity();
    return isPaired ? SessionDestination.childHome : SessionDestination.login;
  }

  /// Signing in again after a logout: restores the previous session for
  /// [email] instead of emailing another OTP.
  ///
  /// Returns true when the child can go straight to the dashboard. Returns
  /// false — and the caller falls back to the normal login + OTP flow — when
  /// this device has no refresh token, is not paired, was paired to a different
  /// parent account, or the backend rejects the refresh token.
  Future<bool> resumeSession(String email) async {
    final tokenStorage = _ref.read(tokenStorageProvider);
    if (!await tokenStorage.hasRefreshToken()) return false;

    final identity = await _ref.read(identityStorageProvider).read();
    if (!identity.isComplete) return false;

    // Only the account this device is paired to may resume the session; a
    // different parent signing in has to pair through the OTP flow.
    if (!identity.matchesParentEmail(email)) {
      debugPrint('[SessionResolver] email does not match the paired account');
      return false;
    }

    try {
      await _ref.read(authRepositoryProvider).refreshSession();
      await tokenStorage.setSignedOut(false);
      debugPrint('[SessionResolver] session resumed for $email → dashboard');
      return true;
    } on ApiException catch (e) {
      if (_isAuthFailure(e)) {
        // Expired / revoked: drop the tokens so later launches stop retrying.
        debugPrint('[SessionResolver] stored refresh token rejected '
            '(${e.statusCode}) → OTP flow');
        await tokenStorage.clearTokens();
      } else {
        debugPrint('[SessionResolver] resume unavailable (${e.kind}): '
            '${e.message}');
      }
      return false;
    } catch (e, st) {
      debugPrint('[SessionResolver] unexpected resume error: $e\n$st');
      return false;
    }
  }

  Future<bool> _hasPairedIdentity() async {
    final identity = await _ref.read(identityStorageProvider).read();
    return identity.isComplete;
  }

  /// True when the server actively rejected the refresh token, as opposed to
  /// the request never reaching it.
  bool _isAuthFailure(ApiException e) {
    if (e.kind != ApiErrorKind.badResponse) return false;
    return e.statusCode == 401 || e.statusCode == 403;
  }

  /// Wipes the local session so the next screens start onboarding from scratch.
  Future<void> _clearSession() async {
    await Future.wait([
      _ref.read(tokenStorageProvider).clearTokens(),
      _ref.read(identityStorageProvider).clear(),
      _ref.read(deviceStorageProvider).clear(),
    ]);
  }
}

final sessionResolverProvider =
    Provider<SessionResolver>((ref) => SessionResolver(ref));
