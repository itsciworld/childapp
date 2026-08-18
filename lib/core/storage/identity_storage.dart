import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The paired-device identity needed when uploading monitored data and for
/// greeting the child on the home screen.
class Identity {
  const Identity({
    this.childId,
    this.parentId,
    this.childName,
    this.childAge,
    this.parentEmail,
  });

  final String? childId;
  final String? parentId;
  final String? childName;
  final int? childAge;

  /// The parent email this device was paired with. Used at sign-in to check
  /// the same account is coming back before restoring the session silently.
  final String? parentEmail;

  /// True when [email] is the account this device is paired to. An install
  /// paired before the email was recorded has nothing to compare against, so
  /// it never matches and goes through the OTP flow.
  bool matchesParentEmail(String email) {
    final stored = parentEmail?.trim().toLowerCase();
    if (stored == null || stored.isEmpty) return false;
    return stored == email.trim().toLowerCase();
  }

  bool get isComplete =>
      (childId?.isNotEmpty ?? false) && (parentId?.isNotEmpty ?? false);
}

/// Persists the child / parent ids (and the child's display details) so any
/// isolate (including the background monitoring service) can read them from
/// [SharedPreferences].
class IdentityStorage {
  // Re-uses the existing `childId` key already written by the welcome flow.
  static const String _childIdKey = 'childId';
  static const String _parentIdKey = 'parentId';
  static const String _childNameKey = 'childName';
  static const String _childAgeKey = 'childAge';
  static const String _parentEmailKey = 'parentEmail';

  Future<void> save({
    String? childId,
    String? parentId,
    String? childName,
    int? childAge,
    String? parentEmail,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (childId != null && childId.isNotEmpty) {
      await prefs.setString(_childIdKey, childId);
    }
    if (parentId != null && parentId.isNotEmpty) {
      await prefs.setString(_parentIdKey, parentId);
    }
    if (childName != null && childName.isNotEmpty) {
      await prefs.setString(_childNameKey, childName);
    }
    if (childAge != null && childAge > 0) {
      await prefs.setInt(_childAgeKey, childAge);
    }
    if (parentEmail != null && parentEmail.isNotEmpty) {
      await prefs.setString(_parentEmailKey, parentEmail.trim().toLowerCase());
    }
  }

  Future<Identity> read() async {
    final prefs = await SharedPreferences.getInstance();
    // The background isolate caches prefs from app boot (before pairing). Reload
    // so it sees childId/parentId written later by the main isolate.
    await prefs.reload();
    return Identity(
      childId: prefs.getString(_childIdKey),
      parentId: prefs.getString(_parentIdKey),
      childName: prefs.getString(_childNameKey),
      childAge: prefs.getInt(_childAgeKey),
      parentEmail: prefs.getString(_parentEmailKey),
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_childIdKey);
    await prefs.remove(_parentIdKey);
    await prefs.remove(_childNameKey);
    await prefs.remove(_childAgeKey);
    await prefs.remove(_parentEmailKey);
  }
}

final identityStorageProvider =
    Provider<IdentityStorage>((ref) => IdentityStorage());

/// One-shot read of the stored [Identity] — handy for screens that just need
/// to display the child's details.
final identityProvider = FutureProvider<Identity>((ref) {
  return ref.watch(identityStorageProvider).read();
});
