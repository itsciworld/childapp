import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/social_upload_response.dart';
import '../../../../core/platform/social_queue_file.dart';
import '../../../../core/storage/device_storage.dart';
import '../models/screen_message_entry.dart';

/// Owns all data access for FEATURE B (on-screen capture): draining the native
/// accessibility queue file and uploading the records. Same shape as
/// `NotificationCaptureRepository`, just a different queue file + endpoint.
///
/// ─────────────────────────────────────────────────────────────────────────
///  GOING LIVE: when the backend endpoint exists, do exactly two things —
///    1. set [_endpoint] to the real path, and
///    2. flip [_uploadEnabled] to return `true`.
///  (And adjust `ScreenMessageEntry.toChatMessageJson()` / [_groupByConversation]
///   / `SocialUploadResponse` if the schema differs.) Everything else stays.
/// ─────────────────────────────────────────────────────────────────────────
class ScreenCaptureRepository {
  ScreenCaptureRepository(this._dio, this._deviceStorage);

  final Dio _dio;
  final DeviceStorage _deviceStorage;
  final SocialQueueFile _queue = SocialQueueFile('a11y_queue.jsonl');

  static const String _tag = '[SocialA11y]';

  /// Live endpoint for captured on-screen text.
  static const String _endpoint = '/api/social/screen';

  /// While `false`, nothing is sent over the network — the payload that WOULD
  /// be posted is printed in full to the debug console instead. Live now that
  /// the backend is ready.
  static bool get _uploadEnabled => true;

  /// Drains everything captured since the last pass into upload-ready entries.
  Future<List<ScreenMessageEntry>> readQueued() async {
    final raw = await _queue.drain();
    return raw.map(ScreenMessageEntry.fromQueue).toList();
  }

  /// Puts [entries] back on the queue so a later pass retries them — used on
  /// upload failure or when a pass exceeds its per-run cap.
  Future<void> requeue(List<ScreenMessageEntry> entries) async {
    if (entries.isEmpty) return;
    await _queue.requeue(entries.map((e) => jsonEncode(e.toQueueMap())));
  }

  /// Uploads one batch. In debug-only mode this logs the payload and returns a
  /// synthetic response; with [_uploadEnabled] it POSTs to [_endpoint] exactly
  /// like the other repositories. Throws [ApiException] on a real failure.
  Future<SocialUploadResponse> store(
    List<ScreenMessageEntry> entries, {
    required String childId,
    required String parentId,
  }) async {
    final payload = <String, dynamic>{
      'child_id': childId,
      'parent_id': parentId,
      'conversations': _groupByConversation(entries),
    };

    _logPayload(entries, payload);

    if (!_uploadEnabled) {
      return SocialUploadResponse.debug(entries.length);
    }

    try {
      final deviceKey = await _deviceStorage.getDeviceKey();
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
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const ApiException('Unexpected response from the server.');
      }
      return SocialUploadResponse.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on FormatException catch (e) {
      throw ApiException(e.message);
    }
  }

  /// Folds a flat, chronologically-ordered list of captured lines into the
  /// chat-shaped upload payload: one entry per open chat, each holding its
  /// messages in the order they were read off the screen. Order within a
  /// conversation is preserved; a `LinkedHashMap` also keeps the conversations
  /// themselves in first-seen order.
  List<Map<String, dynamic>> _groupByConversation(
    List<ScreenMessageEntry> entries,
  ) {
    final groups = <String, Map<String, dynamic>>{};
    for (final e in entries) {
      final key = '${e.packageName}|${e.conversation}';
      final group = groups.putIfAbsent(
        key,
        () => <String, dynamic>{
          'package': e.packageName,
          'app': e.appName,
          'conversation': e.conversation,
          'messages': <Map<String, dynamic>>[],
        },
      );
      (group['messages'] as List<Map<String, dynamic>>)
          .add(e.toChatMessageJson());
    }
    return groups.values.toList();
  }

  /// Detailed console dump — the "see every captured chat line" view, now laid
  /// out like a chat (sent lines indented right, received left) so the two-sided
  /// structure is visible at a glance.
  void _logPayload(
    List<ScreenMessageEntry> entries,
    Map<String, dynamic> payload,
  ) {
    if (!kDebugMode) return;
    debugPrint('$_tag ━━━━━━━━━━ batch of ${entries.length} ━━━━━━━━━━');
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      final chat = e.conversation.isNotEmpty ? e.conversation : '(unknown chat)';
      final side = switch (e.direction) {
        'sent' => '                    →',
        'received' => '←',
        _ => '·',
      };
      debugPrint('$_tag #${i + 1}  ${e.appName}  chat="$chat"');
      debugPrint('$_tag  $side ${e.text}');
      debugPrint('$_tag     [${e.direction}] ${e.capturedAt.toIso8601String()}');
    }
    final mode = _uploadEnabled ? 'POST → $_endpoint' : 'WOULD POST (DISABLED)';
    debugPrint('$_tag 📦 $mode');
    debugPrint('$_tag ${const JsonEncoder.withIndent('  ').convert(payload)}');
  }
}

final screenCaptureRepositoryProvider =
    Provider<ScreenCaptureRepository>((ref) {
  return ScreenCaptureRepository(
    ref.watch(dioProvider),
    ref.watch(deviceStorageProvider),
  );
});
