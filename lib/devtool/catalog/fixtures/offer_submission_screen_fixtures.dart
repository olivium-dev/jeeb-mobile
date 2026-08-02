// Designed states for `OfferSubmissionScreen` — the JM-045 structured Offer
// Composer. ONE source of truth, two consumers:
//
//   lib/devtool/catalog/entries/batch_07_entries.dart   the designer-facing,
//                                                       on-device Screen Catalog
//   lib/features/offers/presentation/offer_submission_screen.dart
//                                                       the JEEB PREVIEWS
//                                                       section at its bottom
//
// The catalog entry owned four private fixtures — `_NoopOfferRepo`,
// `_NeverCompletingOfferRepo`, `_FakeWalletRepository` and `_composerWallet` —
// plus three builders. They moved here whole when the screen got a preview
// section: two copies of the same "designed state" drift, and the catalog is
// the one a designer signs off against.
//
// The two canned repositories became ONE scripted repository per collaborator,
// because the axes are independent and the enum-of-classes could not express
// the 402. `OfferSubmissionScreen` makes exactly two collaborator calls —
// `WalletRepository.fetchBalance()` at mount and
// `OfferSubmissionRepository.submitOffer()` on the send CTA — so a designed
// state here is "what each of those two answers", plus the pre-drive in
// [OfferSubmissionScreenPreviewFixtures.submittingCubit] /
// [OfferSubmissionScreenPreviewFixtures.validationErrorCubit].
//
// ## Everything here is local
//
// Both scripted collaborators answer from a `const` value, throw a typed
// failure, or return a [Completer] that is never completed — no timer, no
// subscription, nothing a widget test reports as pending. The
// `CatalogNetworkGuard` both hosts install is a net, not the plan.
//
// ## What these fixtures CANNOT reach, and why
//
// The offer price and the note live in two `TextEditingController`s owned by
// the private `_OfferComposerState`, and the screen exposes no seam for either.
// `_price` is therefore `null` in every state that can be built without typing,
// which is every state a static fixture can build — so the whole economics
// layer (`offer_composer_fee_line`, `offer_composer_net_line`,
// `offer_composer_reserve_note`) renders its PENDING copy on every surface
// here, and the currency read off the wallet snapshot never appears at all.
// Pre-driving the cubit with a price does not change that: the cubit holds the
// submitted values, the view renders from its own controllers.
//
// [OfferSubmissionScreenPreviewFixtures.shortfall] exists for that reason. The
// JM-046 sheet takes its figures as arguments rather than off `_price`, so it
// is the one surface on this screen where real money copy can be reviewed.

import 'dart:async';

import '../../../features/offers/application/offer_submission_cubit.dart';
import '../../../features/offers/domain/offer_submission_repository.dart';
import '../../../features/wallet/domain/wallet_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Collaborators
// ─────────────────────────────────────────────────────────────────────────────

/// A fake [OfferSubmissionRepository] whose single call is scripted.
///
/// `stalls` is spelled as a [Completer] that is never completed: it holds no
/// timer and no subscription, so a frozen `submitting` is stable for as long as
/// the host is open without arming anything a widget test would report pending.
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
  /// failure, exactly as the real repository leaves it.
  final InsufficientBalanceInfo? balance;

  /// What a 201 answers. The gateway body carries no conversationId — the
  /// jeeber is seated on the request's conversation server-side — so the real
  /// repository falls back to the requestId here; these values only ever reach
  /// `onSubmitted`, which no dev surface wires.
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
///
/// `_loadWallet` swallows every failure and leaves `_wallet` null, so [failure]
/// and [stalls] both degrade the screen to the same reading — the currency
/// falls back to the O1 default `USD`. That is deliberate: it is the ONLY thing
/// a failed wallet read changes on this screen, and it is invisible until a
/// price is typed.
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
// The designed states
// ─────────────────────────────────────────────────────────────────────────────

/// The designed states of `OfferSubmissionScreen`, as collaborators plus the
/// cubit pre-drive that puts the screen in each one.
class OfferSubmissionScreenPreviewFixtures {
  const OfferSubmissionScreenPreviewFixtures._();

  /// `onWithdrawn` / `onRequestGone` stand-in. Both exits leave the composer,
  /// and no dev surface has anywhere to leave to.
  static void noop() {}

  // ── Request identifiers ───────────────────────────────────────────────────
  //
  // `_displayRef` has three branches and each one is a different heading, so
  // the id is a designed axis rather than incidental. Every state below carries
  // its own so the heading also names WHICH state is on screen — several of
  // them are otherwise byte-identical (see the file header: no price means the
  // whole economics block renders its pending copy everywhere).

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
  ///
  /// `_displayRef` returns anything starting with `ORD` verbatim — the
  /// shortening branch is never reached — so this is the raw reference §T5
  /// graded an F, rendered in full in the heading. Kept as a fixture because it
  /// is also the longest heading the screen can be asked to lay out.
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
  /// GoRouter that exists in neither the catalog nor the preview canvas — so
  /// this is the "idle composer, nothing pressed" collaborator.
  static const ScriptedOfferSubmissionRepository idleRepository =
      ScriptedOfferSubmissionRepository();

  /// A submit that never answers, so a pre-driven `submitting` sticks instead
  /// of racing to `success`.
  static const ScriptedOfferSubmissionRepository stalledRepository =
      ScriptedOfferSubmissionRepository(stalls: true);

  // ── 402 figures (O1 / JM-046) ─────────────────────────────────────────────

  /// The needed-vs-available pair the insufficient-balance sheet renders.
  ///
  /// 12.50 is the 10% reserve on a 125.00 offer; 3.75 is
  /// [drainedWallet]'s spendable balance. The gateway sends both in the 402
  /// body, and the sheet renders them verbatim — which is why they are the one
  /// place real money copy is reviewable on this screen (see the file header).
  static const InsufficientBalanceInfo shortfall = InsufficientBalanceInfo(
    needed: 12.50,
    available: 3.75,
    currency: 'USD',
  );

  // ── Cubit pre-drives ──────────────────────────────────────────────────────

  /// A cubit frozen on [OfferFormMode.submitting].
  ///
  /// `submit()` validates synchronously and — with valid inputs — emits
  /// `submitting` BEFORE its first `await` (the never-answering repository
  /// call), so the returned cubit already carries the state; no caller has to
  /// await anything.
  static OfferFormCubit submittingCubit({String? requestId}) =>
      OfferFormCubit(repository: stalledRepository)
        ..submit(
          requestId: requestId ?? submittingRequestId,
          priceUsd: 15.0,
          etaMinutes: 20,
        );

  /// A cubit carrying both inline validation errors.
  ///
  /// Same synchronous-completion trick: a null price and a null ETA fail
  /// client-side validation and `submit()` returns before any await, leaving
  /// `priceError` and `etaError` set and the mode still `idle`.
  ///
  /// The two messages are hardcoded English inside `OfferFormCubit`
  /// (`_validatePrice` / `_validateEta`), so this state renders them in English
  /// under an Arabic locale too — which the AR rendering of the preview shows.
  static OfferFormCubit validationErrorCubit({String? requestId}) =>
      OfferFormCubit(repository: idleRepository)
        ..submit(
          requestId: requestId ?? validationRequestId,
          priceUsd: null,
          etaMinutes: null,
        );
}
