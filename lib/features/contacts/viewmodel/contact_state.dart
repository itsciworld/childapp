import '../data/models/store_contacts_response.dart';

enum ContactSyncStatus { idle, syncing, synced, error }

/// Immutable state for contact sync. Mirrors the SMS state so the home screen
/// can show the last sync outcome.
class ContactState {
  const ContactState({
    this.status = ContactSyncStatus.idle,
    this.lastResponse,
    this.lastSyncedAt,
  });

  final ContactSyncStatus status;
  final StoreContactsResponse? lastResponse;
  final DateTime? lastSyncedAt;

  bool get isSyncing => status == ContactSyncStatus.syncing;

  ContactState copyWith({
    ContactSyncStatus? status,
    StoreContactsResponse? lastResponse,
    DateTime? lastSyncedAt,
  }) {
    return ContactState(
      status: status ?? this.status,
      lastResponse: lastResponse ?? this.lastResponse,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}
