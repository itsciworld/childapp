import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/contact_sync_storage.dart';
import 'contact_state.dart';
import 'contact_sync_service.dart';

/// Foreground entry point for contact sync. Delegates the actual work to
/// [ContactSyncService] (shared with the background isolate) and tracks the
/// last outcome in [ContactState].
class ContactViewModel extends Notifier<ContactState> {
  @override
  ContactState build() => const ContactState();

  Future<void> sync() async {
    state = state.copyWith(status: ContactSyncStatus.syncing);
    final response = await ref.read(contactSyncServiceProvider).sync();
    state = state.copyWith(
      status: response != null
          ? ContactSyncStatus.synced
          : ContactSyncStatus.error,
      lastResponse: response,
      lastSyncedAt: DateTime.now(),
    );
  }

  /// Pulls the last-run timestamp written by the background isolate into the UI
  /// state so the home screen's "Last sync" ticks live without re-uploading.
  Future<void> refreshStatus() async {
    final lastRun = await ref.read(contactSyncStorageProvider).getLastRunAt();
    if (lastRun == null) return;
    if (state.status == ContactSyncStatus.syncing) return;
    state = state.copyWith(
      status: ContactSyncStatus.synced,
      lastSyncedAt: lastRun,
    );
  }
}

final contactViewModelProvider =
    NotifierProvider<ContactViewModel, ContactState>(ContactViewModel.new);
