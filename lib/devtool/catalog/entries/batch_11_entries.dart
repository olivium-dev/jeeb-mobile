import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/session/jeeber_kyc_status_gate.dart';
import '../../../features/home_client/data/dev_client_home_fixtures.dart';
import '../../../features/home_client/data/in_memory_client_home_repository.dart';
import '../../../features/order_history/domain/order_repository.dart';
import '../../../features/order_history/domain/order_summary.dart';
import '../../../features/shell/shell_screen.dart';
import '../../../features/shell/tabs/earnings_tab.dart';
import '../../../features/shell/tabs/home_tab.dart';
import '../../../features/shell/tabs/orders_tab.dart';
import '../../../features/shell/widgets/jeeber_tab_empty_state.dart';
import '../../../features/shell/widgets/shell_header_actions.dart';
import '../../../features/support/application/support_cubit.dart';
import '../../../features/support/domain/support_repository.dart';
import '../../../features/support/presentation/support_ticket_screen.dart';
import '../../../features/tier_selection/data/tier_repository.dart';
import '../../../features/tier_selection/domain/tier.dart';
import '../../../features/tier_selection/presentation/tier_selection_screen.dart';
import '../../../features/transcription/application/transcription_cubit.dart';
import '../../../features/transcription/domain/transcript_audio_player.dart';
import '../../../features/transcription/domain/voice_clip.dart';
import '../../../features/transcription/presentation/transcription_screen.dart';
import '../../../features/voice_request/cubit/voice_recording_cubit.dart';
import '../../../features/voice_request/data/voice_recording_repository.dart';
import '../../../features/voice_request/domain/voice_player.dart';
import '../../../features/voice_request/domain/voice_recorder.dart';
import '../../../features/voice_request/presentation/voice_recording_screen.dart';
import '../../../features/wallet/data/empty_wallet_ledger_repository.dart';
import '../../../features/wallet/data/stub_wallet_transaction_repository.dart';
import '../../../features/wallet/domain/wallet_ledger_repository.dart';
import '../../../features/wallet/domain/wallet_repository.dart';
import '../../../features/wallet/domain/wallet_transaction_repository.dart';
import '../../../features/wallet/presentation/transaction_detail_screen.dart';
import '../../../features/wallet/presentation/wallet_activity_list_screen.dart';
import '../../../features/wallet/presentation/wallet_charge_info_screen.dart';
import '../../../features/wallet/presentation/wallet_hub_screen.dart';
import '../catalog_models.dart';
import '../tier_catalog_fixture.dart';

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
        OrdersTab(repository: _StaticOrderRepository(_sampleOrderPages())),
      ),
    ),
    CatalogState(
      'Empty — no orders yet',
      (_) => _tabPreview(const OrdersTab(repository: _EmptyOrderRepository())),
    ),
    CatalogState(
      'Error — load failed',
      (_) =>
          _tabPreview(const OrdersTab(repository: _FailingOrderRepository())),
    ),
  ],
);

Map<OrderHistoryTab, OrderPage> _sampleOrderPages() => {
  OrderHistoryTab.active: OrderPage(
    items: [
      OrderSummary(
        id: 'req-9001',
        createdAt: DateTime.utc(2026, 7, 1, 9, 30),
        pickupAddress: 'Hamra, Beirut',
        dropoffAddress: 'Achrafieh, Beirut',
        status: OrderRequestStatus.enRoute,
        tier: OrderTier.flash,
        amountMinor: 1500,
        currency: 'USD',
      ),
    ],
    page: 1,
    hasMore: false,
  ),
  OrderHistoryTab.completed: OrderPage(
    items: [
      OrderSummary(
        id: 'req-8890',
        createdAt: DateTime.utc(2026, 6, 20, 14, 0),
        pickupAddress: 'Verdun, Beirut',
        dropoffAddress: 'Mar Mikhael, Beirut',
        status: OrderRequestStatus.delivered,
        tier: OrderTier.standard,
        amountMinor: 900,
        currency: 'USD',
      ),
    ],
    page: 1,
    hasMore: false,
  ),
  OrderHistoryTab.cancelled: const OrderPage(
    items: [],
    page: 1,
    hasMore: false,
  ),
};

class _StaticOrderRepository implements OrderRepository {
  const _StaticOrderRepository(this._pages);

  final Map<OrderHistoryTab, OrderPage> _pages;

  @override
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  }) async {
    return _pages[tab] ?? const OrderPage(items: [], page: 1, hasMore: false);
  }
}

class _EmptyOrderRepository implements OrderRepository {
  const _EmptyOrderRepository();

  @override
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  }) async => const OrderPage(items: [], page: 1, hasMore: false);
}

class _FailingOrderRepository implements OrderRepository {
  const _FailingOrderRepository();

  @override
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  }) async {
    throw const OrderRepositoryException(OrderRepositoryErrorKind.network);
  }
}


final CatalogEntry _earningsTabEntry = CatalogEntry(
  feature: 'shell',
  screen: 'EarningsTab',
  states: [
    CatalogState(
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
        homeRepository: InMemoryClientHomeRepository.fromSnapshot(
          DevClientHomeFixtures.snapshot(),
        ),
        ordersRepository: _StaticOrderRepository(_sampleOrderPages()),
      ),
    ),
    CatalogState(
      'Client landing — empty everywhere',
      (_) => ShellScreen(
        homeRepository: InMemoryClientHomeRepository(),
        ordersRepository: const _EmptyOrderRepository(),
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
        cubit: SupportCubit(const _StubSupportRepository())
          ..setCategory(SupportCategory.delivery)
          ..setBody('My delivery never arrived and the Jeeber is unreachable.'),
      ),
    ),
    CatalogState('Submitting', (_) {
      final cubit = SupportCubit(const _PendingSupportRepository())
        ..setCategory(SupportCategory.delivery)
        ..setBody('My delivery never arrived.');
      unawaited(cubit.submit());
      return SupportTicketScreen(cubit: cubit);
    }),
    CatalogState('Success — confirmation', (_) {
      final cubit = SupportCubit(const _ImmediateSupportRepository())
        ..setCategory(SupportCategory.account)
        ..setBody('Please update my phone number on file.');
      unawaited(cubit.submit());
      return SupportTicketScreen(cubit: cubit);
    }),
    CatalogState('Error — network failure', (_) {
      final cubit =
          SupportCubit(const _FailingSupportRepository(SupportFailure.network))
            ..setCategory(SupportCategory.payment)
            ..setBody('I was charged twice for the same delivery.');
      unawaited(cubit.submit());
      return SupportTicketScreen(cubit: cubit);
    }),
  ],
);

class _StubSupportRepository implements SupportRepository {
  const _StubSupportRepository();

  @override
  Future<SupportTicket> submitTicket(SupportTicketDraft draft) async =>
      const SupportTicket(id: 'ticket-preview-001', status: 'open');
}

class _ImmediateSupportRepository implements SupportRepository {
  const _ImmediateSupportRepository();

  @override
  Future<SupportTicket> submitTicket(SupportTicketDraft draft) async =>
      const SupportTicket(id: 'ticket-preview-902', status: 'open');
}

class _PendingSupportRepository implements SupportRepository {
  const _PendingSupportRepository();

  @override
  Future<SupportTicket> submitTicket(SupportTicketDraft draft) =>
      Completer<SupportTicket>().future;
}

class _FailingSupportRepository implements SupportRepository {
  const _FailingSupportRepository(this.failure);

  final SupportFailure failure;

  @override
  Future<SupportTicket> submitTicket(SupportTicketDraft draft) async {
    throw SupportRepositoryException(failure);
  }
}


final CatalogEntry _tierSelectionEntry = CatalogEntry(
  feature: 'tier_selection',
  screen: 'TierSelectionScreen',
  states: [
    CatalogState(
      'Loading',
      (_) => const TierSelectionScreen(repository: _PendingTierRepository()),
    ),
    CatalogState(
      'Loaded — delivery-service catalog, no selection',
      (_) => const TierSelectionScreen(repository: DevtoolTierRepository()),
    ),
    CatalogState(
      'Error — network unreachable',
      (_) => const TierSelectionScreen(
        repository: DevtoolTierRepository(failWith: TierLoadFailure.network),
      ),
    ),
  ],
);

class _PendingTierRepository implements TierRepository {
  const _PendingTierRepository();

  @override
  Future<List<Tier>> fetchTiers() => Completer<List<Tier>>().future;
}


final CatalogEntry _transcriptionEntry = CatalogEntry(
  feature: 'transcription',
  screen: 'TranscriptionScreen',
  states: [
    CatalogState(
      'Ready — machine transcript to review',
      (_) => const TranscriptionScreen(
        clip: VoiceClip(
          audioPath: 'audio-ready-1',
          durationMs: 42000,
          transcript:
              'Please deliver 2 bags of rice and a water gallon to Hamra, Beirut.',
        ),
        audioPlayer: NoopTranscriptAudioPlayer(),
      ),
    ),
    CatalogState(
      'Queued — no transcript yet, type instead',
      (_) => const TranscriptionScreen(
        clip: VoiceClip(audioPath: 'audio-queued-1', durationMs: 15000),
        audioPlayer: NoopTranscriptAudioPlayer(),
      ),
    ),
    CatalogState('Failed — transcription call errored', (_) {
      const clip = VoiceClip(audioPath: 'audio-failed-1', durationMs: 20000);
      final cubit =
          TranscriptionCubit(player: const NoopTranscriptAudioPlayer())
            ..seedFromClip(clip)
            ..markFailed(TranscriptionFailure.network);
      return TranscriptionScreen(clip: clip, cubit: cubit);
    }),
    CatalogState('Editing — text field open', (_) {
      const clip = VoiceClip(
        audioPath: 'audio-edit-1',
        durationMs: 30000,
        transcript: 'Two bags of rice',
      );
      final cubit =
          TranscriptionCubit(player: const NoopTranscriptAudioPlayer())
            ..seedFromClip(clip)
            ..startEditing();
      return TranscriptionScreen(clip: clip, cubit: cubit);
    }),
  ],
);


final CatalogEntry _voiceRecordingEntry = CatalogEntry(
  feature: 'voice_request',
  screen: 'VoiceRecordingScreen',
  states: [
    CatalogState(
      'Idle — ready to record',
      (_) => VoiceRecordingScreen(cubit: _voiceCubit()),
    ),
    CatalogState('Recording — press-and-hold in progress', (_) {
      final cubit = _voiceCubit();
      unawaited(cubit.startRecording());
      return VoiceRecordingScreen(cubit: cubit);
    }),
    CatalogState('Recorded — playback preview, ready to send', (_) {
      final (:cubit, :ticker) = _voiceCubitWithTicker();
      unawaited(_seedRecorded(cubit, ticker));
      return VoiceRecordingScreen(cubit: cubit);
    }),
    CatalogState('Sent — broadcasting confirmation', (_) {
      final (:cubit, :ticker) = _voiceCubitWithTicker();
      unawaited(_seedSent(cubit, ticker));
      return VoiceRecordingScreen(cubit: cubit);
    }),
    CatalogState('Blocked — microphone permission denied', (_) {
      final cubit = _voiceCubit(
        startFailure: VoiceRecorderFailure.permissionDenied,
      );
      unawaited(cubit.startRecording());
      return VoiceRecordingScreen(cubit: cubit);
    }),
  ],
);

VoiceRecordingCubit _voiceCubit({VoiceRecorderFailure? startFailure}) {
  return VoiceRecordingCubit(
    recorder: FakeVoiceRecorder(startFailure: startFailure),
    player: FakeVoicePlayer(),
    repository: FakeVoiceRecordingRepository(),
  );
}

({VoiceRecordingCubit cubit, StreamController<Duration> ticker})
_voiceCubitWithTicker() {
  // ignore: close_sinks
  final controller = StreamController<Duration>.broadcast();
  final cubit = VoiceRecordingCubit(
    recorder: FakeVoiceRecorder(),
    player: FakeVoicePlayer(),
    repository: FakeVoiceRecordingRepository(),
    tickerFactory: (_) => controller.stream,
  );
  return (cubit: cubit, ticker: controller);
}

Future<void> _seedRecorded(
  VoiceRecordingCubit cubit,
  StreamController<Duration> ticker,
) async {
  await cubit.startRecording();
  ticker.add(const Duration(seconds: 3));
  await Future<void>.delayed(Duration.zero);
  await cubit.stopRecording();
}

Future<void> _seedSent(
  VoiceRecordingCubit cubit,
  StreamController<Duration> ticker,
) async {
  await _seedRecorded(cubit, ticker);
  await cubit.send();
}


final CatalogEntry _walletHubEntry = CatalogEntry(
  feature: 'wallet',
  screen: 'WalletHubScreen',
  states: [
    CatalogState(
      'Loading',
      (_) => const WalletHubScreen(
        repository: _PendingWalletHubRepository(),
        kycStatusGate: _StaticKycStatusGate(JeeberKycStatus.approved),
      ),
    ),
    CatalogState(
      'Healthy — enough to bid',
      (_) => const WalletHubScreen(
        repository: _StaticWalletHubRepository(
          WalletBalance(
            availableBalance: 145.0,
            affordabilityState: WalletAffordability.enough,
            reservedNow: 12.5,
            giftCredit: 0,
            currency: 'USD',
          ),
        ),
        kycStatusGate: _StaticKycStatusGate(JeeberKycStatus.approved),
      ),
    ),
    CatalogState(
      'Low balance — gift credit badge shown',
      (_) => const WalletHubScreen(
        repository: _StaticWalletHubRepository(
          WalletBalance(
            availableBalance: 8.0,
            affordabilityState: WalletAffordability.low,
            reservedNow: 5.0,
            giftCredit: 50.0,
            currency: 'USD',
          ),
        ),
        kycStatusGate: _StaticKycStatusGate(JeeberKycStatus.approved),
      ),
    ),
    CatalogState(
      'Empty + KYC pending banner',
      (_) => const WalletHubScreen(
        repository: _StaticWalletHubRepository(
          WalletBalance(
            availableBalance: 0,
            affordabilityState: WalletAffordability.empty,
            reservedNow: 0,
            giftCredit: 0,
            currency: 'USD',
          ),
        ),
        kycStatusGate: _StaticKycStatusGate(JeeberKycStatus.pending),
      ),
    ),
    CatalogState(
      'All reserved',
      (_) => const WalletHubScreen(
        repository: _StaticWalletHubRepository(
          WalletBalance(
            availableBalance: 20.0,
            affordabilityState: WalletAffordability.allReserved,
            reservedNow: 20.0,
            giftCredit: 0,
            currency: 'USD',
          ),
        ),
        kycStatusGate: _StaticKycStatusGate(JeeberKycStatus.approved),
      ),
    ),
    CatalogState(
      'Error — load failed',
      (_) => const WalletHubScreen(
        repository: _FailingWalletHubRepository(),
        kycStatusGate: _StaticKycStatusGate(JeeberKycStatus.approved),
      ),
    ),
  ],
);

class _StaticWalletHubRepository implements WalletRepository {
  const _StaticWalletHubRepository(this._balance);

  final WalletBalance _balance;

  @override
  Future<WalletBalance> fetchBalance() async => _balance;
}

class _PendingWalletHubRepository implements WalletRepository {
  const _PendingWalletHubRepository();

  @override
  Future<WalletBalance> fetchBalance() => Completer<WalletBalance>().future;
}

class _FailingWalletHubRepository implements WalletRepository {
  const _FailingWalletHubRepository();

  @override
  Future<WalletBalance> fetchBalance() async {
    throw const WalletRepositoryException(WalletFailure.network);
  }
}

class _StaticKycStatusGate implements JeeberKycStatusGate {
  const _StaticKycStatusGate(this.status);

  @override
  final JeeberKycStatus status;

  @override
  bool get isApproved => status == JeeberKycStatus.approved;
}


final CatalogEntry _transactionDetailEntry = CatalogEntry(
  feature: 'wallet',
  screen: 'TransactionDetailScreen',
  states: [
    CatalogState(
      'Loading',
      (_) => const TransactionDetailScreen(
        transactionId: 'txn-loading',
        repository: _PendingWalletTransactionRepository(),
      ),
    ),
    CatalogState(
      'Fee won — exact 10% + pinned price',
      (_) => const TransactionDetailScreen(
        transactionId: 'off-stub-1001',
        repository: StubWalletTransactionRepository(),
      ),
    ),
    CatalogState(
      'Refund — dispute link',
      (_) => const TransactionDetailScreen(
        transactionId: 'txn-refund-001',
        repository: StubWalletTransactionRepository(),
      ),
    ),
    CatalogState(
      'Error — not found',
      (_) => const TransactionDetailScreen(
        transactionId: 'txn-missing',
        repository: _FailingWalletTransactionRepository(
          WalletTransactionFailure.notFound,
        ),
      ),
    ),
  ],
);

class _PendingWalletTransactionRepository
    implements WalletTransactionRepository {
  const _PendingWalletTransactionRepository();

  @override
  Future<WalletTransaction> fetchTransaction(String id) =>
      Completer<WalletTransaction>().future;
}

class _FailingWalletTransactionRepository
    implements WalletTransactionRepository {
  const _FailingWalletTransactionRepository(this.failure);

  final WalletTransactionFailure failure;

  @override
  Future<WalletTransaction> fetchTransaction(String id) async {
    throw WalletTransactionRepositoryException(failure);
  }
}


final CatalogEntry _walletActivityListEntry = CatalogEntry(
  feature: 'wallet',
  screen: 'WalletActivityListScreen',
  states: [
    CatalogState(
      'Loading',
      (_) => const WalletActivityListScreen(
        repository: _PendingWalletLedgerRepository(),
      ),
    ),
    CatalogState(
      'Loaded — mixed ledger rows',
      (_) => const WalletActivityListScreen(
        repository: _StaticWalletLedgerRepository([
          WalletLedgerEntry(
            id: 'ldg-1',
            type: WalletLedgerType.feeWon,
            amount: 1.5,
            sign: -1,
            ref: 'off-1001',
            timestamp: '2026-07-01T09:30:00Z',
            currency: 'USD',
          ),
          WalletLedgerEntry(
            id: 'ldg-2',
            type: WalletLedgerType.topup,
            amount: 50.0,
            sign: 1,
            ref: 'topup-001',
            timestamp: '2026-06-28T12:00:00Z',
            currency: 'USD',
          ),
          WalletLedgerEntry(
            id: 'ldg-3',
            type: WalletLedgerType.gift,
            amount: 50.0,
            sign: 1,
            ref: 'gift-kyc-001',
            timestamp: '2026-06-20T08:00:00Z',
            currency: 'USD',
          ),
        ]),
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
        repository: _FailingWalletLedgerRepository(),
      ),
    ),
  ],
);

class _StaticWalletLedgerRepository implements WalletLedgerRepository {
  const _StaticWalletLedgerRepository(this._entries);

  final List<WalletLedgerEntry> _entries;

  @override
  Future<WalletLedgerPage> fetchLedger({
    int page = 1,
    int pageSize = 20,
  }) async {
    return WalletLedgerPage(entries: _entries, page: 1, totalPages: 1);
  }
}

class _PendingWalletLedgerRepository implements WalletLedgerRepository {
  const _PendingWalletLedgerRepository();

  @override
  Future<WalletLedgerPage> fetchLedger({int page = 1, int pageSize = 20}) =>
      Completer<WalletLedgerPage>().future;
}

class _FailingWalletLedgerRepository implements WalletLedgerRepository {
  const _FailingWalletLedgerRepository();

  @override
  Future<WalletLedgerPage> fetchLedger({
    int page = 1,
    int pageSize = 20,
  }) async {
    throw const WalletLedgerRepositoryException(WalletLedgerFailure.network);
  }
}


final CatalogEntry _walletChargeInfoEntry = CatalogEntry(
  feature: 'wallet',
  screen: 'WalletChargeInfoScreen',
  states: [
    CatalogState(
      'Charge-at-store instructions',
      (_) => const WalletChargeInfoScreen(),
    ),
  ],
);
