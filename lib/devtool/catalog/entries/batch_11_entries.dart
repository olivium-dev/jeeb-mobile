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

/// Batch 11 — DT-04 catalog entries for: shell, support, tier_selection,
/// transcription, voice_request, wallet.
///
/// Every builder below renders the REAL screen with a LOCAL fake/stub injected
/// through an existing (or minimally, additively widened) constructor test
/// seam — no DI, no network.
///
/// SKIPPED (see the bottom of this file for the full reasoning):
///   * `shell`'s `DashboardTab` / the jeeber-content branch of `ShellScreen` —
///     unconditionally resolves multiple `sl<...>()` service locators with no
///     override seam; the only network-free path is the internal dev-seam
///     scaffold, which is out of scope for a minimal additive change.
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

/// Wraps a bare tab body (no Scaffold of its own — it is normally hosted
/// inside the shell's Scaffold) in a minimal Scaffold so it has a Material
/// ancestor when previewed standalone in the catalog.
Widget _tabPreview(Widget child) => Scaffold(body: child);

// ─────────────────────────────────────────────────────────────────────────
// shell — JeeberTabEmptyState
// ─────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────
// shell — ShellHeaderActions
// ─────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────
// shell — HomeTab (Requests tab body)
// ─────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────
// shell — OrdersTab (Delivery tab body)
// ─────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────
// shell — EarningsTab (jeeber Earnings tab body)
// ─────────────────────────────────────────────────────────────────────────

final CatalogEntry _earningsTabEntry = CatalogEntry(
  feature: 'shell',
  screen: 'EarningsTab',
  states: [
    CatalogState(
      // No AuthTokenStore is registered in the catalog harness, so the tab's
      // fail-closed "no session id" branch is the only reachable, network-free
      // state (S0-OAD-03: never bind another user's earnings on a missing
      // session).
      'Unavailable — no active session',
      (_) => _tabPreview(const EarningsTab()),
    ),
  ],
);

// ─────────────────────────────────────────────────────────────────────────
// shell — ShellScreen (bottom-nav host)
// ─────────────────────────────────────────────────────────────────────────
//
// Uses the additive `homeRepository` / `ordersRepository` seams added to
// `ShellScreen` for this batch (see seamsAdded). No `RoleAvailabilityCubit` /
// `BadgeCountCubit` ancestor is provided — both are nullable `context.watch`
// reads that default to "no roles known yet" / "no badge", which is exactly
// the regular (non-jeeber) landing every user sees before a jeeber-role
// resolution. The jeeber-content branch (Dashboard/Earnings tabs' LIVE
// bodies) is intentionally not exercised here — see the skip note.
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

// ─────────────────────────────────────────────────────────────────────────
// support — SupportTicketScreen
// ─────────────────────────────────────────────────────────────────────────
//
// Uses the additive `cubit` seam added to `SupportTicketScreen` for this
// batch (see seamsAdded) to preview the submitting/success/error phases by
// driving a real [SupportCubit] through its public API against a local fake
// [SupportRepository] — the same idiom as the KYC wizard catalog entries
// (batch 05). `setCategory`/`setBody` are synchronous; only `submit()` is
// async, so those two states use `unawaited` + a repository whose future
// resolves immediately (success) or throws immediately (error) — no
// `Future.delayed` needed for the state transition to land before the first
// preview frame settles.

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

// ─────────────────────────────────────────────────────────────────────────
// tier_selection — TierSelectionScreen
// ─────────────────────────────────────────────────────────────────────────
//
// The screen already ships a `repository` constructor seam and calls
// `..load()` itself, so every state below is just a different [TierRepository]
// — no manual cubit driving needed.

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

// ─────────────────────────────────────────────────────────────────────────
// transcription — TranscriptionScreen
// ─────────────────────────────────────────────────────────────────────────
//
// `seedFromClip` / `markFailed` / `startEditing` are all synchronous cubit
// methods (plain `emit`, no repository round-trip), so every state below is
// seeded before the widget is returned — no `unawaited` needed.

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

// ─────────────────────────────────────────────────────────────────────────
// voice_request — VoiceRecordingScreen
// ─────────────────────────────────────────────────────────────────────────
//
// Drives the real [VoiceRecordingCubit] through its public API against the
// shipped `Fake*` recorder/player/repository (mirrors the KYC/onboarding
// seeding idiom). `startRecording`/`stopRecording`/`send` are async, so the
// "recorded"/"sent" states inject a controllable ticker stream and flush one
// microtask turn (`Future<void>.delayed(Duration.zero)`) between the tick and
// the stop so the elapsed duration clears the 1s `minSendableDuration` floor
// before the clip is finalized — otherwise the cubit treats the (still
// zero-elapsed) stop as a mis-tap and bounces back to idle.

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
  // A catalog preview's cubit/controller pair lives for the duration of that
  // preview screen only (same as every other seeded cubit in this file);
  // there is no owner to hand a dispose hook to.
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

// ─────────────────────────────────────────────────────────────────────────
// wallet — WalletHubScreen
// ─────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────
// wallet — TransactionDetailScreen
// ─────────────────────────────────────────────────────────────────────────
//
// Reuses the shipped [StubWalletTransactionRepository] for the two per-type
// "loaded" variants (its branch is keyed off the id containing "refund"/
// "penalty" vs. anything else → fee_won) and a couple of small local fakes for
// loading/error.

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

// ─────────────────────────────────────────────────────────────────────────
// wallet — WalletActivityListScreen
// ─────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────
// wallet — WalletChargeInfoScreen
// ─────────────────────────────────────────────────────────────────────────
//
// Static, no-payment instructional screen (D92/D93) — no constructor params,
// no network call by design (JM-054 AC).

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
