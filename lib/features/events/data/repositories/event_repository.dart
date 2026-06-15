import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/device_storage.dart';
import '../models/event_item.dart';
import '../models/store_events_response.dart';

/// Owns all calendar-event data access: reading events from every device
/// calendar and uploading them to the backend. The UI / background loop never
/// touches `device_calendar_plus` or Dio directly — it goes through here.
class EventRepository {
  EventRepository(this._dio, this._deviceStorage);

  final Dio _dio;
  final DeviceStorage _deviceStorage;
  final DeviceCalendar _calendar = DeviceCalendar.instance;

  static const String _tag = '[EventRepo]';

  /// How far forward to scan for events. We never look into the past — only
  /// events dated from the start of today onward are uploaded.
  static const Duration _futureWindow = Duration(days: 365);

  /// Reads device calendar events and maps them into upload-ready [EventItem]s,
  /// skipping any whose id is in [alreadySynced]. A new id de-dupes within the
  /// pass too, so the same instance isn't returned twice.
  ///
  /// Returns an empty list when there is nothing new or permission isn't
  /// granted (the sync just skips that pass — no API call).
  Future<List<EventItem>> readDeviceEvents({
    required Set<String> alreadySynced,
  }) async {
    try {
      final status = await _calendar.hasPermissions();
      if (status != CalendarPermissionStatus.granted) {
        debugPrint('$_tag calendar permission not granted — skipping.');
        return const [];
      }

      final calendars = await _calendar.listCalendars();
      if (calendars.isEmpty) return const [];

      final now = DateTime.now();
      // Only today and the future — start the scan at midnight today and skip
      // anything that started before it.
      final startOfToday = DateTime(now.year, now.month, now.day);
      final end = now.add(_futureWindow);

      final events = await _calendar.listEvents(
        startOfToday,
        end,
        calendarIds: calendars.map((c) => c.id).toList(),
      );

      final items = <EventItem>[];
      final seenThisPass = <String>{};
      for (final e in events) {
        // Belt-and-braces: the plugin can still return an event that overlaps
        // the window but started earlier (e.g. a multi-day event) — skip it.
        if (e.startDate.isBefore(startOfToday)) continue;
        final id = e.instanceId.isNotEmpty ? e.instanceId : e.eventId;
        if (id.isEmpty) continue;
        if (alreadySynced.contains(id)) continue;
        if (!seenThisPass.add(id)) continue;
        items.add(
          EventItem(
            id: id,
            title: e.title,
            start: e.startDate,
            end: e.endDate,
            location: (e.location?.isEmpty ?? true) ? null : e.location,
            description:
                (e.description?.isEmpty ?? true) ? null : e.description,
          ),
        );
      }
      return items;
    } catch (e, st) {
      debugPrint('$_tag failed to read events: $e\n$st');
      return const [];
    }
  }

  /// Uploads [events] to `POST /api/events/store_events`.
  ///
  /// [childId] / [parentId] are sent once at the top level of the body. The
  /// backend-issued device key is sent in the `x-device-key` header. The server
  /// response is printed so success can be confirmed from the debug log.
  ///
  /// Throws [ApiException] on any network / server failure.
  Future<StoreEventsResponse> storeEvents(
    List<EventItem> events, {
    required String childId,
    required String parentId,
  }) async {
    try {
      final deviceKey = await _deviceStorage.getDeviceKey();
      final response = await _dio.post<dynamic>(
        '/api/events/store_events',
        data: {
          'child_id': childId,
          'parent_id': parentId,
          'events': events.map((e) => e.toJson()).toList(),
        },
        options: Options(
          // Give the insert a generous window — a chunk is small, but a busy
          // server can still take a while to ack, and we'd rather wait than
          // abort and re-send (which the chunked sync would do next pass).
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
          headers: {
            if (deviceKey != null && deviceKey.isNotEmpty)
              'x-device-key': deviceKey,
          },
        ),
      );

      // Print the raw response so the API result is visible in the debug log.
      debugPrint('$_tag store_events response '
          '(${response.statusCode}): ${response.data}');

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const ApiException('Unexpected response from the server.');
      }
      return StoreEventsResponse.fromJson(data);
    } on DioException catch (e) {
      debugPrint('$_tag store_events failed: '
          '${e.response?.statusCode} ${e.response?.data ?? e.message}');
      throw ApiException.fromDio(e);
    } on FormatException catch (e) {
      throw ApiException(e.message);
    }
  }
}

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository(
    ref.watch(dioProvider),
    ref.watch(deviceStorageProvider),
  );
});
