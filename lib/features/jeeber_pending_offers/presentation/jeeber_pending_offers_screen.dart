import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/dev_seam/session_seam_bootstrap.dart';
import '../../../core/di/injection_container.dart';
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
/// container, the app bar, and the `pending_offers_back` edge → delivery-requests
/// (21_NAV_PLAN §C JM-047). The rows + their Semantics ids
/// (`pending_offer_<i>` / `_price` / `_eta` / `pending_offer_awaiting_label` /
/// `_withdraw_cta`, 65_W2_TEST_PLAN §2) come from [PendingOfferRow].
///
/// Self-provides the cubit over `sl<Dio>()` because the route builder constructs
/// `const JeeberPendingOffersScreen()` with no DI param (mirrors
/// `WalletHubScreen`). The optional [repository]/[jeeberId] are constructor test
/// seams (40_GUARDRAILS_ARCH §5.4).
class JeeberPendingOffersScreen extends StatelessWidget {
  const JeeberPendingOffersScreen({
    super.key,
    this.repository,
    this.jeeberId,
  });

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
        jeeberId: jeeberId ?? SessionSeamBootstrap.jeeberUserId,
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
      explicitChildNodes: true,
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
