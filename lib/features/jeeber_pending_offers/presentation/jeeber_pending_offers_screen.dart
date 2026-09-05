import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/auth_token_store.dart';
import '../../../core/notifications/application/offer_lifecycle_signals.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_failure_block.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_pull_to_refresh.dart';
import '../../../core/widgets/jeeb/jeeb_refresh_failed_note.dart';
import '../../../core/widgets/jeeb/jeeb_snack.dart';
import '../../../core/widgets/jeeb/jeeb_state_host.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../jeeber_request_feed/cubit/submitted_offers_cubit.dart';
import '../../jeeber_request_feed/cubit/submitted_offers_state.dart';
import '../../jeeber_request_feed/data/dio_submitted_offers_repository.dart';
import '../../jeeber_request_feed/domain/submitted_offer.dart';
import '../../jeeber_request_feed/domain/submitted_offers_repository.dart';
import '../../jeeber_request_feed/presentation/jeeber_failure_exit.dart';
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
/// redesign-2026-08 (w4/w5): the Material app bar became the in-body
/// [JeebTopBar] and [PendingOfferRow] took over the board's 24px gutter — one
/// gutter for all three of its host surfaces — so the list's horizontal padding
/// stays 0 here deliberately: adding one would indent the cards to 48px.
///
/// MIDNIGHT M3-36 (ORPHAN ruling KEEP+restyle). No tile: the framing is derived
/// from R10 (`client_offers_screen.dart` — field + in-body back bar + top-
/// aligned card list + centred state block) and the state family from the
/// already-shipped twin of this exact list, the R16 feed's Pending-Response
/// sub-tab (`jeeber_feed_tab_view.dart`), which is why the empty block is the
/// same `pocket` [JeebEmptyState] under the same identifier. The three OMDS
/// state widgets are gone; the field is `content` with the ratified `topEnd`
/// glow and no periwinkle wash (none is measured for this surface).
///
/// Self-provides the cubit over `sl<Dio>()` because the route builder constructs
/// `const JeeberPendingOffersScreen()` with no DI param (mirrors
/// `WalletHubScreen`). The optional [repository]/[jeeberId] are constructor test
/// seams (40_GUARDRAILS_ARCH §5.4).
// ORPHAN (JEBV4-227, verified 2026-07-12): only reachable via a degenerate push-notification fallback, no in-app nav callsite — see docs/project-understanding/reconciliation/orphans.md
class JeeberPendingOffersScreen extends StatelessWidget {
  const JeeberPendingOffersScreen({
    super.key,
    this.repository,
    this.jeeberId,
    this.cubit,
  });

  /// Test seam — defaults to a Dio-backed repo over the shared gateway.
  final SubmittedOffersRepository? repository;

  /// Test seam — defaults to the seeded jeeber id (`user-jeeber-002`), which is
  /// what the JM-047 seam pins (`jeeb.seam.journey=jeeber_pending_offers`) and
  /// what the Maestro flow queries (`?jeeberId=user-jeeber-002`). See
  /// 50_ROUTE_REQUESTS.md (PO-jeeberid) for the real session-user-id provider.
  final String? jeeberId;

  /// Preview seam for a state a cold load cannot reach (a warm refresh failure
  /// over rendered rows).
  final SubmittedOffersCubit? cubit;

  @override
  Widget build(BuildContext context) {
    final SubmittedOffersCubit? seated = cubit;
    if (seated != null) {
      return BlocProvider<SubmittedOffersCubit>.value(
        value: seated,
        child: const _PendingOffersView(),
      );
    }
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
    return submittedOffersDiFallback(releaseMode: kReleaseMode);
  }
}

/// GEN-01: a fabricated empty list must never ship as real data; the debug
/// fallback keeps `w2_routes_resolve_test` and the previews green.
SubmittedOffersRepository submittedOffersDiFallback({
  required bool releaseMode,
}) => releaseMode
    ? const _UnavailableSubmittedOffersRepository()
    : const _EmptySubmittedOffersRepository();

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

/// Release-mode fallback: with no gateway wired the screen shows its failure
/// block rather than a fabricated "no pending offers".
class _UnavailableSubmittedOffersRepository
    implements SubmittedOffersRepository {
  const _UnavailableSubmittedOffersRepository();

  @override
  Future<List<SubmittedOffer>> listSubmitted() async =>
      throw const UnknownFailure();

  @override
  Future<bool> withdraw(String offerId) async => throw const UnknownFailure();
}

class _PendingOffersView extends StatelessWidget {
  const _PendingOffersView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'jeeber_pending_offers_root',
      container: true,
      // Token sheet §8: a screen mounts the field, it does not inherit the flat
      // scaffold navy. `animateDecor: false` — the M3 no-motion default.
      child: JeebMidnightField(
        variant: JeebFieldVariant.content,
        animateDecor: false,
        child: Scaffold(
          backgroundColor: Colors.transparent,
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
                  child:
                      BlocConsumer<SubmittedOffersCubit, SubmittedOffersState>(
                        listenWhen: (prev, curr) =>
                            prev.lastEffect != curr.lastEffect &&
                            curr.lastEffect != null,
                        listener: _onWithdrawFailed,
                        builder: _buildBody,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onWithdrawFailed(BuildContext context, SubmittedOffersState state) {
    final effect = state.lastEffect!;
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<SubmittedOffersCubit>();
    showJeebErrorSnack(
      context,
      failure: effect.failure,
      message: effect.failure == null ? l10n.pendingOffersWithdrawFailed : null,
      identifier: 'pending_offers_withdraw_failed_snack',
      retryLabel: l10n.actionRetry,
      onRetry: () => unawaited(cubit.withdraw(effect.offerId)),
    );
    cubit.clearEffect();
  }

  Widget _buildBody(BuildContext context, SubmittedOffersState state) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<SubmittedOffersCubit>();
    // Illustration skeleton only on the first cold load (kit ruling 1).
    if (state.status == SubmittedOffersStatus.loading && state.offers.isEmpty) {
      return JeebStateHost(
        child: JeebEmptyState(
          status: JeebEmptyStateStatus.loading,
          variant: JeebEmptyStateVariant.pocket,
          identifier: 'pending_offers_loading',
          headline: l10n.pendingOffersLoadingHeadline,
        ),
      );
    }
    // Cold-load failure with nothing to show → the kind's block + retry.
    if (state.status == SubmittedOffersStatus.error && state.offers.isEmpty) {
      final resolved = state.error ?? const UnknownFailure();
      final exit = jeeberFailureExit(context, resolved, l10n, onReload: cubit.load);
      return JeebStateHost(
        child: JeebFailureBlock(
          failure: resolved,
          identifier: 'pending_offers_error',
          retryIdentifier: 'pending_offers_retry_cta',
          exitIdentifier: 'pending_offers_exit_cta',
          variant: JeebEmptyStateVariant.pocket,
          onRetry: () => unawaited(cubit.load()),
          onExit: exit.onExit,
          exitLabel: exit.label,
        ),
      );
    }
    final refreshError = state.refreshError;
    // LR-24: the PTR wraps the WHOLE body, so an empty list is still pullable.
    return JeebPullToRefresh(
      onRefresh: cubit.load,
      child: state.offers.isEmpty
          ? const JeebStateHost(child: _PendingOffersEmptyState())
          : Column(
              children: [
                if (refreshError != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      Spacing.xLarge,
                      Spacing.small,
                      Spacing.xLarge,
                      0,
                    ),
                    child: JeebRefreshFailedNote(
                      failure: refreshError,
                      identifier: 'pending_offers_refresh_failed_note',
                      messageOverride: l10n.errorRefreshFailedBody,
                      onDismiss: cubit.clearRefreshError,
                      onRetry: () => unawaited(cubit.load()),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    // Horizontal gutter stays 0: [PendingOfferRow] owns the
                    // board's 24px page margin itself.
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
                ),
              ],
            ),
    );
  }
}

/// The "nothing awaiting a decision" block. Copy is unchanged (D15) — a jeeber
/// sends ONE offer per request, so this stays about requests with no answer
/// yet, never "your offers on this request".
///
/// Byte-identical to the R16 feed sub-tab's block (variant, identifier and both
/// strings): one list, one empty rendering, whichever surface reaches it.
class _PendingOffersEmptyState extends StatelessWidget {
  const _PendingOffersEmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return JeebEmptyState(
      identifier: 'jeeber_pending_offers_empty_state',
      variant: JeebEmptyStateVariant.pocket,
      headline: l10n.pendingOffersEmptyTitle,
      body: l10n.pendingOffersEmptyBody,
    );
  }
}
