import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env_config.dart';

/// A single, shared [Dio] instance configured from [EnvConfig].
///
/// Repositories should depend on this provider rather than creating their own
/// HTTP client, so base URL / timeouts / interceptors live in one place.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: EnvConfig.apiBaseUrl,
      connectTimeout: Duration(milliseconds: EnvConfig.connectTimeoutMs),
      receiveTimeout: Duration(milliseconds: EnvConfig.receiveTimeoutMs),
      headers: const {'Content-Type': 'application/json'},
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
});
