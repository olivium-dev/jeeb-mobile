import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/app_failure.dart';
import '../../../features/home_client/data/dev_client_home_fixtures.dart';
import '../../../features/home_client/data/in_memory_client_home_repository.dart';
import '../../../features/shell/shell_screen.dart';
import '../../../features/chat/application/chat_conversations_cubit.dart';
import '../../../features/shell/tabs/chat_tab.dart';
import '../../../features/shell/tabs/earnings_tab.dart';
import '../../../features/shell/tabs/home_tab.dart';
import '../../../features/shell/tabs/orders_tab.dart';
import '../../../features/shell/widgets/jeeber_tab_empty_state.dart';
import '../../../features/shell/widgets/jeeber_tab_failure_state.dart';
import '../../../features/shell/widgets/shell_header_actions.dart';
import '../../../features/support/presentation/support_ticket_detail_screen.dart';
import '../../../features/support/presentation/support_ticket_screen.dart';
import '../../../features/tier_selection/data/tier_repository.dart';
import '../../../features/tier_selection/presentation/tier_selection_screen.dart';
import '../../../features/transcription/domain/transcript_audio_player.dart';
import '../../../features/transcription/presentation/transcription_screen.dart';
import '../../../features/voice_request/cubit/voice_recording_state.dart';
import '../../../features/voice_request/data/voice_recording_repository.dart';
import '../../../features/voice_request/domain/voice_recorder.dart';
import '../../../features/voice_request/presentation/voice_recording_screen.dart';
import '../../../features/wallet/data/empty_wallet_ledger_repository.dart';
import '../../../features/wallet/domain/wallet_ledger_repository.dart';
import '../../../features/wallet/domain/wallet_repository.dart';
import '../../../features/wallet/domain/wallet_transaction_repository.dart';
import '../../../features/wallet/presentation/customer_wallet_stub_screen.dart';
import '../../../features/wallet/presentation/transaction_detail_screen.dart';
import '../../../features/wallet/presentation/wallet_activity_list_screen.dart';
import '../../../features/wallet/presentation/wallet_charge_info_screen.dart';
import '../../../features/wallet/presentation/wallet_hub_screen.dart';
import '../catalog_models.dart';
import '../fixtures/chat_tab_fixtures.dart';
import '../fixtures/shell_screen_fixtures.dart';
import '../fixtures/support_ticket_detail_screen_fixtures.dart';
import '../fixtures/support_ticket_screen_fixtures.dart';
import '../fixtures/tier_selection_screen_fixtures.dart';
import '../fixtures/customer_wallet_stub_screen_fixtures.dart';
import '../fixtures/transaction_detail_screen_fixtures.dart';
import '../fixtures/transcription_screen_fixtures.dart';
import '../fixtures/voice_recording_screen_fixtures.dart';
import '../fixtures/wallet_activity_list_screen_fixtures.dart';
import '../fixtures/wallet_charge_info_screen_fixtures.dart';
import '../fixtures/wallet_hub_screen_fixtures.dart';

/// DashboardTab skipped — no override seam for sl<...>() service locators.
List<CatalogEntry> get batch11Entries => <CatalogEntry>[
  _jeeberTabEmptyStateEntry,
  _jeeberTabFailureStateEntry,
  _shellHeaderActionsEntry,
  _homeTabEntry,
  _chatTabEntry,
  _ordersTabEntry,
  _earningsTabEntry,
  _shellScreenEntry,
  _supportTicketEntry,
  _supportTicketDetailEntry,
  _tierSelectionEntry,
  _transcriptionEntry,
  _voiceRecordingEntry,
  _walletHubEntry,
  _transactionDetailEntry,
  _walletActivityListEntry,
  _walletChargeInfoEntry,
  _customerWalletStubEntry,
];

/// Wraps bare tab body in Scaffold for Material ancestor.
Widget _tabPreview(Widget child) => Scaffold(body: child);

final CatalogEntry _jeeberTabEmptyStateEntry = CatalogEntry(
  feature: 'shell',
  screen: 'JeeberTabEmptyState',
  states: [
    CatalogState(
      'Dashboard tab — become-a-jeeber invitation',
      (_) => _tabPreview(const JeeberTabEmptyState.dashboard()),
    ),
    CatalogState(
      'Earnings tab — become-a-jeeber invitation',
      (_) => _tabPreview(const JeeberTabEmptyState.earnings()),
    ),
  ],
);

final CatalogEntry _jeeberTabFailureStateEntry = CatalogEntry(
  feature: 'shell',
  screen: 'JeeberTabFailureState',
  states: [
    CatalogState(
      'Dashboard tab — availability unreachable',
      (_) => _tabPreview(
        JeeberTabFailureState.dashboard(
          failure: const NetworkFailure(offline: true),
          onRetry: () {},
        ),
      ),
    ),
    CatalogState(
      'Earnings tab — availability unreachable',
      (_) => _tabPreview(
        JeeberTabFailureState.earnings(
          failure: const ServerFailure(status: 503),
          onRetry: () {},
        ),
      ),
    ),
    CatalogState(
      'Dashboard tab — availability loading',
      (_) => _tabPreview(const JeeberTabLoadingState.dashboard()),
    ),
    CatalogState(
      'Earnings tab — availability loading',
      (_) => _tabPreview(const JeeberTabLoadingState.earnings()),
    ),
  ],
);

final CatalogEntry _shellHeaderActionsEntry = CatalogEntry(
  feature: 'shell',
  screen: 'ShellHeaderActions',
  states: [
    CatalogState(
      'Requests header — search / wallet chip / bell',
      (_) => _tabPreview(
        const Align(
          alignment: AlignmentDirectional.topEnd,
          child: SafeArea(child: ShellHeaderActions(idPrefix: 'orders_home')),
        ),
      ),
    ),
  ],
);

final CatalogEntry _homeTabEntry = CatalogEntry(
  feature: 'shell',
  screen: 'HomeTab',
  states: [
    CatalogState(
      'Populated — In Progress / Pending / Replies fixtures',
      (_) => _tabPreview(
        HomeTab(
          repository: InMemoryClientHomeRepository.fromSnapshot(
            DevClientHomeFixtures.snapshot(),
          ),
          greetingNameProvider: () => 'Sami',
        ),
      ),
    ),
    CatalogState(
      'Empty — nothing to show yet',
      (_) => _tabPreview(
        HomeTab(
          repository: InMemoryClientHomeRepository(),
          greetingNameProvider: () => 'Sami',
        ),
      ),
    ),
  ],
);

final CatalogEntry _chatTabEntry = CatalogEntry(
  feature: 'shell',
  screen: 'ChatTab',
  states: [
    CatalogState(
      'Rows — 3 conversations, one unroutable',
      (_) => _tabPreview(ChatTab(repository: ChatTabPreviewFixtures.rows())),
    ),
    CatalogState(
      'Loading — cold read in flight',
      (_) => _tabPreview(ChatTab(repository: ChatTabPreviewFixtures.loading())),
    ),
    CatalogState(
      'Empty — a real 200 with zero rows',
      (_) => _tabPreview(ChatTab(repository: ChatTabPreviewFixtures.empty())),
    ),
    CatalogState(
      'Error — gateway down (503)',
      (_) =>
          _tabPreview(ChatTab(repository: ChatTabPreviewFixtures.failed503())),
    ),
    CatalogState(
      'Error — offline',
      (_) => _tabPreview(ChatTab(repository: ChatTabPreviewFixtures.offline())),
    ),
    CatalogState(
      'Partial load — 1 row unroutable',
      (_) => _tabPreview(
        ChatTab(repository: ChatTabPreviewFixtures.partialLoad()),
      ),
    ),
    CatalogState('Refresh failed — rows stay up', (_) => _chatTabRefreshed()),
  ],
);

/// The warm rung needs a driven refresh, so the cubit is built here.
Widget _chatTabRefreshed() {
  final ChatConversationsCubit cubit = ChatConversationsCubit(
    ChatTabPreviewFixtures.refreshFailed(),
  );
  unawaited(cubit.load().then((_) => cubit.refresh()));
  return _tabPreview(ChatTab(cubit: cubit));
}

final CatalogEntry _ordersTabEntry = CatalogEntry(
  feature: 'shell',
  screen: 'OrdersTab',
  states: [
    CatalogState(
      'Populated — active / completed / cancelled orders',
      (_) => _tabPreview(
        OrdersTab(repository: ShellScreenPreviewFixtures.populatedOrders()),
      ),
    ),
    CatalogState(
      'Empty — no orders yet',
      (_) => _tabPreview(
        const OrdersTab(repository: ShellScreenEmptyOrderRepository()),
      ),
    ),
    CatalogState(
      'Error — load failed',
      (_) => _tabPreview(
        const OrdersTab(repository: ShellScreenFailingOrderRepository()),
      ),
    ),
  ],
);

final CatalogEntry _earningsTabEntry = CatalogEntry(
  feature: 'shell',
  screen: 'EarningsTab',
  states: [
    CatalogState(
      // S0-OAD-03 rule: no AuthTokenStore → fail-closed.
      'Unavailable — no active session',
      (_) => _tabPreview(const EarningsTab()),
    ),
    CatalogState(
      // The real gate resolves in one frame and never settles into a capture;
      // the seam holds it so M4's loading arm is visible at all.
      'Loading — resolving the session',
      (_) =>
          _tabPreview(EarningsTab(sessionUserId: Completer<String?>().future)),
    ),
  ],
);

final CatalogEntry _shellScreenEntry = CatalogEntry(
  feature: 'shell',
  screen: 'ShellScreen',
  states: [
    CatalogState(
      'Client landing — populated Requests + Delivery',
      (_) => ShellScreen(
        homeRepository: ShellScreenPreviewFixtures.populatedHome(),
        ordersRepository: ShellScreenPreviewFixtures.populatedOrders(),
      ),
    ),
    CatalogState(
      'Client landing — empty everywhere',
      (_) => ShellScreen(
        homeRepository: ShellScreenPreviewFixtures.emptyHome(),
        ordersRepository: const ShellScreenEmptyOrderRepository(),
      ),
    ),
  ],
);

final CatalogEntry _supportTicketEntry = CatalogEntry(
  feature: 'support',
  screen: 'SupportTicketScreen',
  states: [
    CatalogState(
      'Form — empty (nothing selected yet)',
      (_) => const SupportTicketScreen(),
    ),
    CatalogState(
      'Form — ready to submit',
      (_) => SupportTicketScreen(
        cubit: SupportTicketScreenPreviewFixtures.readyToSubmit,
      ),
    ),
    CatalogState(
      'Submitting',
      (_) => SupportTicketScreen(
        cubit: SupportTicketScreenPreviewFixtures.submitting,
      ),
    ),
    CatalogState(
      'Success — confirmation',
      (_) => SupportTicketScreen(
        cubit: SupportTicketScreenPreviewFixtures.success,
      ),
    ),
    CatalogState(
      'Error — network failure',
      (_) => SupportTicketScreen(
        cubit: SupportTicketScreenPreviewFixtures.networkError,
      ),
    ),
    CatalogState(
      'Error — unauthorized (sign-in exit, no Retry)',
      (_) => SupportTicketScreen(
        cubit: SupportTicketScreenPreviewFixtures.unauthorized,
      ),
    ),
    CatalogState(
      'Error — attachment upload failed (UX-28)',
      (_) => SupportTicketScreen(
        cubit: SupportTicketScreenPreviewFixtures.uploadFailure,
      ),
    ),
    CatalogState(
      'Error — repository unavailable (WP7-N4)',
      (_) => SupportTicketScreen(
        cubit: SupportTicketScreenPreviewFixtures.unavailableRepository,
      ),
    ),
  ],
);

final CatalogEntry _supportTicketDetailEntry = CatalogEntry(
  feature: 'support',
  screen: 'SupportTicketDetailScreen',
  states: [
    CatalogState(
      'Loading',
      (_) => SupportTicketDetailScreen(
        ticketId: SupportTicketDetailScreenFixtures.ticketId,
        repository: SupportTicketDetailScreenFixtures.loading,
      ),
    ),
    CatalogState(
      'Loaded — thread with replies',
      (_) => SupportTicketDetailScreen(
        ticketId: SupportTicketDetailScreenFixtures.ticketId,
        repository: SupportTicketDetailScreenFixtures.loaded,
      ),
    ),
    CatalogState(
      'Empty replies — nothing back yet',
      (_) => SupportTicketDetailScreen(
        ticketId: SupportTicketDetailScreenFixtures.ticketId,
        repository: SupportTicketDetailScreenFixtures.emptyReplies,
      ),
    ),
    CatalogState(
      'Closed ticket — read-only',
      (_) => SupportTicketDetailScreen(
        ticketId: SupportTicketDetailScreenFixtures.ticketId,
        repository: SupportTicketDetailScreenFixtures.closed,
      ),
    ),
    CatalogState(
      'Offline — the ONLY state allowed to say offline',
      (_) => SupportTicketDetailScreen(
        ticketId: SupportTicketDetailScreenFixtures.ticketId,
        repository: SupportTicketDetailScreenFixtures.offline,
      ),
    ),
    CatalogState(
      'Not found — exit CTA',
      (_) => SupportTicketDetailScreen(
        ticketId: SupportTicketDetailScreenFixtures.ticketId,
        repository: SupportTicketDetailScreenFixtures.notFound,
      ),
    ),
    CatalogState(
      'Refresh failed over a loaded thread',
      (_) => SupportTicketDetailScreen(
        ticketId: SupportTicketDetailScreenFixtures.ticketId,
        repository: SupportTicketDetailScreenFixtures.refreshFailure,
        cubitFactory: SupportTicketDetailScreenFixtures.refreshFailedCubit,
      ),
    ),
    CatalogState(
      'Pagination failed — footer retry (EP-14)',
      (_) => SupportTicketDetailScreen(
        ticketId: SupportTicketDetailScreenFixtures.ticketId,
        repository: SupportTicketDetailScreenFixtures.paginationFailure,
        cubitFactory: SupportTicketDetailScreenFixtures.paginationFailedCubit,
      ),
    ),
  ],
);

final CatalogEntry _tierSelectionEntry = CatalogEntry(
  feature: 'tier_selection',
  screen: 'TierSelectionScreen',
  states: [
    CatalogState(
      'Loading',
      (_) => TierSelectionScreen(
        repository: TierSelectionScreenPreviewFixtures.stalled(),
      ),
    ),
    CatalogState(
      'Loaded — delivery-service catalog, no selection',
      (_) => TierSelectionScreen(
        repository: TierSelectionScreenPreviewFixtures.servedCatalogue(),
      ),
    ),
    CatalogState(
      'Error — network unreachable',
      (_) => TierSelectionScreen(
        repository: TierSelectionScreenPreviewFixtures.failing(
          TierLoadFailure.network,
        ),
      ),
    ),
    CatalogState(
      'Error — unavailable (503)',
      (_) => TierSelectionScreen(
        repository: TierSelectionScreenPreviewFixtures.unavailable(),
      ),
    ),
    CatalogState(
      'Error — forbidden (403)',
      (_) => TierSelectionScreen(
        repository: TierSelectionScreenPreviewFixtures.forbidden(),
      ),
    ),
    CatalogState(
      'Error — offline',
      (_) => TierSelectionScreen(
        repository: TierSelectionScreenPreviewFixtures.offline(),
      ),
    ),
    CatalogState(
      'Empty — no tiers (200)',
      (_) => TierSelectionScreen(
        repository: TierSelectionScreenPreviewFixtures.emptyCatalogue(),
      ),
    ),
  ],
);

final CatalogEntry _transcriptionEntry = CatalogEntry(
  feature: 'transcription',
  screen: 'TranscriptionScreen',
  states: [
    CatalogState(
      'Ready — machine transcript to review',
      (_) => const TranscriptionScreen(
        clip: transcriptionScreenReadyClip,
        audioPlayer: NoopTranscriptAudioPlayer(),
      ),
    ),
    CatalogState(
      'Ready — Arabic transcript, language detected',
      (_) => TranscriptionScreen(
        clip: transcriptionScreenArabicClip,
        cubit: transcriptionScreenArabicCubit(),
      ),
    ),
    CatalogState(
      'Queued — no transcript yet, type instead',
      (_) => const TranscriptionScreen(
        clip: transcriptionScreenQueuedClip,
        audioPlayer: NoopTranscriptAudioPlayer(),
      ),
    ),
    CatalogState(
      'Failed — transcription call errored',
      (_) => TranscriptionScreen(
        clip: transcriptionScreenFailedClip,
        cubit: transcriptionScreenFailedCubit(),
      ),
    ),
    CatalogState(
      'Editing — text field open',
      (_) => TranscriptionScreen(
        clip: transcriptionScreenEditingClip,
        cubit: transcriptionScreenEditingCubit(),
      ),
    ),
    CatalogState(
      'Playback error — the clip would not play',
      (_) => TranscriptionScreen(
        clip: transcriptionScreenArabicClip,
        cubit: transcriptionScreenPlaybackErrorCubit(),
      ),
    ),
  ],
);

final CatalogEntry _voiceRecordingEntry = CatalogEntry(
  feature: 'voice_request',
  screen: 'VoiceRecordingScreen',
  states: [
    CatalogState(
      'Idle — ready to record',
      (_) => VoiceRecordingScreen(cubit: voiceRecordingScreenCubit()),
    ),
    // Driven ticker, not the default 100ms `Stream.periodic`: a wall-clock
    // ticker leaves a pending timer and makes the elapsed readout undrawable.
    CatalogState('Recording — press-and-hold in progress', (_) {
      final (:cubit, :ticker) = voiceRecordingScreenCubitWithTicker();
      unawaited(voiceRecordingScreenSeedRecording(cubit, ticker));
      return VoiceRecordingScreen(cubit: cubit);
    }),
    // Seeded, not driven: the async seeds stall on `StreamSubscription.cancel`
    // under fake-async, so both states used to capture the recording surface.
    CatalogState(
      'Recorded — playback preview, ready to send',
      (_) => VoiceRecordingScreen(
        cubit: voiceRecordingScreenSeededCubit(
          VoiceRecordingState(
            phase: VoiceRecordingPhase.recorded,
            clip: voiceRecordingScreenClip(),
            elapsed: const Duration(seconds: 3),
          ),
        ),
      ),
    ),
    CatalogState(
      'Sent — broadcasting confirmation',
      (_) => VoiceRecordingScreen(
        cubit: voiceRecordingScreenSeededCubit(
          const VoiceRecordingState(
            phase: VoiceRecordingPhase.sent,
            result: TranscriptionResult(id: 'catalog-voice-001'),
          ),
        ),
      ),
    ),
    CatalogState(
      'Upload failed — retry or record again',
      (_) => VoiceRecordingScreen(
        cubit: voiceRecordingScreenSeededCubit(
          VoiceRecordingState(
            phase: VoiceRecordingPhase.recorded,
            clip: voiceRecordingScreenClip(),
            error: VoiceRecordingError.uploadServer,
          ),
        ),
      ),
    ),
    CatalogState('Blocked — microphone permission denied', (_) {
      final cubit = voiceRecordingScreenCubit(
        startFailure: VoiceRecorderFailure.permissionDenied,
      );
      unawaited(cubit.startRecording());
      return VoiceRecordingScreen(cubit: cubit);
    }),
    CatalogState(
      'Upload failed — too large (413), re-record only',
      (_) => _voiceUploadFailed(VoiceRecordingError.uploadTooLarge),
    ),
    CatalogState(
      'Upload failed — unsupported format (415), re-record only',
      (_) => _voiceUploadFailed(VoiceRecordingError.uploadUnsupported),
    ),
    CatalogState(
      'Upload failed — transcription unavailable (503)',
      (_) => _voiceUploadFailed(VoiceRecordingError.uploadUnavailable),
    ),
    CatalogState(
      'Upload failed — timed out',
      (_) => _voiceUploadFailed(VoiceRecordingError.uploadTimeout),
    ),
  ],
);

/// The retained-clip upload-error surface, one rung per kind.
Widget _voiceUploadFailed(VoiceRecordingError error) => VoiceRecordingScreen(
  cubit: voiceRecordingScreenSeededCubit(
    VoiceRecordingState(
      phase: VoiceRecordingPhase.recorded,
      clip: voiceRecordingScreenClip(),
      error: error,
    ),
  ),
);

final CatalogEntry _walletHubEntry = CatalogEntry(
  feature: 'wallet',
  screen: 'WalletHubScreen',
  states: [
    CatalogState(
      'Loading',
      (_) => const WalletHubScreen(
        repository: WalletHubScreenPendingRepository(),
        kycStatusGate: WalletHubScreenKycGate.approved(),
      ),
    ),
    CatalogState(
      'Healthy — enough to bid',
      (_) => const WalletHubScreen(
        repository: WalletHubScreenFakeRepository(walletHubScreenHealthy),
        kycStatusGate: WalletHubScreenKycGate.approved(),
      ),
    ),
    CatalogState(
      'Low balance — gift credit badge shown',
      (_) => const WalletHubScreen(
        repository: WalletHubScreenFakeRepository(walletHubScreenLowWithGift),
        kycStatusGate: WalletHubScreenKycGate.approved(),
      ),
    ),
    CatalogState(
      'Empty + KYC pending banner',
      (_) => const WalletHubScreen(
        repository: WalletHubScreenFakeRepository(walletHubScreenEmpty),
        kycStatusGate: WalletHubScreenKycGate.pending(),
      ),
    ),
    CatalogState(
      'All reserved',
      (_) => const WalletHubScreen(
        repository: WalletHubScreenFakeRepository(walletHubScreenAllReserved),
        kycStatusGate: WalletHubScreenKycGate.approved(),
      ),
    ),
    CatalogState(
      'Error — load failed',
      (_) => const WalletHubScreen(
        repository: WalletHubScreenFailingRepository(),
        kycStatusGate: WalletHubScreenKycGate.approved(),
      ),
    ),
    CatalogState(
      'Degenerate body — balance unavailable (UX-16)',
      (_) => const WalletHubScreen(
        repository: WalletHubScreenDegenerateRepository(),
        kycStatusGate: WalletHubScreenKycGate.approved(),
      ),
    ),
    CatalogState(
      'Refresh failed — warm note over a live balance',
      (_) => WalletHubScreen(
        cubitFactory: walletHubRefreshFailedCubit,
        repository: WalletHubScreenRefreshFailingRepository(
          walletHubScreenHealthy,
        ),
        kycStatusGate: const WalletHubScreenKycGate.approved(),
      ),
    ),
    CatalogState(
      'Session expired — exit CTA, no inert retry',
      (_) => const WalletHubScreen(
        repository: WalletHubScreenFailingRepository(
          failure: WalletFailure.unauthorized,
        ),
        kycStatusGate: WalletHubScreenKycGate.approved(),
      ),
    ),
  ],
);

final CatalogEntry _transactionDetailEntry = CatalogEntry(
  feature: 'wallet',
  screen: 'TransactionDetailScreen',
  states: [
    CatalogState(
      'Loading',
      (_) => const TransactionDetailScreen(
        transactionId: 'txn-loading',
        repository: TransactionDetailScreenStalledRepository(),
      ),
    ),
    CatalogState(
      'Fee won — exact 10% + pinned price',
      (_) => const TransactionDetailScreen(
        transactionId: 'off-stub-1001',
        repository: TransactionDetailScreenFakeRepository(
          transactionDetailScreenFeeWonRow,
        ),
      ),
    ),
    CatalogState(
      'Fee balance adjustment — dispute link',
      (_) => const TransactionDetailScreen(
        transactionId: 'txn-refund-001',
        repository: TransactionDetailScreenFakeRepository(
          transactionDetailScreenRefundRow,
        ),
      ),
    ),
    CatalogState(
      'Error — not found',
      (_) => const TransactionDetailScreen(
        transactionId: 'txn-missing',
        repository: TransactionDetailScreenFailingRepository(
          WalletTransactionFailure.notFound,
        ),
      ),
    ),
    CatalogState(
      'Error — 404, exit CTA and never a retry',
      (_) => const TransactionDetailScreen(
        transactionId: 'txn-missing',
        repository: transactionDetailScreenNotFoundRepository,
      ),
    ),
    CatalogState(
      'Error — 500, retryable',
      (_) => const TransactionDetailScreen(
        transactionId: 'txn-500',
        repository: transactionDetailScreenServerRepository,
      ),
    ),
    CatalogState(
      'Sign-less row — the one row cannot be dropped (UX-17)',
      (_) => const TransactionDetailScreen(
        transactionId: 'txn-signless',
        repository: TransactionDetailScreenSignlessRepository(),
      ),
    ),
  ],
);

final CatalogEntry _walletActivityListEntry = CatalogEntry(
  feature: 'wallet',
  screen: 'WalletActivityListScreen',
  states: [
    CatalogState(
      'Loading',
      (_) => const WalletActivityListScreen(
        repository: WalletActivityListScreenPendingRepository(),
      ),
    ),
    CatalogState(
      'Loaded — mixed ledger rows',
      (_) => const WalletActivityListScreen(
        repository: WalletActivityListScreenFakeRepository(
          walletActivityListScreenMixedLedger,
        ),
      ),
    ),
    CatalogState(
      'Empty — no ledger rows yet',
      (_) => const WalletActivityListScreen(
        repository: EmptyWalletLedgerRepository(),
      ),
    ),
    CatalogState(
      'Error — load failed',
      (_) => const WalletActivityListScreen(
        repository: WalletActivityListScreenFakeRepository(
          <WalletLedgerEntry>[],
          failure: WalletLedgerFailure.network,
        ),
      ),
    ),
    CatalogState(
      'Unrenderable row — dropped and named',
      (_) => const WalletActivityListScreen(
        repository: WalletActivityListScreenUnrenderableRowRepository(
          walletActivityListScreenMixedLedger,
        ),
      ),
    ),
    CatalogState(
      'Load-more failed — footer retry, no scroll loop',
      (_) => const WalletActivityListScreen(
        cubitFactory: walletActivityLoadMoreFailedCubit,
        repository: WalletActivityListScreenLoadMoreFailingRepository(
          walletActivityListScreenMixedLedger,
        ),
      ),
    ),
    CatalogState(
      'Refresh failed — rows stay up',
      (_) => WalletActivityListScreen(
        cubitFactory: walletActivityRefreshFailedCubit,
        repository: WalletActivityListScreenRefreshFailingRepository(
          walletActivityListScreenMixedLedger,
        ),
      ),
    ),
  ],
);

/// Needs GoRouter wrapper: back CTA falls through to real app router without it.
final CatalogEntry _walletChargeInfoEntry = CatalogEntry(
  feature: 'wallet',
  screen: 'WalletChargeInfoScreen',
  states: [
    CatalogState(
      'Charge-at-store instructions',
      (_) => const WalletChargeInfoScreenHost(screen: WalletChargeInfoScreen()),
    ),
  ],
);

/// The customer-facing wallet surface had NO catalog state at all, so its whole
/// treatment was uncapturable. Needs the GoRouter wrapper: the chip reaches it
/// with a stack-REPLACING `goNamed`, so the exit falls back to the shell.
final CatalogEntry _customerWalletStubEntry = CatalogEntry(
  feature: 'wallet',
  screen: 'CustomerWalletStubScreen',
  states: [
    CatalogState(
      'Cash on delivery — no in-app balance',
      (_) => const CustomerWalletStubScreenPreviewHost(
        screen: CustomerWalletStubScreen(),
      ),
    ),
  ],
);
