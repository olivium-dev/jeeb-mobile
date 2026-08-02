import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/formatting/friendly_reference.dart';
import '../../../../core/formatting/money_format.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/offer_accept_cubit.dart';
import '../../application/offer_accept_state.dart';
import '../../data/fake_offers_repository.dart';
import '../../domain/offer.dart';
import '../../domain/offers_repository.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';
import '../../domain/jeeber_vehicle.dart';

/// `offer-accept-confirm` (JM-029, D11/D71/D69) — the accept-offer confirmation
/// sheet.
///
/// The D11/D71 comprehension gate: accepting an offer is consequential — it
/// captures the fee and closes every losing offer — so it is fronted by this
/// explicit confirm step instead of firing inline from the offer card
/// (`offer-review-list`, JM-028). The sheet shows the chosen Jeeber's name, the
/// "Pay $N cash on delivery" amount (D11), and the "other offers will close"
/// note (D71), then:
///   - [offer_accept_confirm_cta] → `POST /v1/offers/:offerId/accept` (fee
///     captured + losers superseded server-side), then navigates to
///     `order-chat` (`/chat/<conversationId>`) so the pinned summary renders.
///   - [offer_accept_cancel_cta]  → dismisses, returning to `offer-review-list`.
///
/// It is a **sheet, not a route** (40_GUARDRAILS_ARCH §5 — sheets are
/// `showModalBottomSheet`, not `GoRoute`s; mirrors `SocialCollisionSheet`).
/// It owns its own async surface via [OfferAcceptCubit].
///
/// Semantics identifiers exposed (EXACT, 63_W1_TEST_PLAN §2.9):
///   - `offer_accept_sheet`              — bottom-sheet root
///   - `offer_accept_jeeber_name`        — "Accept X's offer?" / Jeeber name
///   - `offer_accept_price_label`        — "Pay $N cash on delivery" (D11)
///   - `offer_accept_other_offers_note`  — "Other offers will close" (D71)
///   - `offer_accept_confirm_cta`        — Confirm → capture fee → order-chat
///   - `offer_accept_cancel_cta`         — Cancel → back to offer-review-list
class OfferAcceptSheet extends StatelessWidget {
  const OfferAcceptSheet({
    super.key,
    required this.offer,
    required this.requestId,
    this.repository,
    this.onConfirmed,
    this.onCancelled,
    this.initialState,
  });

  /// The offer being confirmed. Supplies the Jeeber name + fee + currency the
  /// sheet renders; [Offer.id] is the offer accepted server-side.
  final Offer offer;

  /// The parent request id — paired with [Offer.id] for the accept call.
  final String requestId;

  /// Optional repository override. Production builds leave this null and
  /// resolve [OffersRepository] from DI (DioOffersRepository). Widget tests
  /// inject a scripted instance.
  final OffersRepository? repository;

  /// Fired once the accept call succeeds, with the full [OfferAcceptResult] —
  /// the server `conversationId` (order-chat target) AND the `deliveryId` of the
  /// active delivery the accept just created (used to make live tracking
  /// reachable). Either may be null when the gateway surfaces none. [show] wires
  /// the default `order-chat` navigation; an explicit callback is for tests.
  final void Function(OfferAcceptResult result)? onConfirmed;

  /// Fired when the user cancels (or the accept fails and they back out). [show]
  /// wires the default dismiss; an explicit callback is for tests.
  final VoidCallback? onCancelled;

  /// DT-04 screen-catalog / test seam: preset the cubit's initial state (e.g.
  /// `submitting` / `failed`) so the sheet can be previewed already mid-flow.
  /// Null (default, production) starts idle exactly as before.
  final OfferAcceptState? initialState;

  OffersRepository _resolveRepository() {
    final explicit = repository;
    if (explicit != null) return explicit;
    if (sl.isRegistered<OffersRepository>()) return sl<OffersRepository>();
    return FakeOffersRepository();
  }

  /// Opens the accept-confirm sheet over the current route with a dimmed scrim
  /// and the standard OMDS top-rounded sheet shape (matches
  /// `SocialCollisionSheet`). Confirm captures the fee then navigates to
  /// `order-chat`; cancel dismisses back to `offer-review-list`. Both pop the
  /// sheet FIRST so the destination's signature id (`order_chat_pinned_summary`
  /// / `offer_review_list_root`) is the only thing the Maestro flow sees.
  ///
  /// EDGE (21_NAV_PLAN §C, JM-029, D11/D71): the confirm path resolves to
  /// `chat-detail` (`/chat/:id`) — the `order-chat` blueprint surface — keyed on
  /// the [requestId], NEVER on `result.conversationId`. CHAT-CONTRACT
  /// (sprint-8f, T-APP-1): the accept response's conversationId can be a PHANTOM
  /// (`conv-for-<requestId>`) the gateway mints before the real conversation
  /// exists; routing on it lands the client in a thread the winning jeeber never
  /// joins. So we route by request id and let `ChatDetailScreen` resolve-or-
  /// create the REAL conversation by request id (the one shared by BOTH the
  /// customer and the winning jeeber). The accept response also carries the
  /// server-created `deliveryId` (the accepted offer is a real active delivery);
  /// we forward it as the `deliveryId` query param so the order-chat's "Track
  /// order" CTA (G5, `OfferAcceptedBanner`) is reachable for an offer accepted
  /// straight from the review list — the conversation phase is `accepted` on
  /// load but the chat would otherwise have no delivery id to track.
  static Future<void> show(
    BuildContext context, {
    required Offer offer,
    required String requestId,
    OffersRepository? repository,
  }) {
    final rootContext = context;
    final scrim = Theme.of(context).colorScheme.onSecondaryContainer.withValues(
      alpha: UIConstants.opacityHigh,
    );
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      barrierColor: scrim,
      // B-01: the swipe-down drag is the ONE dismissal vector the sheet's
      // PopScope(canPop:!isSubmitting) can NOT guard — `BottomSheet`'s
      // drag-to-close calls `Navigator.pop` DIRECTLY (bottom_sheet.dart
      // onClosing) rather than `maybePop`, so it bypasses the route's pop
      // disposition. Barrier-tap and system-back both route through `maybePop`
      // and ARE blocked while the accept POST is in flight; drag was the hole
      // that let the user bail mid-POST and go accept a second offer. Disable
      // drag outright (the Cancel CTA + idle barrier-tap remain the dismissal
      // path) so the accept-exactly-ONE guard holds on every vector.
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: OmdsBorderRadius.topXLarge,
      ),
      builder: (sheetContext) => OfferAcceptSheet(
        offer: offer,
        requestId: requestId,
        repository: repository,
        onConfirmed: (result) {
          Navigator.of(sheetContext).pop();
          // CHAT-CONTRACT (sprint-8f, T-APP-1): open the order-chat by the
          // REQUEST id, NEVER by `result.conversationId`. The accept response's
          // conversationId may be a PHANTOM (`conv-for-<requestId>`) the gateway
          // synthesises before the real conversation exists; trusting it routes
          // the client into a chat that is not the one the winning jeeber joins,
          // so the two participants never share a thread. `ChatDetailScreen`
          // treats the route param as the conversation's CORRELATION KEY and
          // resolve-or-creates the REAL server conversation by request id (the
          // single conversation BOTH the customer and the winning jeeber are
          // participants of, regardless of when the jeeber offered). So we hand
          // it the request id and discard the (possibly phantom) conversationId.
          final deliveryId = result.deliveryId;
          rootContext.goNamed(
            'chat-detail',
            pathParameters: {'id': requestId},
            queryParameters: {
              if (deliveryId != null && deliveryId.isNotEmpty)
                'deliveryId': deliveryId,
            },
          );
        },
        onCancelled: () => Navigator.of(sheetContext).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = _resolveRepository();
    return BlocProvider<OfferAcceptCubit>(
      create: (_) => OfferAcceptCubit(
        repository: repo,
        requestId: requestId,
        offerId: offer.id,
        initialState: initialState,
      ),
      child: _OfferAcceptView(
        offer: offer,
        onConfirmed: onConfirmed,
        onCancelled: onCancelled,
      ),
    );
  }
}

class _OfferAcceptView extends StatelessWidget {
  const _OfferAcceptView({
    required this.offer,
    this.onConfirmed,
    this.onCancelled,
  });

  final Offer offer;
  final void Function(OfferAcceptResult result)? onConfirmed;
  final VoidCallback? onCancelled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // Lane item 3 (currency unification): single MoneyFormat across surfaces.
    final feeFormatted = MoneyFormat.format(
      offer.fee,
      currency: offer.currency,
    );
    // W6/SW-08: the confirm title headlines the Jeeber's name — suppress a
    // synthetic handle / UUID the same way the offer card does, so the
    // accept-ONE moment never reads "9acb579d-…'s offer was accepted".
    final jeeberDisplayName =
        displayNameOrNull(offer.jeeberName) ?? l10n.offersCardJeeberFallback;
    return BlocConsumer<OfferAcceptCubit, OfferAcceptState>(
      listenWhen: (prev, next) =>
          prev.status != next.status &&
          next.status == OfferAcceptStatus.succeeded,
      listener: (context, state) {
        // Side effect only in the listener (never the builder) per
        // 40_GUARDRAILS_ARCH §3. Forward the full result so the navigation can
        // route to order-chat (conversationId) AND surface the tracking entry
        // (deliveryId).
        onConfirmed?.call(state.result ?? OfferAcceptResult.empty);
      },
      builder: (context, state) {
        return PopScope(
          // B-01: the accept POST is the accept-exactly-ONE moment. While it is
          // in flight the sheet must be NON-DISMISSIBLE — canPop:false blocks
          // the Android system-back gesture, the scrim tap, and the swipe-down
          // (all route pops go through the navigator's pop disposition). Without
          // this the user could dismiss mid-POST, get no success/failure signal,
          // and return to the list to fire a SECOND accept (double-accept). The
          // Confirm/Cancel CTAs are already inert while submitting; this closes
          // the remaining scrim/drag/back dismissal vectors.
          canPop: !state.isSubmitting,
          child: Semantics(
            identifier: 'offer_accept_sheet',
            // explicitChildNodes keeps each line + CTA as an independent,
            // id-addressable semantics node (matches SocialCollisionSheet) so
            // Maestro can assert/tap each one.
            explicitChildNodes: true,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  Spacing.xLarge,
                  Spacing.small,
                  Spacing.xLarge,
                  Spacing.xLarge,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SheetDragHandle(),
                    const SizedBox(height: Spacing.large),
                    // "Accept X's offer?" — the Jeeber name is the load-bearing
                    // data, and the framing is a QUESTION.
                    //
                    // This line used to reuse `chatSystemOfferAcceptedNamed`
                    // ("{name}'s offer was accepted"). That string is a CHAT
                    // SYSTEM MESSAGE, written to narrate an accept that has
                    // already happened, and borrowing it put the sheet in the
                    // past tense: the title told the customer the offer WAS
                    // accepted while the button directly below it was still
                    // asking them to confirm. On the one screen whose entire
                    // reason to exist is the D11/D71 comprehension gate, that
                    // is the worst possible copy — it reads as a report of a
                    // decision the customer has not made yet, and "Cancel"
                    // then reads as undoing something. `offerAcceptTitle` was
                    // already specified for exactly this slot in
                    // `docs/build-out/50_ROUTE_REQUESTS.md`; it is now landed
                    // in both ARBs and used here.
                    Semantics(
                      identifier: 'offer_accept_jeeber_name',
                      child: Text(
                        l10n.offerAcceptTitle(jeeberDisplayName),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.medium),
                    // "Pay $N cash on delivery" (D11). Reuses offersCardFee
                    // ("{amount} {currency}") for the amount; a dedicated
                    // `offerAcceptPayCashOnDelivery` is filed in 50_ROUTE_REQUESTS.
                    Semantics(
                      identifier: 'offer_accept_price_label',
                      child: Text(
                        l10n.offersCardFee(feeFormatted, offer.currency),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.small),
                    // "Other offers will close" (D71). Reuses chatOfferAcceptOnlyOne
                    // ("Accept only one offer"); a dedicated
                    // `offerAcceptOtherOffersClose` is filed in 50_ROUTE_REQUESTS.
                    Semantics(
                      identifier: 'offer_accept_other_offers_note',
                      child: Text(
                        l10n.chatOfferAcceptOnlyOne,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    // Inline failure copy (sprint-009 scenario matrix #7). A
                    // failed accept — e.g. the 409 race where another accept
                    // closed the auction first — MUST tell the user why; the
                    // pre-fix sheet only listened for success and a failure
                    // silently stopped the spinner. Typed [OffersFailure] →
                    // l10n copy ("This request is no longer open." for the
                    // request-level closure). Confirm stays retryable; cancel
                    // returns to the review list, which re-loads and shows the
                    // closed banner.
                    if (state.status == OfferAcceptStatus.failed &&
                        state.error != null) ...[
                      const SizedBox(height: Spacing.medium),
                      Semantics(
                        identifier: 'offer_accept_error',
                        liveRegion: true,
                        child: Container(
                          key: const Key('offer-accept-error'),
                          padding: const EdgeInsets.all(Spacing.small),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: OmdsBorderRadius.small,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: theme.colorScheme.onErrorContainer,
                              ),
                              const SizedBox(width: Spacing.small),
                              Expanded(
                                child: Text(
                                  _failureCopy(l10n, state.error!),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: Spacing.twoXLarge),
                    // CONFIRM → capture fee → order-chat. Disabled-while-submitting
                    // + spinner via the loading button; success fires the listener.
                    Semantics(
                      identifier: 'offer_accept_confirm_cta',
                      container: true,
                      button: true,
                      label: l10n.chatOfferAccept,
                      onTap: state.isSubmitting
                          ? null
                          : () => context.read<OfferAcceptCubit>().confirm(),
                      child: ExcludeSemantics(
                        child: OmdsLoadingButton(
                          key: const Key('offer-accept-confirm-cta'),
                          text: state.isSubmitting
                              ? l10n.chatOfferAccepting
                              : l10n.chatOfferAccept,
                          isLoading: state.isSubmitting,
                          onTap: () =>
                              context.read<OfferAcceptCubit>().confirm(),
                          backgroundColor: theme.colorScheme.primary,
                          textColor: theme.colorScheme.onPrimary,
                          borderRadius: OmdsBorderRadius.uiSmall,
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.small),
                    // CANCEL → back to offer-review-list. Inert while submitting
                    // so a confirmed accept can't be torn down mid-flight.
                    Semantics(
                      identifier: 'offer_accept_cancel_cta',
                      container: true,
                      button: true,
                      label: l10n.actionCancel,
                      onTap: state.isSubmitting ? null : onCancelled,
                      child: ExcludeSemantics(
                        child: OmdsPrimaryButton(
                          key: const Key('offer-accept-cancel-cta'),
                          text: l10n.actionCancel,
                          variant: OmdsButtonVariant.outlined,
                          isEnabled: !state.isSubmitting,
                          onTap: () => onCancelled?.call(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Typed accept failure → user copy. Mirrors the review-list mapping
  /// (`ClientOffersScreen._errorCopy`) so both surfaces speak identically.
  static String _failureCopy(AppLocalizations l10n, OffersFailure failure) {
    switch (failure) {
      case OffersFailure.network:
        return l10n.offersErrorNetwork;
      case OffersFailure.requestNotOpen:
        return l10n.offersErrorRequestNotOpen;
      case OffersFailure.offerNotPending:
        return l10n.offersErrorOfferNotPending;
      case OffersFailure.jeeberAtCapacity:
        return l10n.offersErrorJeeberAtCapacity;
      // Accepts are POSTs — never suppressed by the 429 back-off — so
      // rateLimited cannot reach the accept surface; fold into the generic copy
      // for switch-exhaustiveness (defensive only).
      case OffersFailure.rateLimited:
      case OffersFailure.unknown:
        return l10n.offersErrorGeneric;
    }
  }
}

/// Centered M3 drag handle (32×4 pill) tinted with the brand primary — matches
/// the shared sheet handle styling used across the app's bottom sheets.
class _SheetDragHandle extends StatelessWidget {
  const _SheetDragHandle();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        width: Spacing.twoXLarge,
        height: Spacing.twoXSmall,
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: OmdsBorderRadius.pill,
        ),
      ),
    );
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/client_offers/offer_accept_sheet_preview_test.dart
// ===========================================================================

// Widget previews for [OfferAcceptSheet] — run with
// `flutter widget-preview start`.
//
// JM-029 `offer-accept-confirm` is the D11/D71 comprehension gate: the one
// surface between "I like this bid" and an irreversible accept that captures
// the fee and closes every losing offer. Almost everything that has gone wrong
// with it went wrong in **copy and state**, not in the accept call — a
// past-tense title (SW-14), a raw `jeeb-<hash>` where a name belongs (W6/SW-08),
// and a failed accept that silently stopped the spinner and said nothing
// (sprint-009 scenario #7). Those are exactly the things you only catch by
// looking, which is what these previews are for.
//
// **Network-free by construction.** Two seams are used and neither can reach a
// gateway:
//
// * `initialState:` presets the [OfferAcceptCubit]'s state, so the submitting
//   and failed states are reached without driving `confirm()` at all.
// * `repository:` takes [_OfferAcceptSheetCannedRepository], a local fake with
//   no transport of any kind, so the Confirm button in the canvas resolves
//   against canned data instead of falling through to DI /
//   [FakeOffersRepository].
//
// Fixture data is lifted from `test/features/client_offers/offer_accept_sheet_test.dart`
// and `..._tense_test.dart` — the Kamal Hajj / `offer-001` / $6.00 offer and the
// `jeeb-e1a35ea8a520` synthetic handle — so the preview and the widget tests
// stay directly comparable.
//
// **What the matrix shows that a widget test does not.**
//
// * *EN 200% text* — **this is the one that finds something.** The sheet's
//   [Column] has no scroll fallback (same shape as
//   `ConfirmDeliveryActionSheet`), and `showModalBottomSheet(isScrollControlled:
//   true)` grants height, it does not add scrolling. Measured heights of the
//   sheet at 390 pt wide: idle **328 → 564** pt from 1.0 to 2.0 text; with the
//   BR-10 capacity banner **468 → 924** pt, i.e. a hard
//   `RenderFlex overflowed by 160 pixels` against an 844 pt phone, and by
//   **516 pt** on a 320×568 one. What overflows is the bottom of the stack: the
//   Confirm and Cancel CTAs. See the note on
//   [offerAcceptSheetFailedAtCapacity].
// * *AR RTL dark* — the fee is the one string that must NOT mirror. It is
//   wrapped in a U+2066/U+2069 LTR isolate by `MoneyFormat`, so `$6.00` has to
//   stay `$6.00` and never render as `6.00$`. The rest of the sheet mirrors on
//   its own (`EdgeInsetsDirectional` padding; the banner's [Row] takes its
//   direction from the ambient [Directionality]), and the dark palette is
//   comfortable throughout — the two roles worth a number are the fee/handle
//   `primary` on `surface` at **10.85:1** and the banner's `onErrorContainer`
//   on `errorContainer` at **7.24:1**.
//
// Measurements above come from `flutter test`, whose substituted test font is
// wider and taller than the production Inter face, so treat them as an upper
// bound on the real device — except the 320 pt overflow, which is far past any
// font-metric slack.

/// Phone width, with room for the idle stack (drag handle → title → fee → D71
/// note → two 48 pt CTAs), measured at 328 pt.
///
/// Deliberately NOT sized to fit the matrix's 200%-text rendering, unlike
/// `ConfirmDeliveryActionSheet`'s box: that rendering is 564 pt and there is no
/// phone-shaped box that would contain it *and* the error states. The stripes it
/// paints in the canvas are the widget's problem, not the canvas's.
const Size _offerAcceptSheetBox = Size(390, 400);

/// The same stack plus the inline error banner — 408 pt for the one-line
/// request-closed copy, 468 pt for the three-line BR-10 capacity copy.
const Size _offerAcceptSheetErrorBox = Size(390, 500);

/// A repository with no transport at all.
///
/// The sheet resolves its repository as "the explicit one, else the
/// DI-registered `OffersRepository`, else a `FakeOffersRepository`". Passing
/// this explicitly closes that chain: a preview must never depend on whether
/// the canvas happened to build the DI graph, and `FakeOffersRepository` —
/// while itself in-memory — is production code with a randomised seed and a
/// wall-clock drip feed, which is not what a preview fixture should be.
///
/// `fetchOffers` is never called by this sheet (the review list owns the read);
/// it is implemented only to satisfy the interface.
class _OfferAcceptSheetCannedRepository implements OffersRepository {
  const _OfferAcceptSheetCannedRepository({this.failure});

  /// When set, `acceptOffer` throws this instead of succeeding — so tapping
  /// Confirm in the canvas reaches the inline error banner for real.
  final OffersFailure? failure;

  @override
  Future<OffersSnapshot> fetchOffers(String requestId) async =>
      const OffersSnapshot(
        offers: <Offer>[],
        windowExpiresAt: null,
        requestIsOpen: true,
      );

  @override
  Future<OfferAcceptResult> acceptOffer({
    required String requestId,
    required String offerId,
  }) async {
    final OffersFailure? f = failure;
    if (f != null) throw OffersRepositoryException(f);
    return const OfferAcceptResult(
      conversationId: 'conv-preview-accepted',
      deliveryId: 'dlv-preview-001',
    );
  }
}

/// The offer under confirmation. Defaults reproduce the fixture the JM-029
/// widget tests use.
Offer _offerAcceptSheetOffer({
  String jeeberName = 'Kamal Hajj',
  double fee = 6.0,
  String currency = 'USD',
}) =>
    Offer(
      id: 'offer-001',
      jeeberId: 'user-jeeber-002',
      jeeberName: jeeberName,
      fee: fee,
      currency: currency,
      etaMinutes: 20,
      vehicle: JeeberVehicle.scooter,
      rating: 4.8,
      ratingCount: 42,
      // Fixed, never `DateTime.now()`: a preview that changes between two
      // renders is a preview you cannot diff.
      submittedAt: DateTime(2026, 6, 18, 9, 12),
    );

/// Mounts the sheet the way `showModalBottomSheet` presents it — bottom-anchored
/// content on the surface colour — without needing a [Navigator] to push onto.
///
/// Mirrors `_sheetHost` in `lib/devtool/catalog/entries/batch_02_entries.dart`
/// so the catalog and the canvas frame the same widget the same way. The sheet
/// is *content*, not a route: it renders a bare [Column] and relies on its host
/// for the scrim and the rounded top corners.
Widget _offerAcceptSheetHosted(
  Offer offer, {
  OfferAcceptState? initialState,
  OffersFailure? failure,
}) =>
    Align(
      alignment: Alignment.bottomCenter,
      child: OfferAcceptSheet(
        offer: offer,
        requestId: 'req-client-001-offers',
        repository: _OfferAcceptSheetCannedRepository(failure: failure),
        initialState: initialState,
        // No-ops on purpose. Production pops the sheet and navigates to
        // order-chat; neither belongs in a canvas.
        onConfirmed: (OfferAcceptResult _) {},
        onCancelled: () {},
      ),
    );

/// The default reading: a real Jeeber name, a small USD fee, nothing in flight.
///
/// The title must be a **question** — "Accept Kamal Hajj's offer?" — and it is
/// the SW-14 regression that makes this worth looking at rather than assuming.
/// The slot used to borrow `chatSystemOfferAcceptedNamed` ("{name}'s offer was
/// accepted"), a chat system message written to narrate an accept that had
/// already happened, so the sheet reported a decision the customer had not made
/// yet while the button below it was still asking them to make it. If this ever
/// renders past tense again, the copy has regressed.
@JeebPreview(
  group: 'client_offers',
  name: 'Idle · named Jeeber',
  size: _offerAcceptSheetBox,
)
Widget offerAcceptSheetIdle() =>
    _offerAcceptSheetHosted(_offerAcceptSheetOffer());

/// The accept POST is in flight — the B-01 accept-exactly-ONE lock, made
/// visible.
///
/// While `isSubmitting` the sheet is deliberately non-dismissible
/// (`PopScope(canPop: false)` plus `enableDrag: false` on the route) and both
/// CTAs go inert, because the hole this closed was a user bailing mid-POST and
/// going back to accept a SECOND offer.
///
/// Two things this rendering shows that no assertion in the test file does.
///
/// **The spinner is the ONLY in-flight signal, and it is silent.** `text:` is
/// set to `chatOfferAccepting` ("Accepting…" / "جاري القبول…") while submitting,
/// but `OmdsLoadingButton` renders `OmdsButtonLoading` *instead of* `text`
/// whenever `isLoading` — so that string is translated in both ARBs and never
/// appears on screen. The surrounding `Semantics` keeps `label:
/// l10n.chatOfferAccept` unconditionally and the child is `ExcludeSemantics`, so
/// a screen reader announces a plain "Accept Offer" button that does nothing:
/// the B-01 lock is visible but not audible.
///
/// **The swap must not resize the button.** It is animated, so a height change
/// across label→spinner reads as a jump. The indicator itself is `onPrimary`
/// over `primary` dimmed to 60% — 3.26:1 dark / 4.70:1 light, i.e. it clears
/// WCAG 1.4.11's 3:1 non-text floor but not by much in dark.
@JeebPreview(
  group: 'client_offers',
  name: 'Submitting · B-01 lock',
  size: _offerAcceptSheetBox,
)
Widget offerAcceptSheetSubmitting() => _offerAcceptSheetHosted(
      _offerAcceptSheetOffer(),
      initialState: const OfferAcceptState(
        status: OfferAcceptStatus.submitting,
      ),
    );

/// sprint-009 scenario #7: the accept race the customer actually loses.
///
/// Another accept closed the auction first, so the gateway answers 409
/// `request_not_open`. The pre-fix sheet only listened for success — the spinner
/// simply stopped and nothing was said — which is the single worst outcome on a
/// surface whose whole job is comprehension. The inline banner is the fix, and
/// the CTAs stay live underneath it: Confirm is retryable, Cancel returns to the
/// review list, which reloads and shows the closed banner.
@JeebPreview(
  group: 'client_offers',
  name: 'Failed · request closed (409)',
  size: _offerAcceptSheetErrorBox,
)
Widget offerAcceptSheetFailedRequestClosed() => _offerAcceptSheetHosted(
      _offerAcceptSheetOffer(),
      failure: OffersFailure.requestNotOpen,
      initialState: const OfferAcceptState(
        status: OfferAcceptStatus.failed,
        error: OffersFailure.requestNotOpen,
      ),
    );

/// BR-10 `too-many-active-deliveries`, and the longest error copy the sheet can
/// show.
///
/// This is the distinct-copy half of fix/offer-accept-409-mislabel: the winning
/// Jeeber is already at their concurrent-delivery cap, so the OFFER is still
/// pending upstream and the sheet must NOT say "this offer is no longer
/// available". It says "…Choose another offer." instead — 75 characters set next
/// to a fixed-size [Icon] in a plain [Row], and the longest string this widget
/// can be asked to lay out.
///
/// **This state is where the 200%-text rendering breaks, and the break is real.**
/// The sheet measures 468 pt at 1.0 and 924 pt at 2.0; on an 844 pt phone that
/// is `A RenderFlex overflowed by 160 pixels on the bottom` (80 in AR, whose
/// copy is shorter), and on a 320×568 phone it is 516 pixels. The [Column] has
/// no scroll fallback and `showModalBottomSheet` does not add one, so what is
/// clipped is the bottom of the stack — **both CTAs**. A customer at large text
/// who loses the accept race is shown an error they can neither retry nor
/// dismiss.
@JeebPreview(
  group: 'client_offers',
  name: 'Failed · Jeeber at capacity',
  size: _offerAcceptSheetErrorBox,
)
Widget offerAcceptSheetFailedAtCapacity() => _offerAcceptSheetHosted(
      _offerAcceptSheetOffer(),
      failure: OffersFailure.jeeberAtCapacity,
      initialState: const OfferAcceptState(
        status: OfferAcceptStatus.failed,
        error: OffersFailure.jeeberAtCapacity,
      ),
    );

/// W6/SW-08 regression guard: a phone-only Jeeber has no real name, only a
/// synthetic handle (`jeeb-<hash>`).
///
/// The title runs it through `displayNameOrNull` and falls back to
/// `offersCardJeeberFallback` — "New Jeeber" / "جِيبر جديد". If this preview ever
/// renders "Accept jeeb-e1a35ea8a520's offer?", the suppression has broken on
/// the one screen where the customer is being asked to trust a stranger with
/// their money.
@JeebPreview(
  group: 'client_offers',
  name: 'Synthetic handle suppressed',
  size: _offerAcceptSheetBox,
)
Widget offerAcceptSheetSyntheticHandle() => _offerAcceptSheetHosted(
      _offerAcceptSheetOffer(jeeberName: 'jeeb-e1a35ea8a520'),
    );

/// The content ceiling: the longest plausible name against the longest plausible
/// fee.
///
/// A six-figure LBP quote is not hypothetical — LBP is a live currency here and
/// `MoneyFormat` groups it as `LBP 4,500,000.00`, which is 17 characters set in
/// `headlineSmall` and bold. Paired with a name that wraps the title, this is
/// where the sheet is widest and tallest at once: 384 pt at 1.0 text, and
/// **836 pt at 200%** — eight pixels short of an 844 pt phone, with no error
/// banner shown. That is the margin the state above spends.
///
/// The AR RTL rendering is the load-bearing one: the fee carries a U+2066 LTR
/// isolate precisely so the amount does not reorder under RTL, and a long Latin
/// name inside an Arabic question sentence is the classic bidi-reorder case.
@JeebPreview(
  group: 'client_offers',
  name: 'Long name · LBP fee',
  size: _offerAcceptSheetErrorBox,
)
Widget offerAcceptSheetLongContent() => _offerAcceptSheetHosted(
      _offerAcceptSheetOffer(
        jeeberName: 'Abdulrahman Al-Muhandis Al-Trabulsi',
        fee: 4500000,
        currency: 'LBP',
      ),
    );
