import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env_config.dart';
import '../storage/device_storage.dart';

/// Builds a [Dio] configured for [baseUrl] with the shared timeouts, the
/// `x-device-key` interceptor, and (in debug) response logging, so that config
/// lives in one place.
Dio _buildDio(String baseUrl) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: Duration(milliseconds: EnvConfig.connectTimeoutMs),
      receiveTimeout: Duration(milliseconds: EnvConfig.receiveTimeoutMs),
      headers: const {'Content-Type': 'application/json'},
    ),
  );

  // Attach the backend-issued device key to every request as `x-device-key`,
  // so each repository no longer has to set it by hand. Before pairing (no key
  // stored yet) the header is simply omitted. A request can opt out — e.g. the
  // permissions calls, which authenticate with the bearer token only — by
  // setting `extra: {'skipDeviceKey': true}`. An explicitly-set header on the
  // request is left untouched.
  final deviceStorage = DeviceStorage();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final skip = options.extra['skipDeviceKey'] == true;
        if (!skip && !options.headers.containsKey('x-device-key')) {
          final deviceKey = await deviceStorage.getDeviceKey();
          if (deviceKey != null && deviceKey.isNotEmpty) {
            options.headers['x-device-key'] = deviceKey;
          }
        }
        handler.next(options);
      },
    ),
  );

  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        // Keep request bodies OUT of the console: the SMS upload payload is
        // huge and would dump every message body on each (retried) sync pass.
        // The SmsSyncService already logs just the count.
        requestBody: false,
        responseBody: true,
        logPrint: (obj) => debugPrint('[DIO] $obj'),
      ),
    );
  }

  return dio;
}

/// A single, shared [Dio] for the main monitoring backend ([EnvConfig.apiBaseUrl]).
///
/// Repositories should depend on this provider rather than creating their own
/// HTTP client, so base URL / timeouts / interceptors live in one place.
final dioProvider = Provider<Dio>((ref) => _buildDio(EnvConfig.apiBaseUrl));
