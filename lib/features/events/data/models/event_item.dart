/// A single calendar event inside the `events` array of
/// `POST /api/events/store_events`.
///
/// `child_id` / `parent_id` are NOT part of an event — they are sent once at
/// the top level of the request body (see [EventRepository.storeEvents]).
///
/// Matches one element of the `events` array:
/// `{ "title", "start", "end", "location", "description" }`.
class EventItem {
  const EventItem({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.location,
    this.description,
  });

  /// Device-local unique id (instanceId) — used only for de-duplication; it is
  /// NOT sent in the body.
  final String id;

  final String title;
  final DateTime start;
  final DateTime end;
  final String? location;
  final String? description;

  Map<String, dynamic> toJson() => {
        'title': title,
        // ISO-8601 in UTC, e.g. `2026-06-10T09:00:00Z`.
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
        'location': location,
        'description': description,
      };
}
