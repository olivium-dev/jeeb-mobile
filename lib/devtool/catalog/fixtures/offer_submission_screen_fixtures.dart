// Designed states for `OfferSubmissionScreen` — the JM-045 structured Offer

import 'dart:async';

import '../../../features/offers/application/offer_submission_cubit.dart';
import '../../../features/offers/domain/offer_submission_repository.dart';
import '../../../features/wallet/domain/wallet_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────

/// A fake [OfferSubmissionRepository] whose single call is scripted.
/// `stalls` is spelled as a [Completer] that is never completed: it holds no
/// timer and no subscription, so a frozen `submitting` is stable for as long as
class ScriptedOfferSubmissionRepository implements OfferSubmissionRepository {
  const ScriptedOfferSubmissionRepository({
    this.stalls = false,
    this.failure,
    this.balance,
    this.offerId = 'offer-1',
    this.conversationId = 'conv-1',
  });

  /// When true, `POST /requests/{id}/offers` never answers and the cubit stays
  /// on [OfferFormMode.submitting].
  final bool stalls;

  /// When set, the call throws this typed failure instead of succeeding.
  final OfferSubmissionFailure? failure;

  /// The 402 body (O1 `{needed, available, currency}`) carried alongside a
  /// [OfferSubmissionFailure.insufficientBalance]. Null for every other
  final InsufficientBalanceInfo? balance;

  /// What a 201 answers. The gateway body carries no conversationId — the
  /// jeeber is seated on the request's conversation server-side — so the real
  final String offerId;
  final String conversationId;

  @override
  Future<OfferSubmissionResult> submitOffer({
    required String requestId,
    required double priceUsd,
    required int etaMinutes,
    String? note,
  }) {
    if (stalls) return Completer<OfferSubmissionResult>().future;
    final OfferSubmissionFailure? f = failure;
    if (f != null) {
      return Future<OfferSubmissionResult>.error(
        OfferSubmissionException(f, balance: balance),
      );
    }
    return Future<OfferSubmissionResult>.value(
      OfferSubmissionResult(offerId: offerId, conversationId: conversationId),
    );
  }
}

/// A fake [WalletRepository] for the composer's money lines (W1m).
/// `_loadWallet` swallows every failure and leaves `_wallet` null, so [failure]
/// and [stalls] both degrade the screen to the same reading — the currency
class ScriptedWalletRepository implements WalletRepository {
  const ScriptedWalletRepository({
    this.balance = OfferSubmissionScreenPreviewFixtures.wallet,
    this.stalls = false,
    this.failure,
  });

  /// What a successful `GET /v1/jeeb/wallet` answers.
  final WalletBalance balance;

  /// When true, the read never lands and `_wallet` stays null forever.
  final bool stalls;

  /// When set, the read throws it. `_loadWallet` catches EVERYTHING, so the
  /// shape is not observable — see the class doc.
  final WalletFailure? failure;

  @override
  Future<WalletBalance> fetchBalance() {
    if (stalls) return Completer<WalletBalance>().future;
    final WalletFailure? f = failure;
    if (f != null) {
      return Future<WalletBalance>.error(WalletRepositoryException(f));
    }
    return Future<WalletBalance>.value(balance);
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// The designed states of `OfferSubmissionScreen`, as collaborators plus the
/// cubit pre-drive that puts the screen in each one.
class OfferSubmissionScreenPreviewFixtures {
  const OfferSubmissionScreenPreviewFixtures._();

  /// `onWithdrawn` / `onRequestGone` stand-in. Both exits leave the composer,
  /// and no dev surface has anywhere to leave to.
  static void noop() {}

  // ── Request identifiers ───────────────────────────────────────────────────

  /// The reference request: an opaque gateway UUID, shortened to `ORD-A1B2C3`.
  static const String requestId = '0d5f4e1c-8a37-4b90-b2c6-7712dda1b2c3';

  /// The request whose offer is in flight — heading `ORD-D4E5F6`.
  static const String submittingRequestId =
      '3e6b90aa-14c7-4d02-9f81-55cc00d4e5f6';

  /// The request the jeeber failed to bid on — heading `ORD-9F8E7D`.
  static const String validationRequestId =
      '8b21c74d-90fe-4a13-8c55-2200339f8e7d';

  /// The sprint-009 §T5 identifier itself, as the gateway sends it: a bare
  /// UUID. `_displayRef` shortens it to `ORD-4C5D6E`.
  static const String opaqueRequestId =
      '9c37b6af-4e21-4e4a-9c1b-1f2a3b4c5d6e';

  /// The SAME identifier already carrying an `ORD` prefix.
  /// `_displayRef` returns anything starting with `ORD` verbatim — the
  static const String prefixedRequestId =
      'ORD-9C37B6AF-4E21-4E4A-9C1B-1F2A3B4C5D6E';

  // ── Wallet snapshots (W1m) ────────────────────────────────────────────────

  /// The reference wallet: funded, in the O1 default currency.
  static const WalletBalance wallet = WalletBalance(
    availableBalance: 25.00,
    affordabilityState: WalletAffordability.enough,
    reservedNow: 3.00,
    giftCredit: 10.00,
    currency: 'USD',
  );

  /// A wallet that cannot cover another 10% reserve (D43 `allReserved`).
  static const WalletBalance drainedWallet = WalletBalance(
    availableBalance: 3.75,
    affordabilityState: WalletAffordability.allReserved,
    reservedNow: 21.25,
    giftCredit: 0,
    currency: 'USD',
  );

  /// The funded wallet as a collaborator — what every state but the 402 uses.
  static const ScriptedWalletRepository walletRepository =
      ScriptedWalletRepository();

  // ── Repositories ──────────────────────────────────────────────────────────

  /// A submit that succeeds. Nothing reaches the success branch on a dev
  /// surface — `OfferFormMode.success` calls `context.go('/')` through a
  static const ScriptedOfferSubmissionRepository idleRepository =
      ScriptedOfferSubmissionRepository();

  /// A submit that never answers, so a pre-driven `submitting` sticks instead
  /// of racing to `success`.
  static const ScriptedOfferSubmissionRepository stalledRepository =
      ScriptedOfferSubmissionRepository(stalls: true);

  // ── 402 figures (O1 / JM-046) ─────────────────────────────────────────────

  /// The needed-vs-available pair the insufficient-balance sheet renders.
  /// 12.50 is the 10% reserve on a 125.00 offer; 3.75 is
  static const InsufficientBalanceInfo shortfall = InsufficientBalanceInfo(
    needed: 12.50,
    available: 3.75,
    currency: 'USD',
  );

  // ── Cubit pre-drives ──────────────────────────────────────────────────────

  /// A cubit frozen on [OfferFormMode.submitting].
  /// `submit()` validates synchronously and — with valid inputs — emits
  static OfferFormCubit submittingCubit({String? requestId}) =>
      OfferFormCubit(repository: stalledRepository)
        ..submit(
          requestId: requestId ?? submittingRequestId,
          priceUsd: 15.0,
          etaMinutes: 20,
        );

  /// A cubit carrying both inline validation errors.
  /// Same synchronous-completion trick: a null price and a null ETA fail
  static OfferFormCubit validationErrorCubit({String? requestId}) =>
      OfferFormCubit(repository: idleRepository)
        ..submit(
          requestId: requestId ?? validationRequestId,
          priceUsd: null,
          etaMinutes: null,
        );
}
