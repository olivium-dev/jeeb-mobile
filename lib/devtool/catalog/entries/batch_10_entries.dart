import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../../../core/session/jeeber_kyc_status_gate.dart';
import '../../../features/tier_selection/cubit/tier_selection_cubit.dart';
import '../../../features/tier_selection/cubit/tier_selection_state.dart';
import '../../../features/tier_selection/data/tier_repository.dart';
import '../../../features/tier_selection/presentation/tier_selection_screen.dart';
import '../../../features/transcription/application/transcription_cubit.dart';
import '../../../features/transcription/domain/transcript_audio_player.dart';
import '../../../features/transcription/domain/voice_clip.dart'
    as transcript_domain;
import '../../../features/transcription/presentation/transcription_screen.dart';
import '../../../features/voice_request/cubit/voice_recording_cubit.dart';
import '../../../features/voice_request/cubit/voice_recording_state.dart';
import '../../../features/voice_request/data/voice_recording_repository.dart';
import '../../../features/voice_request/domain/voice_clip.dart';
import '../../../features/voice_request/domain/voice_player.dart';
import '../../../features/voice_request/domain/voice_recorder.dart';
import '../../../features/voice_request/presentation/voice_recording_screen.dart';
import '../../../features/wallet/data/empty_wallet_ledger_repository.dart';
import '../../../features/wallet/data/stub_wallet_repository.dart';
import '../../../features/wallet/data/stub_wallet_transaction_repository.dart';
import '../../../features/wallet/domain/wallet_ledger_repository.dart';
import '../../../features/wallet/domain/wallet_repository.dart';
import '../../../features/wallet/domain/wallet_transaction_repository.dart';
import '../../../features/wallet/presentation/transaction_detail_screen.dart';
import '../../../features/wallet/presentation/wallet_activity_list_screen.dart';
import '../../../features/wallet/presentation/wallet_charge_info_screen.dart';
import '../../../features/wallet/presentation/wallet_hub_screen.dart';
import '../catalog_models.dart';

/// Batch 10 — shell, support, tier_selection, transcription, voice_request,
/// wallet.
///
/// `shell` and `support` are DELIBERATELY NOT cataloged here (see the "SKIPPED"
/// notes just below this list) — every other entry renders the REAL screen in
/// a DESIGNED state with NO network, per the same local fake/stub pattern as
/// batch_00.
List<CatalogEntry> get batch10Entries => <CatalogEntry>[
      // ─────────────────────────────────────────────────────────────────────
      // tier_selection
      // ─────────────────────────────────────────────────────────────────────
      const CatalogEntry(
        feature: 'tier_selection',
        screen: 'TierSelectionScreen',
        states: [
          CatalogState('Loaded (Flash recommended)', _tierSelectionLoaded),
          CatalogState(
            'Cached fallback (offline)',
            _tierSelectionCachedFallback,
          ),
          CatalogState('Error', _tierSelectionError),
        ],
      ),

      // ─────────────────────────────────────────────────────────────────────
      // transcription
      // ─────────────────────────────────────────────────────────────────────
      const CatalogEntry(
        feature: 'transcription',
        screen: 'TranscriptionScreen',
        states: [
          CatalogState('Ready (machine transcript)', _transcriptionReady),
          CatalogState('Queued (no transcript yet)', _transcriptionQueued),
          CatalogState('Failed (network)', _transcriptionFailed),
        ],
      ),

      // ─────────────────────────────────────────────────────────────────────
      // voice_request
      // ─────────────────────────────────────────────────────────────────────
      const CatalogEntry(
        feature: 'voice_request',
        screen: 'VoiceRecordingScreen',
        states: [
          CatalogState('Idle (mic ready)', _voiceRecordingIdle),
          CatalogState('Recorded (preview + send)', _voiceRecordingRecorded),
          CatalogState('Sent (broadcasting)', _voiceRecordingSent),
        ],
      ),

      // ─────────────────────────────────────────────────────────────────────
      // wallet
      // ─────────────────────────────────────────────────────────────────────
      const CatalogEntry(
        feature: 'wallet',
        screen: 'WalletHubScreen',
        states: [
          CatalogState('Healthy (enough to bid + gift)', _walletHubEnough),
          CatalogState('Low balance', _walletHubLow),
          CatalogState('Empty', _walletHubEmpty),
          CatalogState(
            'All reserved + KYC pending banner',
            _walletHubAllReservedPending,
          ),
          CatalogState('Failed to load', _walletHubFailed),
        ],
      ),
      const CatalogEntry(
        feature: 'wallet',
        screen: 'WalletActivityListScreen',
        states: [
          CatalogState('Loaded (mixed ledger rows)', _walletActivityLoaded),
          CatalogState('Empty', _walletActivityEmpty),
          CatalogState('Error', _walletActivityError),
        ],
      ),
      const CatalogEntry(
        feature: 'wallet',
        screen: 'WalletChargeInfoScreen',
        states: [
          CatalogState('Charge instructions (static, no network)', _chargeInfo),
        ],
      ),
      const CatalogEntry(
        feature: 'wallet',
        screen: 'TransactionDetailScreen',
        states: [
          CatalogState('Fee-won (exact 10% + pinned price)', _txnDetailFeeWon),
          CatalogState('Refund (dispute link)', _txnDetailRefund),
          CatalogState('Error', _txnDetailError),
        ],
      ),
    ];

// SKIPPED (DoD #6 — heavy infra, no local override hook):
//
//  * `shell` (ShellScreen): aggregates HomeTab / OrdersTab / DashboardTab /
//    EarningsTab behind a `RoleCubit` (app-root-provided, not available in the
//    Dev Tool's plain-`MaterialApp` harness) plus per-tab GetIt resolution.
//    `EarningsTab` and `DashboardTab` hardcode `sl<EarningsRepository>()` /
//    `sl<JeeberKycStatusGate>()` with NO constructor override — there is no
//    local seam to swap in a fake without touching those tabs' production
//    code, so previewing the shell would hit the live gateway.
//
//  * `support` (SupportTicketScreen): its `build()` calls
//    `GoRouterState.of(context)` unconditionally to read the optional inbound
//    `extra` order ref. The Dev Tool hosts catalog previews under a bare
//    `Navigator.of(context).push(MaterialPageRoute(...))` (see
//    `devtool/catalog/catalog_screen.dart` / `devtool/devtool_shell.dart`) —
//    there is no `GoRouter` ancestor, so `GoRouterState.of` throws before the
//    screen can render. Reaching it would require standing up a real
//    `GoRouter`/`MaterialApp.router` shell just for this one preview — out of
//    scope for a local, no-network catalog entry.

// ───────────────────────────────────────────────────────────────────────────
// tier_selection
// ───────────────────────────────────────────────────────────────────────────

/// Seeds [TierSelectionState.error] directly (bypassing `load()`/the
/// repository) since the shipped cubit's `catch` branches always fall back to
/// the cached catalog rather than surfacing `TierSelectionStatus.error` — the
/// only way to preview the screen's designed error state is a subclass that
/// `emit`s it (a subclass may call the `@protected` `emit`, same as the base
/// cubit itself).
class _TierSelectionErrorCubit extends TierSelectionCubit {
  _TierSelectionErrorCubit() : super(repository: const FakeTierRepository()) {
    emit(
      state.copyWith(
        status: TierSelectionStatus.error,
        failure: TierLoadFailure.network,
      ),
    );
  }
}

Widget _tierSelectionLoaded(BuildContext _) =>
    const TierSelectionScreen(repository: FakeTierRepository());

Widget _tierSelectionCachedFallback(BuildContext _) => const TierSelectionScreen(
      repository: FakeTierRepository(failWith: TierLoadFailure.network),
    );

Widget _tierSelectionError(BuildContext _) =>
    TierSelectionScreen(cubit: _TierSelectionErrorCubit());

// ───────────────────────────────────────────────────────────────────────────
// transcription
// ───────────────────────────────────────────────────────────────────────────

const _transcriptionSampleClip = transcript_domain.VoiceClip(
  audioPath: 'devtool/sample-clip.m4a',
  durationMs: 8000,
  transcript:
      'Pick up two bags of rice from Al Fanar market and drop at Building 12, Apt 4.',
);

const _transcriptionEmptyClip = transcript_domain.VoiceClip(
  audioPath: 'devtool/sample-clip.m4a',
  durationMs: 5000,
);

Widget _transcriptionReady(BuildContext _) =>
    const TranscriptionScreen(clip: _transcriptionSampleClip);

Widget _transcriptionQueued(BuildContext _) =>
    const TranscriptionScreen(clip: _transcriptionEmptyClip);

Widget _transcriptionFailed(BuildContext _) {
  final cubit = TranscriptionCubit(player: const NoopTranscriptAudioPlayer())
    ..seedFromClip(_transcriptionEmptyClip)
    ..markFailed(TranscriptionFailure.network);
  return TranscriptionScreen(clip: _transcriptionEmptyClip, cubit: cubit);
}

// ───────────────────────────────────────────────────────────────────────────
// voice_request
// ───────────────────────────────────────────────────────────────────────────

/// Seeds a [VoiceRecordingState] directly. The real transitions
/// (`startRecording` → `stopRecording` → `send`) are all `async` and depend on
/// awaiting the injected recorder/player/repository, so they cannot be
/// cascaded synchronously the way the template's `LoginCubit` field setters
/// are (batch_00 precedent). A subclass `emit`ting the target state is the
/// local, no-network way to preview `recorded` / `sent` deterministically.
class _SeededVoiceRecordingCubit extends VoiceRecordingCubit {
  _SeededVoiceRecordingCubit(VoiceRecordingState seed)
      : super(
          recorder: FakeVoiceRecorder(),
          player: FakeVoicePlayer(),
          repository: FakeVoiceRecordingRepository(),
        ) {
    emit(seed);
  }
}

VoiceClip _voiceSampleClip() => VoiceClip(
      bytes: Uint8List.fromList(List<int>.filled(2048, 0x55)),
      duration: const Duration(seconds: 12),
    );

Widget _voiceRecordingIdle(BuildContext _) => VoiceRecordingScreen(
      cubit: VoiceRecordingCubit(
        recorder: FakeVoiceRecorder(),
        player: FakeVoicePlayer(),
        repository: FakeVoiceRecordingRepository(),
      ),
    );

Widget _voiceRecordingRecorded(BuildContext _) => VoiceRecordingScreen(
      cubit: _SeededVoiceRecordingCubit(
        VoiceRecordingState(
          phase: VoiceRecordingPhase.recorded,
          elapsed: const Duration(seconds: 12),
          clip: _voiceSampleClip(),
        ),
      ),
    );

Widget _voiceRecordingSent(BuildContext _) => VoiceRecordingScreen(
      cubit: _SeededVoiceRecordingCubit(
        VoiceRecordingState(
          phase: VoiceRecordingPhase.sent,
          elapsed: const Duration(seconds: 12),
          clip: _voiceSampleClip(),
          result: const TranscriptionResult(
            id: 'demo-clip-001',
            transcript: 'Pick up groceries from Spinneys and drop at Building 12.',
          ),
        ),
      ),
    );

// ───────────────────────────────────────────────────────────────────────────
// wallet — WalletHubScreen
// ───────────────────────────────────────────────────────────────────────────

class _FakeWalletRepository implements WalletRepository {
  const _FakeWalletRepository({this.balance, this.failure});

  final WalletBalance? balance;
  final WalletFailure? failure;

  @override
  Future<WalletBalance> fetchBalance() async {
    final f = failure;
    if (f != null) throw WalletRepositoryException(f);
    return balance ??
        const WalletBalance(
          availableBalance: 120.0,
          affordabilityState: WalletAffordability.enough,
          reservedNow: 0.0,
          giftCredit: 50.0,
          currency: 'SAR',
        );
  }
}

class _FakeKycGate implements JeeberKycStatusGate {
  const _FakeKycGate(this.status);

  @override
  final JeeberKycStatus status;

  @override
  bool get isApproved => status == JeeberKycStatus.approved;
}

Widget _walletHubEnough(BuildContext _) => const WalletHubScreen(
      repository: StubWalletRepository(),
      kycStatusGate: _FakeKycGate(JeeberKycStatus.approved),
    );

Widget _walletHubLow(BuildContext _) => const WalletHubScreen(
      repository: _FakeWalletRepository(
        balance: WalletBalance(
          availableBalance: 8.0,
          affordabilityState: WalletAffordability.low,
          reservedNow: 12.0,
          giftCredit: 0.0,
          currency: 'SAR',
        ),
      ),
      kycStatusGate: _FakeKycGate(JeeberKycStatus.approved),
    );

Widget _walletHubEmpty(BuildContext _) => const WalletHubScreen(
      repository: _FakeWalletRepository(
        balance: WalletBalance(
          availableBalance: 0.0,
          affordabilityState: WalletAffordability.empty,
          reservedNow: 0.0,
          giftCredit: 0.0,
          currency: 'SAR',
        ),
      ),
      kycStatusGate: _FakeKycGate(JeeberKycStatus.approved),
    );

Widget _walletHubAllReservedPending(BuildContext _) => const WalletHubScreen(
      repository: _FakeWalletRepository(
        balance: WalletBalance(
          availableBalance: 0.0,
          affordabilityState: WalletAffordability.allReserved,
          reservedNow: 45.0,
          giftCredit: 50.0,
          currency: 'SAR',
        ),
      ),
      kycStatusGate: _FakeKycGate(JeeberKycStatus.pending),
    );

Widget _walletHubFailed(BuildContext _) => const WalletHubScreen(
      repository: _FakeWalletRepository(failure: WalletFailure.network),
      kycStatusGate: _FakeKycGate(JeeberKycStatus.approved),
    );

// ───────────────────────────────────────────────────────────────────────────
// wallet — WalletActivityListScreen
// ───────────────────────────────────────────────────────────────────────────

class _FakeWalletLedgerRepository implements WalletLedgerRepository {
  const _FakeWalletLedgerRepository({
    this.entries = const <WalletLedgerEntry>[],
    this.failure,
  });

  final List<WalletLedgerEntry> entries;
  final WalletLedgerFailure? failure;

  @override
  Future<WalletLedgerPage> fetchLedger({
    int page = 1,
    int pageSize = 20,
  }) async {
    final f = failure;
    if (f != null) throw WalletLedgerRepositoryException(f);
    return WalletLedgerPage(entries: entries, page: 1, totalPages: 1);
  }
}

Widget _walletActivityLoaded(BuildContext _) => const WalletActivityListScreen(
      repository: _FakeWalletLedgerRepository(
        entries: [
          WalletLedgerEntry(
            id: 'ledger-001',
            type: WalletLedgerType.feeWon,
            amount: 1.5,
            sign: -1,
            ref: 'off-1001',
            timestamp: '2026-07-01T09:15:00Z',
            currency: 'SAR',
          ),
          WalletLedgerEntry(
            id: 'ledger-002',
            type: WalletLedgerType.topup,
            amount: 50.0,
            sign: 1,
            ref: 'topup-2002',
            timestamp: '2026-06-30T18:40:00Z',
            currency: 'SAR',
          ),
          WalletLedgerEntry(
            id: 'ledger-003',
            type: WalletLedgerType.refund,
            amount: 6.0,
            sign: 1,
            ref: 'dispute-3003',
            timestamp: '2026-06-29T12:00:00Z',
            currency: 'SAR',
          ),
        ],
      ),
    );

Widget _walletActivityEmpty(BuildContext _) =>
    const WalletActivityListScreen(repository: EmptyWalletLedgerRepository());

Widget _walletActivityError(BuildContext _) => const WalletActivityListScreen(
      repository: _FakeWalletLedgerRepository(
        failure: WalletLedgerFailure.network,
      ),
    );

// ───────────────────────────────────────────────────────────────────────────
// wallet — WalletChargeInfoScreen (static, no cubit/repository — JM-054 AC:
// "No network call. Mock: —").
// ───────────────────────────────────────────────────────────────────────────

Widget _chargeInfo(BuildContext _) => const WalletChargeInfoScreen();

// ───────────────────────────────────────────────────────────────────────────
// wallet — TransactionDetailScreen
// ───────────────────────────────────────────────────────────────────────────

class _FailingWalletTransactionRepository
    implements WalletTransactionRepository {
  const _FailingWalletTransactionRepository(this.failure);

  final WalletTransactionFailure failure;

  @override
  Future<WalletTransaction> fetchTransaction(String id) async {
    throw WalletTransactionRepositoryException(failure);
  }
}

Widget _txnDetailFeeWon(BuildContext _) => const TransactionDetailScreen(
      // StubWalletTransactionRepository returns its richest fee_won variant
      // (exact-10% + pinned price) for any id that doesn't mention
      // refund/penalty.
      transactionId: 'off-demo-1001',
      repository: StubWalletTransactionRepository(),
    );

Widget _txnDetailRefund(BuildContext _) => const TransactionDetailScreen(
      // StubWalletTransactionRepository special-cases ids containing
      // "refund"/"penalty" to return the dispute-linked refund variant.
      transactionId: 'txn-refund-1002',
      repository: StubWalletTransactionRepository(),
    );

Widget _txnDetailError(BuildContext _) => const TransactionDetailScreen(
      transactionId: 'txn-err-1003',
      repository: _FailingWalletTransactionRepository(
        WalletTransactionFailure.network,
      ),
    );
