/// A single contact uploaded to `POST /api/contacts/store_contacts`.
///
/// Matches one element of the `contacts` array in the request body:
/// `{ "name", "phone", "child_id", "parent_id" }`.
class ContactItem {
  const ContactItem({
    required this.name,
    required this.phone,
    required this.childId,
    required this.parentId,
  });

  /// Contact display name (empty when unnamed).
  final String name;

  /// Phone number, e.g. `+923001234567`. Also used as the dedupe key.
  final String phone;

  final String childId;
  final String parentId;

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'child_id': childId,
        'parent_id': parentId,
      };
}
