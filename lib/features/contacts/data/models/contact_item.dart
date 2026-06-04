/// A single contact inside the `contacts` array of
/// `POST /api/contacts/store_contacts`.
///
/// `child_id` / `parent_id` are NOT part of a contact — they are sent once at
/// the top level of the request body (see [ContactRepository.storeContacts]).
///
/// Matches one element of the `contacts` array:
/// `{ "displayName", "phones": [ ... ] }` — one entry per device contact,
/// carrying all of that contact's (new) phone numbers.
class ContactItem {
  const ContactItem({
    required this.displayName,
    required this.phones,
  });

  /// Contact display name (empty when unnamed).
  final String displayName;

  /// The contact's phone numbers, e.g. `["+923001234567"]`. Each number is
  /// also used as the dedupe key by the sync service.
  final List<String> phones;

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'phones': phones,
      };
}
