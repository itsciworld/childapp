import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:usage_stats/usage_stats.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/device_storage.dart';
import '../models/app_usage_item.dart';
import '../models/save_apps_response.dart';

/// Owns all app-usage data access: reading foreground-usage stats, resolving
/// each package's human app name, and uploading them to the backend. The UI /
/// background loop never touches `usage_stats` / `installed_apps` or Dio
/// directly — it goes through this repository.
class AppUsageRepository {
  AppUsageRepository(this._dio, this._deviceStorage);

  final Dio _dio;
  final DeviceStorage _deviceStorage;

  /// packageName → appName cache, so we resolve each label at most once per
  /// isolate (the name lookup is a platform call).
  final Map<String, String> _nameCache = {};

  static const String _tag = '[AppUsageRepo]';

  /// How far back to total each app's usage.
  static const Duration _window = Duration(hours: 24);

  /// Whether Usage Access is granted (Android-only special permission).
  Future<bool> hasPermission() async =>
      (await UsageStats.checkUsagePermission()) ?? false;

  /// Reads the last-24h foreground usage and maps it into upload-ready
  /// [AppUsageItem]s (only apps with ≥ 1 minute of usage), sorted most-used
  /// first. Returns an empty list when permission isn't granted.
  Future<List<AppUsageItem>> readUsage() async {
    try {
      if (!await hasPermission()) {
        debugPrint('$_tag usage access not granted — skipping.');
        return const [];
      }

      final end = DateTime.now();
      final start = end.subtract(_window);
      // Aggregating collapses the per-interval rows into one entry per package.
      final stats = await UsageStats.queryAndAggregateUsageStats(start, end);

      final items = <AppUsageItem>[];
      for (final entry in stats.values) {
        final pkg = entry.packageName;
        if (pkg == null || pkg.isEmpty) continue;

        final foregroundMs =
            int.tryParse(entry.totalTimeInForeground ?? '') ?? 0;
        final minutes = foregroundMs ~/ 60000;
        if (minutes < 1) continue; // skip apps barely/never used in the window

        final lastUsedMs = int.tryParse(entry.lastTimeUsed ?? '');
        items.add(
          AppUsageItem(
            packageName: pkg,
            appName: await _appName(pkg),
            usageMinutes: minutes,
            lastTimeUsed: lastUsedMs == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(lastUsedMs),
          ),
        );
      }

      items.sort((a, b) => b.usageMinutes.compareTo(a.usageMinutes));
      return items;
    } catch (e, st) {
      debugPrint('$_tag failed to read usage: $e\n$st');
      return const [];
    }
  }

  /// Resolves a package's display name, caching the result. Falls back to the
  /// package name when the label can't be resolved.
  Future<String> _appName(String packageName) async {
    final cached = _nameCache[packageName];
    if (cached != null) return cached;
    String name = packageName;
    try {
      final info = await InstalledApps.getAppInfo(packageName);
      if (info != null && info.name.isNotEmpty) name = info.name;
    } catch (_) {/* fall back to packageName */}
    _nameCache[packageName] = name;
    return name;
  }

  /// Uploads [apps] to `POST /api/apps/save_apps`.
  ///
  /// [childId] / [parentId] are sent once at the top level of the body. The
  /// backend-issued device key is sent in the `x-device-key` header. The server
  /// response is printed so success can be confirmed from the debug log.
  ///
  /// Throws [ApiException] on any network / server failure.
  Future<SaveAppsResponse> saveApps(
    List<AppUsageItem> apps, {
    required String childId,
    required String parentId,
  }) async {
    try {
      final deviceKey = await _deviceStorage.getDeviceKey();
      final response = await _dio.post<dynamic>(
        '/api/apps/save_apps',
        data: {
          'child_id': childId,
          'parent_id': parentId,
          'apps': apps.map((e) => e.toJson()).toList(),
        },
        options: Options(
          headers: {
            if (deviceKey != null && deviceKey.isNotEmpty)
              'x-device-key': deviceKey,
          },
        ),
      );

      // Print the raw response so the API result is visible in the debug log.
      debugPrint('$_tag save_apps response '
          '(${response.statusCode}): ${response.data}');

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const ApiException('Unexpected response from the server.');
      }
      return SaveAppsResponse.fromJson(data);
    } on DioException catch (e) {
      debugPrint('$_tag save_apps failed: '
          '${e.response?.statusCode} ${e.response?.data ?? e.message}');
      throw ApiException.fromDio(e);
    } on FormatException catch (e) {
      throw ApiException(e.message);
    }
  }
}

final appUsageRepositoryProvider = Provider<AppUsageRepository>((ref) {
  return AppUsageRepository(
    ref.watch(dioProvider),
    ref.watch(deviceStorageProvider),
  );
});
