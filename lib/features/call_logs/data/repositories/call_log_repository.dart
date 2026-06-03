import 'package:call_log/call_log.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/device_storage.dart';
import '../models/call_log_item.dart';
import '../models/store_call_logs_response.dart';

/// Owns all call-log data access: reading entries from the device call history
/// and uploading them to the backend. The UI / background loop never talks to
/// the `call_log` plugin or Dio directly — it goes through this repository.
class CallLogRepository {
  CallLogRepository(this._dio, this._deviceStorage);

  final Dio _dio;
  final DeviceStorage _deviceStorage;

  /// Reads device call logs and maps them into upload-ready [CallLogItem]s
  /// tagged with [childId] / [parentId], **sorted oldest-first**.
  ///
  /// Incremental behaviour:
  /// - When [since] is given, only calls strictly newer than it are returned —
  ///   the watermark that prevents re-uploading already-sent calls.
  /// - When [since] is `null` (first ever sync) the FULL history is returned
  ///   (oldest-first). The caller uploads it one batch per pass (like the
  ///   contacts sync), so the whole backlog drains gradually instead of in one
  ///   huge request.
  ///
  /// Returns an empty list when there is nothing new. Assumes the
  /// `READ_CALL_LOG` permission has already been granted.
  Future<List<CallLogItem>> readDeviceCallLogs({
    required String childId,
    required String parentId,
    DateTime? since,
  }) async {
    // CRITICAL: never call `CallLog.query()` unless READ_CALL_LOG is granted.
    // The `call_log` plugin has a bug — when queried without permission (which
    // happens on first launch, before the user grants it, and always in a
    // background isolate where it can't show a prompt) it replies
    // MISSING_PERMISSIONS but leaves its internal `request` flag set. From then
    // on EVERY query returns ALREADY_RUNNING and the plugin double-replies
    // ("Reply already submitted") — permanently broken until the isolate
    // restarts, even after permission is granted. Gating on the permission
    // avoids ever tripping that path.
    if (!await Permission.phone.isGranted) {
      debugPrint('[CallLogRepository] READ_CALL_LOG not granted — skipping.');
      return const [];
    }

    final entries = (await CallLog.query()).toList();

    // Oldest-first so the caller can use the last entry as the new watermark.
    entries.sort((a, b) => (a.timestamp ?? 0).compareTo(b.timestamp ?? 0));

    List<CallLogEntry> selected;
    if (since != null) {
      final sinceMs = since.millisecondsSinceEpoch;
      selected = entries.where((e) => (e.timestamp ?? 0) > sinceMs).toList();
    } else {
      // First sync: take the full history (oldest-first); the caller batches it.
      selected = entries;
    }

    final logs = <CallLogItem>[];
    for (final entry in selected) {
      final number = entry.number;
      if (number == null || number.isEmpty) continue;
      logs.add(
        CallLogItem(
          number: number,
          name: entry.name ?? '',
          callType: (entry.callType ?? CallType.unknown).name,
          timestamp: DateTime.fromMillisecondsSinceEpoch(entry.timestamp ?? 0),
          duration: entry.duration ?? 0,
          childId: childId,
          parentId: parentId,
        ),
      );
    }
    return logs;
  }


  /// Uploads [logs] to `POST /api/logs/store_calllogs`.
  ///
  /// The backend-issued device key (stored at pairing) is sent in the
  /// `x-device-key` header so the server can authorise this paired device.
  ///
  /// Throws [ApiException] on any network / server failure.
  Future<StoreCallLogsResponse> storeCallLogs(List<CallLogItem> logs) async {
    try {
      final deviceKey = await _deviceStorage.getDeviceKey();
      final response = await _dio.post<dynamic>(
        '/api/logs/store_calllogs',
        data: {'logs': logs.map((e) => e.toJson()).toList()},
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
      return StoreCallLogsResponse.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on FormatException catch (e) {
      throw ApiException(e.message);
    }
  }
}

final callLogRepositoryProvider = Provider<CallLogRepository>((ref) {
  return CallLogRepository(
    ref.watch(dioProvider),
    ref.watch(deviceStorageProvider),
  );
});
