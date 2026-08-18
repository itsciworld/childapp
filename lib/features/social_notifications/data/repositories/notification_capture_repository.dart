import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/social_upload_response.dart';
import '../../../../core/platform/social_queue_file.dart';
import '../../../../core/storage/device_storage.dart';
import '../models/notification_message_entry.dart';

/// Owns all data access for FEATURE A (notification capture): draining the
/// native queue file and uploading the records. Mirrors `SmsRepository`, except
/// the "device read" is replaced by reading the JSONL queue the
/// [VigilNotificationListenerService] writes.
///
/// ─────────────────────────────────────────────────────────────────────────
///  GOING LIVE: when the backend endpoint exists, do exactly two things —
///    1. set [_endpoint] to the real path, and
///    2. flip [_uploadEnabled] to return `true`.
///  (And adjust `NotificationMessageEntry.toJson()` / `SocialUploadResponse`
///   if the schema differs.) Everything else stays.
/// ─────────────────────────────────────────────────────────────────────────
class NotificationCaptureRepository {
  NotificationCaptureRepository(this._dio, this._deviceStorage);

  final Dio _dio;
  final DeviceStorage _deviceStorage;
  final SocialQueueFile _queue = SocialQueueFile('notif_queue.jsonl');

  static const String _tag = '[SocialNotif]';

  /// Live endpoint for captured notifications.
  static const String _endpoint = '/api/social/notifications';

  /// While `false`, nothing is sent over the network — the payload that WOULD
  /// be posted is printed in full to the debug console instead. Live now that
  /// the backend is ready.
  static bool get _uploadEnabled => true;

  /// Drains everything captured since the last pass into upload-ready entries.
  Future<List<NotificationMessageEntry>> readQueued() async {
    final raw = await _queue.drain();
    final entries = raw.map(NotificationMessageEntry.fromQueue).toList();
    if (entries.isNotEmpty) {
      final byApp = <String, int>{};
      for (final e in entries) {
        final key = e.appName.isNotEmpty ? e.appName : e.packageName;
        byApp[key] = (byApp[key] ?? 0) + 1;
      }
      debugPrint('$_tag 📥 DRAINED ${entries.length} captured message(s) '
          'from notif_queue.jsonl — $byApp');
    }
    return entries;
  }

  /// Puts [entries] back on the queue (newest-appended) so a later pass retries
  /// them — used on upload failure or when a pass exceeds its per-run cap.
  Future<void> requeue(List<NotificationMessageEntry> entries) async {
    if (entries.isEmpty) return;
    await _queue.requeue(entries.map((e) => jsonEncode(e.toQueueMap())));
  }

  /// Uploads one batch. In debug-only mode this just logs the payload and
  /// returns a synthetic response; with [_uploadEnabled] it POSTs to
  /// [_endpoint] exactly like `SmsRepository.storeSms` (device key header and
  /// all). Throws [ApiException] on a real network/server failure.
  Future<SocialUploadResponse> store(
    List<NotificationMessageEntry> entries, {
    required String childId,
    required String parentId,
  }) async {
    final payload = <String, dynamic>{
      'child_id': childId,
      'parent_id': parentId,
      'messages': entries.map((e) => e.toJson()).toList(),
    };

    if (!_uploadEnabled) {
      return SocialUploadResponse.debug(entries.length);
    }

    final startedAt = DateTime.now();

    try {
      final deviceKey = await _deviceStorage.getDeviceKey();
      debugPrint('$_tag ⬆️  POSTING ${entries.length} message(s) → '
          '${_dio.options.baseUrl}$_endpoint '
          '(child=$childId, deviceKey=${deviceKey != null && deviceKey.isNotEmpty ? 'yes' : 'MISSING'})');

      final response = await _dio.post<dynamic>(
        _endpoint,
        data: payload,
        options: Options(
          headers: {
            if (deviceKey != null && deviceKey.isNotEmpty)
              'x-device-key': deviceKey,
          },
        ),
      );

      final ms = DateTime.now().difference(startedAt).inMilliseconds;
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        debugPrint('$_tag ❌ BACKEND REJECTED — HTTP ${response.statusCode} '
            'returned ${data.runtimeType}, expected a JSON object. Body: $data');
        throw const ApiException('Unexpected response from the server.');
      }

      final parsed = SocialUploadResponse.fromJson(data);
      debugPrint('$_tag ✅ POSTED OK — HTTP ${response.statusCode} in ${ms}ms | '
          'sent=${entries.length} saved=${parsed.saved ?? '?'} '
          'skipped=${parsed.duplicates ?? '?'}');
      return parsed;
    } on DioException catch (e) {
      final ms = DateTime.now().difference(startedAt).inMilliseconds;
      debugPrint('$_tag ❌ POST FAILED — HTTP ${e.response?.statusCode ?? 'no-response'} '
          '(${e.type.name}) in ${ms}ms | ${entries.length} message(s) re-queued');
      debugPrint('$_tag    reason: ${e.response?.data ?? e.message}');
      throw ApiException.fromDio(e);
    } on FormatException catch (e) {
      debugPrint('$_tag ❌ RESPONSE PARSE FAILED — ${e.message}');
      throw ApiException(e.message);
    }
  }
}

final notificationCaptureRepositoryProvider =
    Provider<NotificationCaptureRepository>((ref) {
  return NotificationCaptureRepository(
    ref.watch(dioProvider),
    ref.watch(deviceStorageProvider),
  );
});
