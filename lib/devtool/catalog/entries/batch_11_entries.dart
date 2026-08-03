import 'dart:async';

import 'package:flutter/material.dart';

import '../../../features/home_client/data/dev_client_home_fixtures.dart';
import '../../../features/home_client/data/in_memory_client_home_repository.dart';
import '../../../features/shell/shell_screen.dart';
import '../../../features/shell/tabs/earnings_tab.dart';
import '../../../features/shell/tabs/home_tab.dart';
import '../../../features/shell/tabs/orders_tab.dart';
import '../../../features/shell/widgets/jeeber_tab_empty_state.dart';
import '../../../features/shell/widgets/shell_header_actions.dart';
import '../../../features/support/presentation/support_ticket_screen.dart';
import '../../../features/tier_selection/data/tier_repository.dart';
import '../../../features/tier_selection/presentation/tier_selection_screen.dart';
import '../../../features/transcription/domain/transcript_audio_player.dart';
import '../../../features/transcription/presentation/transcription_screen.dart';
import '../../../features/voice_request/domain/voice_recorder.dart';
import '../../../features/voice_request/presentation/voice_recording_screen.dart';
import '../../../features/wallet/data/empty_wallet_ledger_repository.dart';
import '../../../features/wallet/domain/wallet_ledger_repository.dart';
import '../../../features/wallet/domain/wallet_transaction_repository.dart';
import '../../../features/wallet/presentation/transaction_detail_screen.dart';
import '../../../features/wallet/presentation/wallet_activity_list_screen.dart';
import '../../../features/wallet/presentation/wallet_charge_info_screen.dart';
import '../../../features/wallet/presentation/wallet_hub_screen.dart';
import '../catalog_models.dart';
import '../fixtures/shell_screen_fixtures.dart';
import '../fixtures/support_ticket_screen_fixtures.dart';
import '../fixtures/tier_selection_screen_fixtures.dart';
import '../fixtures/transaction_detail_screen_fixtures.dart';
import '../fixtures/transcription_screen_fixtures.dart';
import '../fixtures/voice_recording_screen_fixtures.dart';
import '../fixtures/wallet_activity_list_screen_fixtures.dart';
import '../fixtures/wallet_charge_info_screen_fixtures.dart';
import '../fixtures/wallet_hub_screen_fixtures.dart';

/// DashboardTab skipped — no override seam for sl<...>() service locators.
List<CatalogEntry> get batch11Entries => <CatalogEntry>[
  _jeeberTabEmptyStateEntry,
  _shellHeaderActionsEntry,
  _homeTabEntry,
  _ordersTabEntry,
  _earningsTabEntry,
  _shellScreenEntry,
  _supportTicketEntry,
  _tierSelectionEntry,
  _transcriptionEntry,
  _voiceRecordingEntry,
  _walletHubEntry,
  _transactionDetailEntry,
  _walletActivityListEntry,
  _walletChargeInfoEntry,
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
    CatalogState('Recorded — playback preview, ready to send', (_) {
      final (:cubit, :ticker) = voiceRecordingScreenCubitWithTicker();
      unawaited(voiceRecordingScreenSeedRecorded(cubit, ticker));
      return VoiceRecordingScreen(cubit: cubit);
    }),
    CatalogState('Sent — broadcasting confirmation', (_) {
      final (:cubit, :ticker) = voiceRecordingScreenCubitWithTicker();
      unawaited(voiceRecordingScreenSeedSent(cubit, ticker));
      return VoiceRecordingScreen(cubit: cubit);
    }),
    CatalogState('Blocked — microphone permission denied', (_) {
      final cubit = voiceRecordingScreenCubit(
        startFailure: VoiceRecorderFailure.permissionDenied,
      );
      unawaited(cubit.startRecording());
      return VoiceRecordingScreen(cubit: cubit);
    }),
  ],
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
      'Refund — dispute link',
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
  ],
);

/// Needs GoRouter wrapper: back CTA falls through to real app router without it.
final CatalogEntry _walletChargeInfoEntry = CatalogEntry(
  feature: 'wallet',
  screen: 'WalletChargeInfoScreen',
  states: [
    CatalogState(
      'Charge-at-store instructions',
      (_) => const WalletChargeInfoScreenHost(
        screen: WalletChargeInfoScreen(),
      ),
    ),
  ],
);
