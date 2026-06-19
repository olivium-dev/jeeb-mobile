import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../client_offers/domain/offers_repository.dart';
import '../../../client_offers/presentation/widgets/offer_accept_sheet.dart';
import '../../application/client_home_cubit.dart';
import '../../application/client_home_state.dart';
import '../../domain/client_home_request.dart';
import '../widgets/replies_card.dart';

/// JM-027 — Replies sub-tab (`my-orders`).
///
/// Renders requests where ≥1 Jeeber has replied with an offer. Each row shows
/// the stacked offerer avatars (max 3 + overflow count), an offer badge, and a
/// CTA row with two actions:
///   * `replies_check_offers_cta` → `offer-review` list (`/requests/:id/offers`,
///     JM-028). This REPLACES the old divergent `→ /chat/:id` edge the gap map
///     flagged for `my-orders` (20_GAP_MAP customer row + 21_NAV_PLAN §"185").
///   * `replies_accept_cta` → `offer-accept-confirm` sheet (`offer_accept_sheet`,
///     JM-029) [D11/D71].
///
/// Avatar images are rendered by [OmdsProfileAvatar] with network URLs to
/// benefit from the OS image cache.
///
/// WS push integration: real-time offer increments are handled by the cubit;
/// this tab rebuilds when the cubit emits a new replies list.
///
/// Mock endpoint: `GET /delivery-service/v1/requests?status=offers-received`
/// (reached via the `/v1/requests` gateway-contract path the home repository
/// already speaks; `MockGatewayClient` rewrites the prefix to :4010).
class RepliesTab extends StatelessWidget {
  const RepliesTab({super.key, this.onCheckOffers, this.onAccept});

  /// Called when `replies_check_offers_cta` is tapped. When null the tab routes
  /// to the registered `offer-review` route itself (JM-028); tests inject a
  /// callback to observe the tapped request.
  final void Function(ClientHomeRequest request)? onCheckOffers;

  /// Called when `replies_accept_cta` is tapped. When null the tab opens the
  /// `offer-accept-confirm` sheet (JM-029) via [_openAcceptConfirm]; tests
  /// inject a callback to observe the tapped request.
  final void Function(ClientHomeRequest request)? onAccept;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClientHomeCubit, ClientHomeState>(
      buildWhen: _rebuildWhen,
      builder: (context, state) => _RepliesContent(
        state: state,
        onCheckOffers: onCheckOffers ?? (r) => _openOfferReview(context, r),
        onAccept: onAccept ?? (r) => _openAcceptConfirm(context, r),
      ),
    );
  }

  static bool _rebuildWhen(ClientHomeState prev, ClientHomeState next) =>
      prev.status != next.status || prev.replies != next.replies;

  /// JM-027 AC1: Check Offers → offer-review-list (JM-028), NOT chat.
  /// Routes to the registered `offer-review` route (`/requests/:id/offers`),
  /// keyed by the request id (the seam seeds it as `req-client-001-offers`).
  static void _openOfferReview(
    BuildContext context,
    ClientHomeRequest request,
  ) {
    if (request.id.isEmpty) return;
    GoRouter.of(context).pushNamed(
      'offer-review',
      pathParameters: {'id': request.id},
    );
  }

  /// JM-027 AC2: Accept → offer-accept-confirm sheet (`offer_accept_sheet`,
  /// JM-029) [D11/D71].
  ///
  /// JM-029's `OfferAcceptSheet` (a `showModalBottomSheet`, no route —
  /// 21_NAV_PLAN §"117") has now landed, so the reply card's Accept opens it
  /// directly. The reply card only carries the [ClientHomeRequest], so we
  /// resolve the request's open offers via [OffersRepository] (the same
  /// gateway-backed read the offer-review list uses) and front the
  /// top-of-list offer on the sheet (D11/D71 comprehension gate). On any
  /// failure / no offers / no GoRouter we degrade HONESTLY to the registered
  /// `offer-review` route — where JM-028's `offer_card_<id>_accept_cta` opens
  /// the same sheet — so the nav is never a dead end.
  static Future<void> _openAcceptConfirm(
    BuildContext context,
    ClientHomeRequest request,
  ) async {
    if (request.id.isEmpty) return;
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<OffersRepository>()) {
      _openOfferReview(context, request);
      return;
    }
    final repository = getIt<OffersRepository>();
    try {
      final snapshot = await repository.fetchOffers(request.id);
      if (!context.mounted) return;
      if (snapshot.offers.isEmpty) {
        _openOfferReview(context, request);
        return;
      }
      await OfferAcceptSheet.show(
        context,
        offer: snapshot.offers.first,
        requestId: request.id,
      );
    } catch (_) {
      // Soft-fail to the honest registered destination rather than trapping
      // the user (40_GUARDRAILS_ARCH §6.7 navigation honesty).
      if (!context.mounted) return;
      _openOfferReview(context, request);
    }
  }
}

class _RepliesContent extends StatelessWidget {
  const _RepliesContent({
    required this.state,
    required this.onCheckOffers,
    required this.onAccept,
  });

  final ClientHomeState state;
  final void Function(ClientHomeRequest) onCheckOffers;
  final void Function(ClientHomeRequest) onAccept;

  @override
  Widget build(BuildContext context) {
    if (state.status == ClientHomeStatus.failed) {
      return _RepliesError(
        onRetry: () => context.read<ClientHomeCubit>().load(),
      );
    }
    if (state.status == ClientHomeStatus.loading) {
      return const _RepliesLoading();
    }
    if (state.replies.isEmpty) {
      return const _RepliesEmpty();
    }
    return _RepliesList(
      requests: state.replies,
      onCheckOffers: onCheckOffers,
      onAccept: onAccept,
    );
  }
}

class _RepliesLoading extends StatelessWidget {
  const _RepliesLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: Key('replies-loading'),
      child: OmdsLoadingState(),
    );
  }
}

class _RepliesError extends StatelessWidget {
  const _RepliesError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OmdsErrorState(
      key: const Key('replies-error'),
      icon: Icons.cloud_off_outlined,
      title: l10n.homeLoadFailedTitle,
      message: l10n.homeErrorRetry,
      retryLabel: l10n.homeLoadFailedRetry,
      onRetry: onRetry,
    );
  }
}

class _RepliesEmpty extends StatelessWidget {
  const _RepliesEmpty();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OmdsEmptyState(
      key: const Key('replies-empty'),
      icon: Icons.mark_chat_unread_outlined,
      title: l10n.homeEmptyTitle,
      subtitle: l10n.homeRepliesEmpty,
    );
  }
}

class _RepliesList extends StatelessWidget {
  const _RepliesList({
    required this.requests,
    required this.onCheckOffers,
    required this.onAccept,
  });

  final List<ClientHomeRequest> requests;
  final void Function(ClientHomeRequest) onCheckOffers;
  final void Function(ClientHomeRequest) onAccept;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('replies-tab-list'),
      children: [
        for (final r in requests)
          Semantics(
            label: _a11yLabel(context, r),
            child: RepliesCard(
              request: r,
              onCheckOffers: () => onCheckOffers(r),
              onAccept: () => onAccept(r),
            ),
          ),
      ],
    );
  }

  String _a11yLabel(BuildContext context, ClientHomeRequest r) {
    final l10n = AppLocalizations.of(context);
    return l10n.repliesTabA11yLabel(r.offerCount);
  }
}
