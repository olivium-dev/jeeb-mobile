import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/network/auth_token_store.dart';
import '../../../core/notifications/application/offer_lifecycle_signals.dart';
import '../../../l10n/app_localizations.dart';
import '../../jeeber_request_feed/cubit/submitted_offers_cubit.dart';
import '../../jeeber_request_feed/cubit/submitted_offers_state.dart';
import '../../jeeber_request_feed/data/dio_submitted_offers_repository.dart';
import '../../jeeber_request_feed/domain/submitted_offer.dart';
import '../../jeeber_request_feed/domain/submitted_offers_repository.dart';
import '../../jeeber_request_feed/presentation/pending_offer_row.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/jeeber_pending_offers_screen_fixtures.dart';

/// jeeber-pending-offers (JM-047, D15) — the STANDALONE surface.
///
/// The blueprint allows the submitted-offers list as EITHER a standalone screen
/// OR the Pending-Response sub-tab of the jeeber feed (21_NAV_PLAN §A). JM-048
/// already wired the feed sub-tab (`jeeber_feed_pending_tab` → the same list),
/// so this screen REUSES that exact stack rather than duplicating it (single
/// source of truth, 40_GUARDRAILS_ARCH): [SubmittedOffersCubit] +
/// [DioSubmittedOffersRepository] (data `GET /v1/offers?jeeberId=` filtered to
/// `submitted`, withdraw `DELETE /v1/offers/:offerId`, D1) + the shared
/// [PendingOfferRow] (which carries the `pending_offer_<index>` family). The
/// integrator registered the optional `/jeeber/pending-offers` route, so the
/// list is reachable both ways and the ids stay identical.
///
/// This screen owns only the standalone CHROME: the `jeeber_pending_offers_root`
/// container, the app bar, and the `pending_offers_back` edge → delivery-requests
/// (21_NAV_PLAN §C JM-047). The rows + their Semantics ids
/// (`pending_offer_<i>` / `_price` / `_eta` / `pending_offer_awaiting_label` /
/// `_withdraw_cta`, 65_W2_TEST_PLAN §2) come from [PendingOfferRow].
///
/// Self-provides the cubit over `sl<Dio>()` because the route builder constructs
/// `const JeeberPendingOffersScreen()` with no DI param (mirrors
/// `WalletHubScreen`). The optional [repository]/[jeeberId] are constructor test
/// seams (40_GUARDRAILS_ARCH §5.4).
// ORPHAN (JEBV4-227, verified 2026-07-12): only reachable via a degenerate push-notification fallback, no in-app nav callsite — see docs/project-understanding/reconciliation/orphans.md
class JeeberPendingOffersScreen extends StatelessWidget {
  const JeeberPendingOffersScreen({super.key, this.repository, this.jeeberId});

  /// Test seam — defaults to a Dio-backed repo over the shared gateway.
  final SubmittedOffersRepository? repository;

  /// Test seam — defaults to the seeded jeeber id (`user-jeeber-002`), which is
  /// what the JM-047 seam pins (`jeeb.seam.journey=jeeber_pending_offers`) and
  /// what the Maestro flow queries (`?jeeberId=user-jeeber-002`). See
  /// 50_ROUTE_REQUESTS.md (PO-jeeberid) for the real session-user-id provider.
  final String? jeeberId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SubmittedOffersCubit>(
      create: (_) => SubmittedOffersCubit(
        repository: repository ?? _resolveRepository(),
        // sprint-009: subscribe to the offer-lifecycle bus so an
        // offer_accepted/offer_lost push flips the row + re-pulls while this
        // list is open. Absent under the route-resolution harness (no DI).
        lifecycleSignals: sl.isRegistered<OfferLifecycleSignals>()
            ? sl<OfferLifecycleSignals>().stream
            : null,
      )..load(),
      child: const _PendingOffersView(),
    );
  }

  /// Production resolves the Dio-backed repo over the shared gateway. The
  /// isolated route-resolution harness (`w2_routes_resolve_test.dart`) resets
  /// GetIt and does NOT register [Dio], so fall back to an empty repo there so
  /// the route resolves + renders (mounts to its empty-state) without that test
  /// having to be edited to seed a Dio.
  SubmittedOffersRepository _resolveRepository() {
    if (sl.isRegistered<Dio>()) {
      return DioSubmittedOffersRepository(
        dio: sl<Dio>(),
        jeeberId: jeeberId,
        tokenStore: sl.isRegistered<AuthTokenStore>()
            ? sl<AuthTokenStore>()
            : null,
      );
    }
    return const _EmptySubmittedOffersRepository();
  }
}

/// Inert repository used only when no [Dio] is registered (route-resolution
/// harness). Yields no offers and silently fails a withdraw — never hits the
/// network.
class _EmptySubmittedOffersRepository implements SubmittedOffersRepository {
  const _EmptySubmittedOffersRepository();

  @override
  Future<List<SubmittedOffer>> listSubmitted() async =>
      const <SubmittedOffer>[];

  @override
  Future<bool> withdraw(String offerId) async => false;
}

class _PendingOffersView extends StatelessWidget {
  const _PendingOffersView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'jeeber_pending_offers_root',
      container: true,
      child: Scaffold(
        appBar: OMDSAppBar(
          title: l10n.pendingOffersTitle,
          showBackButton: true,
          leading: Semantics(
            identifier: 'pending_offers_back',
            button: true,
            container: true,
            child: BackButton(
              // EDGE → delivery-requests (DELIVERY/Dashboard tab; tabs are not
              // routes — pop back to the shell-hosted feed, else go to root).
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/'),
            ),
          ),
        ),
        body: BlocBuilder<SubmittedOffersCubit, SubmittedOffersState>(
          builder: (context, state) {
            final cubit = context.read<SubmittedOffersCubit>();
            // Spinner only on the first cold load.
            if (state.status == SubmittedOffersStatus.loading &&
                state.offers.isEmpty) {
              return const OmdsLoadingState();
            }
            // Cold-load failure with nothing to show → error-state + retry.
            if (state.status == SubmittedOffersStatus.error &&
                state.offers.isEmpty) {
              return OmdsErrorState(
                message: l10n.offerSubmissionErrorGeneric,
                retryLabel: l10n.offerSubmissionRetryButton,
                onRetry: () => cubit.load(),
              );
            }
            if (state.offers.isEmpty) {
              return OmdsEmptyState(
                icon: Icons.hourglass_empty_rounded,
                title: l10n.pendingOffersEmptyTitle,
                subtitle: l10n.pendingOffersEmptyBody,
              );
            }
            return OmdsPullToRefresh(
              onRefresh: cubit.load,
              child: ListView.builder(
                padding: const EdgeInsetsDirectional.symmetric(
                  vertical: Spacing.small,
                ),
                itemCount: state.offers.length,
                itemBuilder: (_, index) {
                  final offer = state.offers[index];
                  return PendingOfferRow(
                    index: index,
                    offer: offer,
                    isWithdrawing: state.isWithdrawing(offer.id),
                    onWithdraw: () => cubit.withdraw(offer.id),
                  );
                },
              ),
            );
          },
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
// Render tests: test/previews/jeeber_pending_offers/jeeber_pending_offers_screen_preview_test.dart
// ===========================================================================
//
// [JeeberPendingOffersScreen] takes a REPOSITORY, not a state — it builds its
// own [SubmittedOffersCubit] and calls `load()` at mount — so every preview
// below hands it a local fake through the same constructor test seam the widget
// tests use, and the real cold-load path runs exactly as it does in production.
//
// The fakes and the casts are NOT declared here. They live in
// `lib/devtool/catalog/fixtures/jeeber_pending_offers_screen_fixtures.dart`,
// shared with the on-device Screen Catalog entry for this screen
// (`devtool/catalog/entries/batch_05_entries.dart`), so the designer's in-app
// browser and this canvas cannot drift into showing two different "designed
// states". None of those repositories can reach the network — they answer from
// a `const` list, throw, or never complete.
//
// Two things about this harness are worth knowing before editing it:
//
//  * **The screen owns a Scaffold and [jeebPreviewHost] supplies another.**
//    They nest: the host's `Scaffold + SafeArea` frames the card and the
//    screen's own `Scaffold + OMDSAppBar` paints inside it. That is the same
//    nesting the Screen Catalog produces.
//  * **The frame is pinned in the TREE, not just in `size:`.**
//    [_jeeberPendingOffersScreenFramed] pins the same width in the widget tree
//    so the render tests measure a phone, not the 800 pt test surface where
//    every truncation under review disappears. Height is pinned too, but the
//    render surface is 800x600, so a `SizedBox` asking for 844 is enforced down
//    to what the host has; the COMPACT box (320x568) fits and is exact.
//
// Two hazards this screen has that the previews expose rather than hide:
//
//  * **Back is not previewable.** `pending_offers_back` calls
//    `context.canPop()`, which resolves a [GoRouter] that exists above neither
//    a preview card nor a catalog state. Tapping it throws. Nothing else on the
//    screen navigates, so no other affordance is affected — Withdraw and
//    pull-to-refresh both stay inside the injected fake.
//  * **The busy row cannot be previewed statically.** `isWithdrawing` is cubit
//    state reached only by tapping Withdraw, so there is no fixture for it
//    here; [PendingOfferRow]'s own section previews that row directly
//    (`Withdraw in flight`).
//
// The states are the four the Screen Catalog names plus three it does not, and
// all three of the extras are states that break:
//
//   * **Loading.** The cold read in flight — a bare [OmdsLoadingState] spinner
//     with no copy and nothing to tap. Every jeeber sees it, and the catalog
//     has no state for it.
//   * **Longest content at 320 pt.** The layout ceiling on the narrowest phone
//     the app supports, in a zero-decimal currency.
//   * **A list long enough to scroll.** The only way to see that this screen
//     has no count, no header and no bottom affordance at all.
//
// Three things the canvas shows that no test asserted before this section
// landed, all in the screen and none of them fixed here. Every number is
// measured off the render tree through the REAL Inter and Noto Arabic faces —
// under Flutter's 1-em test face Latin measures ~2x too wide and Arabic ~2.4x,
// so widths taken there report breakages that exist on no device.
//
// * **Every non-list body is pinned to the top-left corner.**
//   `OmdsEmptyState`, `OmdsErrorState` and `OmdsLoadingState` are each a
//   `mainAxisSize: MainAxisSize.min` [Column], and `Scaffold` lays its body out
//   under LOOSE constraints and positions it at the content origin. So a body
//   that shrink-wraps is not centred in the space it was given: on a 390x600
//   frame the empty state occupies y 56..304 where centring would put it at
//   204..452, and the spinner is an 88x88 box in the TOP-LEFT corner rather
//   than the middle of the screen. `OmdsEmptyStatePage` / `OmdsErrorStatePage`
//   exist and do centre; this screen uses the un-paged variants.
// * **At 200% text on a 320 pt frame the price is the only thing that yields,
//   and the app-bar title goes with it.** `_PriceEtaRow` gives the price an
//   [Expanded] and the ETA a bare [Text], so the ETA takes its full intrinsic
//   width first: [jeeberPendingOffersScreenLongestContent] at 200% wants
//   199.9 dp of price and is given 166.8 in EN, wants 208.3 and is given 159.3
//   in AR. Both ellipsize. So does "Pending offers" in the app bar — 230.3 dp
//   wanted, 216.0 given. At 1x none of this is visible: the same price wants
//   100.8 dp of the 219.4 it is handed.
// * **The failure copy is about the wrong verb.** A failed LIST renders
//   `offerSubmissionErrorGeneric` — "Something went wrong sending your offer.
//   Please try again." Nothing was being sent; the jeeber is told their bid
//   failed to submit when the screen merely could not read the list back.
//
// What the canvas does NOT show, having been checked: nothing overflows. At
// 200% text, in both locales, on both the 390 and the 320 frame, no
// [RenderFlex] overflows and the terminal badge does not clip — "Request
// declined" measures 208.7 dp inside a pill that allows 272.

/// The phone this screen is designed against.
const Size _jeeberPendingOffersScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports — and roughly what an Android
/// multi-window split leaves a foreground app.
const Size _jeeberPendingOffersScreenCompactBox = Size(320, 568);

/// Pins [screen] to a device-sized frame inside whatever box the host gives it.
Widget _jeeberPendingOffersScreenFramed(
  Widget screen, {
  Size box = _jeeberPendingOffersScreenPhoneBox,
}) {
  return Align(
    alignment: Alignment.topCenter,
    child: SizedBox(width: box.width, height: box.height, child: screen),
  );
}

/// Builds the screen the way its route builds it — no DI, one injected
/// repository — pinned to a device frame.
///
/// [muteTicker] freezes indefinite animations. `OmdsLoadingState` renders a
/// [CircularProgressIndicator], which never stops scheduling frames, and the
/// render tests' `pumpAndSettle` would hang on it. Muting the ticker still
/// paints the arc — it just stops it spinning, which is what a static canvas
/// wanted anyway.
Widget _jeeberPendingOffersScreenHosted(
  SubmittedOffersRepository repository, {
  Size box = _jeeberPendingOffersScreenPhoneBox,
  bool muteTicker = false,
}) {
  final Widget screen = JeeberPendingOffersScreen(
    repository: repository,
    jeeberId: jeeberPendingOffersScreenJeeberId,
  );
  return _jeeberPendingOffersScreenFramed(
    muteTicker ? TickerMode(enabled: false, child: screen) : screen,
    box: box,
  );
}

/// The reference reading, and the state JM-047 AC1/AC2 assert: two offers still
/// awaiting the customer's decision.
///
/// Everything the QA flow keys off is on screen at once —
/// `pending_offer_0_price`, `_eta`, the shared `pending_offer_awaiting_label`
/// and `_withdraw_cta` — under the standalone chrome this screen owns.
///
/// This is the one the matrix is for. Each row is a [Row] of an [Expanded]
/// price beside an inflexible ETA, over a trailing-aligned Withdraw pill, and
/// the AR rendering is the mirroring check: everything is built from
/// [EdgeInsetsDirectional] and [AlignmentDirectional], so the price must move to
/// the right edge, the ETA to its left, and Withdraw to the LEFT edge. Measured
/// in AR at 390 pt it does — the price paragraph starts at x=72.5 and runs to
/// the trailing edge, while the ETA and the Withdraw pill both sit at x=16,
/// hard against the row's leading padding.
///
/// The second offer carries no ETA, so the two readings of the top line — with
/// and without the trailing slot — are visible in the same card.
@JeebPreview(
  group: 'jeeber_pending_offers',
  name: 'Awaiting decision',
  size: _jeeberPendingOffersScreenPhoneBox,
  matrix: true,
)
Widget jeeberPendingOffersScreenAwaitingDecision() =>
    _jeeberPendingOffersScreenHosted(
      const JeeberPendingOffersScreenStaticOffers(
        JeeberPendingOffersScreenOffers.awaitingDecision,
      ),
    );

/// sprint-009 offer-lifecycle: the two TERMINAL outcomes beside a still-open
/// offer.
///
/// The regression this state guards is structural — a terminal row shows an
/// outcome badge and NO Withdraw control — and it is also where the list's
/// vertical rhythm goes: measured at 390 pt a terminal row is 89 dp and an open
/// one 141 (129 against 181 at 200% text), so a mixed list has two row heights
/// 52 dp apart and no visual grouping to explain why.
///
/// Both badge strings are borrowed placeholders, which this state makes
/// visible: "Accepted" is `requestStatusAccepted`, and the lost row renders
/// `requestFeedActionDeclinedSnack` → "Request declined", a snackbar string
/// about a jeeber declining a *request*, shown to a jeeber whose *offer* the
/// customer did not pick.
@JeebPreview(
  group: 'jeeber_pending_offers',
  name: 'Mixed outcomes · accepted / not selected',
  size: _jeeberPendingOffersScreenPhoneBox,
)
Widget jeeberPendingOffersScreenMixedOutcomes() =>
    _jeeberPendingOffersScreenHosted(
      const JeeberPendingOffersScreenStaticOffers(
        JeeberPendingOffersScreenOffers.mixedOutcomes,
      ),
    );

/// A read that SUCCEEDED and came back with zero rows.
///
/// Read this next to [jeeberPendingOffersScreenLoadFailed]: a failed read
/// leaves `offers` empty too, and the view tests `status` before it tests
/// emptiness, so the ORDER of those two branches is the only thing stopping
/// this copy — a claim about server data — from being shown over a read that
/// never happened.
///
/// Note where the content sits. `OmdsEmptyState` is a `mainAxisSize.min`
/// [Column] handed straight to `Scaffold.body`, which lays its child out loose
/// and pins it to the content origin — so the illustration and copy sit hard
/// under the app bar (y 56..304 on a 390x600 frame) instead of centred in the
/// space below it (204..452). The centred variant is `OmdsEmptyStatePage`.
@JeebPreview(
  group: 'jeeber_pending_offers',
  name: 'Empty · nothing submitted',
  size: _jeeberPendingOffersScreenPhoneBox,
)
Widget jeeberPendingOffersScreenEmpty() => _jeeberPendingOffersScreenHosted(
      const JeeberPendingOffersScreenStaticOffers(
        JeeberPendingOffersScreenOffers.none,
      ),
    );

/// The cold read failed: an [OmdsErrorState] with a Retry that re-enters
/// `load()`.
///
/// The copy is `offerSubmissionErrorGeneric` — "Something went wrong sending
/// your offer. Please try again." — which is the wrong sentence for this
/// screen: nothing was being *sent*. A jeeber who fails to LIST their pending
/// offers is told their offer submission failed, which reads as "the bid I
/// placed a minute ago did not go through".
///
/// The body replaces the list entirely, which is correct here and is what makes
/// the branch order in the view load-bearing: `SubmittedOffersCubit.load`
/// downgrades a failure to `ready` whenever the list is non-empty, so this
/// surface is reachable only from an empty one.
@JeebPreview(
  group: 'jeeber_pending_offers',
  name: 'Load failed · retry',
  size: _jeeberPendingOffersScreenPhoneBox,
)
Widget jeeberPendingOffersScreenLoadFailed() =>
    _jeeberPendingOffersScreenHosted(
      const JeeberPendingOffersScreenFailingOffers(),
    );

/// The cold read in flight: an [OmdsLoadingState] spinner and nothing else.
///
/// Every jeeber sees this — `load()` is fired from `BlocProvider.create` and
/// the first frame is painted before it can return — and no state in the Screen
/// Catalog shows it. Note what is NOT on screen: no copy, no skeleton rows, and
/// nothing to tap except a back arrow that cannot be previewed. Note also WHERE
/// it is: an 88x88 box in the TOP-LEFT corner of the body, because a
/// shrink-wrapping `Scaffold.body` is positioned at the content origin rather
/// than centred.
///
/// The ticker is muted so a static canvas (and `pumpAndSettle`) has something
/// to settle on; see [_jeeberPendingOffersScreenHosted].
@JeebPreview(
  group: 'jeeber_pending_offers',
  name: 'Loading · cold read',
  size: _jeeberPendingOffersScreenPhoneBox,
)
Widget jeeberPendingOffersScreenLoading() => _jeeberPendingOffersScreenHosted(
      const JeeberPendingOffersScreenStalledOffers(),
      muteTicker: true,
    );

/// A pending list long enough to scroll.
///
/// The body is a bare `ListView.builder` under an app bar — no count, no
/// section header, no summary of what is reserved against these bids (D1), and
/// no bottom affordance. Six rows in, the only way to know how many offers are
/// outstanding is to scroll to the end, and a mixed list's ragged row heights
/// are what the scroll is made of.
@JeebPreview(
  group: 'jeeber_pending_offers',
  name: 'Long list · scrolls',
  size: _jeeberPendingOffersScreenPhoneBox,
)
Widget jeeberPendingOffersScreenLongList() => _jeeberPendingOffersScreenHosted(
      const JeeberPendingOffersScreenStaticOffers(
        JeeberPendingOffersScreenOffers.manyOffers,
      ),
    );

/// The layout ceiling on the narrowest phone the app supports.
///
/// Lebanese pricing is the real case: LBP is zero-decimal and everyday amounts
/// run to seven digits, so `NumberFormat.simpleCurrency` produces
/// "L£2,750,000" — 100.8 dp against roughly 50 for "$12.50". Beside it is a
/// multi-day ETA. The row gives the price an [Expanded] and the ETA a bare
/// `Text` with no [Flexible], so the ETA takes its intrinsic width FIRST and
/// the price ellipsizes into whatever is left.
///
/// The EN 1x reading fits with room to spare — 100.8 dp wanted, 219.4 given —
/// and hides the problem completely. The 200% rendering of the matrix is what
/// shows it: 199.9 wanted against 166.8 given in EN, 208.3 against 159.3 in AR,
/// ellipsized in both, plus an app-bar title clipped from 230.3 to 216.0. That
/// asymmetry is the point of the state; the ETA never yields a pixel.
///
/// The third row carries no ETA, so its price is handed the full 288 dp — the
/// control that shows the truncation above it is the [Expanded]/bare-[Text]
/// split and not the frame width.
@JeebPreview(
  group: 'jeeber_pending_offers',
  name: 'Longest content · compact 320',
  size: _jeeberPendingOffersScreenCompactBox,
  matrix: true,
)
Widget jeeberPendingOffersScreenLongestContent() =>
    _jeeberPendingOffersScreenHosted(
      const JeeberPendingOffersScreenStaticOffers(
        JeeberPendingOffersScreenOffers.longestContent,
      ),
      box: _jeeberPendingOffersScreenCompactBox,
    );
