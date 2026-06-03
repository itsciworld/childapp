import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/device_storage.dart';
import '../models/sms_entry.dart';
import '../models/store_sms_response.dart';

/// Owns all SMS data access: reading messages from the device inbox and
/// uploading them to the backend. The UI / background loop never talks to the
/// SMS plugin or Dio directly — it goes through this repository.
class SmsRepository {
  SmsRepository(this._dio, this._deviceStorage);

  final Dio _dio;
  final DeviceStorage _deviceStorage;
  final SmsQuery _query = SmsQuery();

  /// Reads device messages (inbox + sent) and maps them into upload-ready
  /// [SmsEntry]s tagged with [childId] / [parentId], **sorted oldest-first**.
  ///
  /// Incremental behaviour:
  /// - When [since] is given, only messages strictly newer than it are
  ///   returned — this is the watermark that prevents re-uploading messages
  ///   already sent on a previous app session.
  /// - When [since] is `null` (first ever sync on this device) only the most
  ///   recent [firstSyncLimit] messages are returned, so the very first upload
  ///   doesn't dump the entire history.
  ///
  /// Returns an empty list when there is nothing new. Assumes the `READ_SMS`
  /// permission has already been granted by the permissions flow.
  Future<List<SmsEntry>> readDeviceSms({
    required String childId,
    required String parentId,
    DateTime? since,
    int fetchLimit = 500,
  }) async {
    final messages = await _query.querySms(
      kinds: const [SmsQueryKind.inbox, SmsQueryKind.sent],
      count: fetchLimit,
    );

    // Oldest-first so the caller can use the last entry as the new watermark.
    messages.sort(
        (a, b) => (a.date ?? DateTime(0)).compareTo(b.date ?? DateTime(0)));

    List<SmsMessage> selected;
    if (since != null) {
      selected = messages
          .where((m) => m.date != null && m.date!.isAfter(since))
          .toList();
    } else {
      // First sync: take everything fetched (oldest-first); the caller uploads
      // it one batch per pass, so the backlog drains gradually.
      selected = messages;
    }

    final entries = <SmsEntry>[];
    for (final message in selected) {
      final address = message.address;
      if (address == null || address.isEmpty) continue;
      entries.add(
        SmsEntry(
          address: address,
          body: message.body ?? '',
          date: message.date ?? DateTime.now(),
          childId: childId,
          parentId: parentId,
        ),
      );
    }
    return entries;
  }

  /// Uploads [entries] to `POST /api/sms/store_sms`.
  ///
  /// The backend-issued device key (stored at pairing) is sent in the
  /// `x-device-key` header so the server can authorise this paired device.
  ///
  /// Throws [ApiException] on any network / server failure.
  Future<StoreSmsResponse> storeSms(List<SmsEntry> entries) async {
    try {
      final deviceKey = await _deviceStorage.getDeviceKey();
      final response = await _dio.post<dynamic>(
        '/api/sms/store_sms',
        data: {'sms': entries.map((e) => e.toJson()).toList()},
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
      return StoreSmsResponse.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on FormatException catch (e) {
      throw ApiException(e.message);
    }
  }
}

final smsRepositoryProvider = Provider<SmsRepository>((ref) {
  return SmsRepository(
    ref.watch(dioProvider),
    ref.watch(deviceStorageProvider),
  );
});
