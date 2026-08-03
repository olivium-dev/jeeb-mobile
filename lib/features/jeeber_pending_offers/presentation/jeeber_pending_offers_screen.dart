import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/network/auth_token_store.dart';
import '../../../core/notifications/application/offer_lifecycle_signals.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../jeeber_request_feed/cubit/submitted_offers_cubit.dart';
import '../../jeeber_request_feed/cubit/submitted_offers_state.dart';
import '../../jeeber_request_feed/data/dio_submitted_offers_repository.dart';
import '../../jeeber_request_feed/domain/submitted_offer.dart';
import '../../jeeber_request_feed/domain/submitted_offers_repository.dart';
import '../../jeeber_request_feed/presentation/pending_offer_row.dart';

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
/// container, the header, and the `pending_offers_back` edge → delivery-requests
/// (21_NAV_PLAN §C JM-047). The rows + their Semantics ids
/// (`pending_offer_<i>` / `_price` / `_eta` / `pending_offer_awaiting_label` /
/// `_withdraw_cta`, 65_W2_TEST_PLAN §2) come from [PendingOfferRow].
///
/// redesign-2026-08 (w4): re-skinned onto the Jeeb kit as far as this lane's
/// ownership reaches — the Material app bar became the in-body [JeebTopBar]
/// (`back` circle + `jeebText.h2` title, board padding `14/24/0`), the list
/// picked up the board's vertical rhythm, and the empty state is top-aligned
/// (R1: the residual space stays white, never vertically centred).
/// [PendingOfferRow] itself lives in `jeeber_request_feed/` and is shared with
/// the feed's Pending-Response sub-tab and the shell dashboard's copy of it.
/// **w5 landed its card/type treatment** (the `w4-jeeber-pending-offers.md` R1
/// request), and the row now owns the board's 24px gutter itself — one gutter
/// for all three surfaces — so the list's horizontal padding stays 0 here
/// deliberately: adding one would indent the cards to 48px.
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
        // No `Scaffold.appBar`: the board's header is a body row (§5 #1), so
        // the bar scrolls with the same 24px gutter as everything under it.
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              JeebTopBar.back(
                title: l10n.pendingOffersTitle,
                // FROZEN id — the kit lands it on the leading circle with the
                // same `button: true, container: true` node the hand-rolled
                // BackButton wrapper carried.
                identifier: 'pending_offers_back',
                // EDGE → delivery-requests (DELIVERY/Dashboard tab; tabs are
                // not routes — pop back to the shell-hosted feed, else go to
                // root). The kit never imports go_router, so the fallback
                // stays here.
                onLeadingPressed: () =>
                    context.canPop() ? context.pop() : context.go('/'),
              ),
              Expanded(
                child: BlocBuilder<SubmittedOffersCubit, SubmittedOffersState>(
                  builder: _buildBody,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, SubmittedOffersState state) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<SubmittedOffersCubit>();
    // Spinner only on the first cold load.
    if (state.status == SubmittedOffersStatus.loading && state.offers.isEmpty) {
      return const OmdsLoadingState();
    }
    // Cold-load failure with nothing to show → error-state + retry.
    if (state.status == SubmittedOffersStatus.error && state.offers.isEmpty) {
      return OmdsErrorState(
        message: l10n.offerSubmissionErrorGeneric,
        retryLabel: l10n.offerSubmissionRetryButton,
        onRetry: () => cubit.load(),
      );
    }
    if (state.offers.isEmpty) {
      // R1: the residual space below stays white and the copy sits under the
      // header — never vertically centred. Scrollable so the block survives a
      // large text scale on a short viewport.
      return const SingleChildScrollView(
        padding: EdgeInsetsDirectional.only(top: Spacing.twoXLarge),
        child: _PendingOffersEmptyState(),
      );
    }
    return OmdsPullToRefresh(
      onRefresh: cubit.load,
      child: ListView.builder(
        // Horizontal gutter stays 0: [PendingOfferRow] owns the board's 24px
        // page margin itself (see the class docs) so all three of its host
        // surfaces line up — the vertical rhythm is this lane's.
        padding: const EdgeInsetsDirectional.only(
          top: Spacing.medium,
          bottom: Spacing.xLarge,
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
  }
}

/// The "nothing awaiting a decision" block. Copy is unchanged (D15) — a jeeber
/// sends ONE offer per request, so this stays about requests with no answer
/// yet, never "your offers on this request".
class _PendingOffersEmptyState extends StatelessWidget {
  const _PendingOffersEmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OmdsEmptyState(
      icon: Icons.hourglass_empty_rounded,
      title: l10n.pendingOffersEmptyTitle,
      subtitle: l10n.pendingOffersEmptyBody,
    );
  }
}
