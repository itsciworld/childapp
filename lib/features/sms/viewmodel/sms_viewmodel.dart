import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sms_state.dart';
import 'sms_sync_service.dart';

/// Foreground entry point for SMS sync. Delegates the actual work to
/// [SmsSyncService] (shared with the background isolate) and tracks the last
/// outcome in [SmsState].
///
/// The sync itself is silent — nothing is shown to the user — so this is only
/// needed if the app ever wants to trigger / observe a sync from the UI. The
/// recurring upload runs in the background service.
class SmsViewModel extends Notifier<SmsState> {
  @override
  SmsState build() => const SmsState();

  Future<void> sync() async {
    state = state.copyWith(status: SmsSyncStatus.syncing);
    final response = await ref.read(smsSyncServiceProvider).sync();
    state = state.copyWith(
      status: response != null ? SmsSyncStatus.synced : SmsSyncStatus.error,
      lastResponse: response,
      lastSyncedAt: DateTime.now(),
    );
  }
}

final smsViewModelProvider =
    NotifierProvider<SmsViewModel, SmsState>(SmsViewModel.new);
