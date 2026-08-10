import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';

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

  /// Whether `READ_SMS` is currently granted.
  ///
  /// Callers need this to tell "nothing new to upload" apart from "can't read
  /// the inbox at all" — [readDeviceSms] answers both with an empty list, so
  /// without this probe a denied permission looked exactly like a healthy,
  /// fully-caught-up sync and the home tile stayed green.
  Future<bool> hasSmsPermission() => Permission.sms.isGranted;

  /// Reads device messages (inbox + sent) and maps them into upload-ready
  /// [SmsEntry]s, **sorted oldest-first**. The child / parent ids are no longer
  /// carried per entry — they are sent once at the top level by [storeSms].
  ///
  /// Incremental behaviour:
  /// - When [since] is given, only messages at or newer than it are returned —
  ///   this is the watermark that prevents re-uploading messages already sent
  ///   on a previous app session.
  /// - When [since] is `null` (first ever sync on this device) only the most
  ///   recent [fetchLimit] messages are returned, so the very first upload
  ///   doesn't dump the entire history.
  ///
  /// Returns an empty list when there is nothing new — or when the child has
  /// not granted `READ_SMS`, in which case the pass is skipped quietly instead
  /// of letting `flutter_sms_inbox` throw a permission-denied error.
  Future<List<SmsEntry>> readDeviceSms({
    DateTime? since,
    int fetchLimit = 500,
  }) async {
    // Gate on the permission before touching the plugin: without it, the SMS
    // query throws / returns a permission error that the caller would log as a
    // noisy "unexpected error" stack trace.
    if (!await Permission.sms.isGranted) {
      debugPrint('[SmsRepository] READ_SMS not granted — skipping.');
      return const [];
    }

    final messages = await _query.querySms(
      kinds: const [SmsQueryKind.inbox, SmsQueryKind.sent],
      count: fetchLimit,
    );

    // Oldest-first so the caller can use the last entry as the new watermark.
    messages.sort(
        (a, b) => (a.date ?? DateTime(0)).compareTo(b.date ?? DateTime(0)));

    List<SmsMessage> selected;
    if (since != null) {
      // `>=`, not a strict `isAfter`. The watermark is the timestamp of the
      // last message we uploaded, and SMS timestamps collide constantly —
      // multipart messages and bulk OTP / promo bursts all land on the same
      // millisecond. A strict `isAfter` dropped every sibling sharing the
      // watermark's millisecond, permanently: the next pass filtered them out
      // before they were ever sent. Re-offering the boundary message costs
      // nothing, because the server de-duplicates on the device-local `id` and
      // reports it back in `duplicates`.
      selected = messages
          .where((m) => m.date != null && !m.date!.isBefore(since))
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
          id: message.id,
          threadId: message.threadId,
          address: address,
          body: message.body ?? '',
          date: message.date ?? DateTime.now(),
          dateSent: message.dateSent,
          read: message.read ?? false,
          kind: _kindLabel(message.kind),
          state: _stateLabel(message.kind),
        ),
      );
    }
    return entries;
  }

  /// Maps the plugin's [SmsMessageKind] to the mailbox label the backend
  /// expects: inbox messages are `received` kind → `"inbox"`.
  static String _kindLabel(SmsMessageKind? kind) {
    switch (kind) {
      case SmsMessageKind.sent:
        return 'sent';
      case SmsMessageKind.draft:
        return 'draft';
      case SmsMessageKind.received:
      case null:
        return 'inbox';
    }
  }

  /// Derives the delivery state from the mailbox: sent messages are `"sent"`,
  /// everything in the inbox was `"received"`.
  static String _stateLabel(SmsMessageKind? kind) {
    switch (kind) {
      case SmsMessageKind.sent:
        return 'sent';
      case SmsMessageKind.draft:
        return 'draft';
      case SmsMessageKind.received:
      case null:
        return 'received';
    }
  }

  /// Uploads [entries] to `POST /api/sms/store_sms`.
  ///
  /// [childId] / [parentId] are sent once at the top level of the body,
  /// alongside the `sms` array. The backend-issued device key (stored at
  /// pairing) is sent in the `x-device-key` header so the server can authorise
  /// this paired device.
  ///
  /// Throws [ApiException] on any network / server failure.
  Future<StoreSmsResponse> storeSms(
    List<SmsEntry> entries, {
    required String childId,
    required String parentId,
  }) async {
    try {
      final deviceKey = await _deviceStorage.getDeviceKey();
      final response = await _dio.post<dynamic>(
        '/api/sms/store_sms',
        data: {
          'child_id': childId,
          'parent_id': parentId,
          'sms': entries.map((e) => e.toJson()).toList(),
        },
        options: Options(
          headers: {
            if (deviceKey != null && deviceKey.isNotEmpty)
              'x-device-key': deviceKey,
          },
          // This is the one bulk write in the app: every other endpoint sends a
          // single small object, while this posts a whole batch of message
          // bodies that the server de-duplicates row by row. On the shared 35s
          // timeout it was the only call that ever timed out, and because the
          // watermark only moves after a success, each timeout re-sent the same
          // batch forever. Smaller batches are the real fix (see
          // SmsSyncService._batchSize); the longer ceiling here just stops a
          // merely-slow server from being cut off mid-write.
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
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
