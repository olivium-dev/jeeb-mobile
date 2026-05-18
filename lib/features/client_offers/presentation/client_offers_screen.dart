import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../application/client_offers_cubit.dart';
import '../application/client_offers_state.dart';
import '../domain/offers_repository.dart';
import 'widgets/offer_card.dart';
import 'widgets/offer_sort_bar.dart';
import 'widgets/offer_window_timer.dart';

/// Signature for the optional cubit factory the screen exposes for tests.
/// Production wiring leaves it `null` so the default ticker-driven cubit is
/// used; tests pass a factory that injects empty `pollTicks` / `clockTicks`
/// so the test binding doesn't complain about pending timers.
typedef ClientOffersCubitFactory = ClientOffersCubit Function(
  OffersRepository repository,
  String requestId,
);

/// Client view of the offer cards screen.
///
/// Renders the offer window countdown, the sort bar, and the current sorted
/// offer list, plus the accept-success and request-closed banners. Owns the
/// cubit lifecycle; the host route just passes the request id.
class ClientOffersScreen extends StatelessWidget {
  const ClientOffersScreen({
    super.key,
    required this.requestId,
    required this.repository,
    this.onOfferAccepted,
    this.cubitFactory,
  });

  final String requestId;
  final OffersRepository repository;

  /// Called once the accept request succeeds. The host typically navigates to
  /// the tracking thread; the cubit keeps the success state visible until the
  /// widget is disposed so the banner stays on screen during the transition.
  final void Function(String offerId)? onOfferAccepted;

  /// Test seam — see [ClientOffersCubitFactory].
  final ClientOffersCubitFactory? cubitFactory;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ClientOffersCubit>(
      create: (_) {
        final cubit = cubitFactory?.call(repository, requestId) ??
            ClientOffersCubit(
              repository: repository,
              requestId: requestId,
            );
        cubit.load();
        return cubit;
      },
      child: _ClientOffersView(onOfferAccepted: onOfferAccepted),
    );
  }
}

class _ClientOffersView extends StatelessWidget {
  const _ClientOffersView({this.onOfferAccepted});

  final void Function(String offerId)? onOfferAccepted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: OMDSAppBar(
        title: l10n.offersScreenTitle,
        showBackButton: true,
      ),
      body: BlocConsumer<ClientOffersCubit, ClientOffersState>(
        listenWhen: (prev, next) =>
            prev.acceptStatus != next.acceptStatus &&
            next.acceptStatus == AcceptStatus.succeeded,
        listener: (context, state) {
          final id = state.acceptedOfferId;
          if (id != null) onOfferAccepted?.call(id);
        },
        builder: (context, state) {
          switch (state.status) {
            case OffersScreenStatus.initial:
            case OffersScreenStatus.loading:
              return const OmdsLoadingState();
            case OffersScreenStatus.failed:
              return OmdsErrorState(
                key: const Key('offer-load-error'),
                message: _errorCopy(l10n, state.error),
                retryLabel: l10n.offersRetryAction,
                onRetry: () =>
                    context.read<ClientOffersCubit>().refresh(),
              );
            case OffersScreenStatus.loaded:
              return _LoadedBody(
                state: state,
                onSortChanged: (mode) =>
                    context.read<ClientOffersCubit>().setSortMode(mode),
                onAccept: (id) =>
                    context.read<ClientOffersCubit>().acceptOffer(id),
                onRefresh: () =>
                    context.read<ClientOffersCubit>().refresh(),
              );
          }
        },
      ),
    );
  }

  static String _errorCopy(AppLocalizations l10n, OffersFailure? failure) {
    switch (failure) {
      case OffersFailure.network:
        return l10n.offersErrorNetwork;
      case OffersFailure.requestNotOpen:
        return l10n.offersErrorRequestNotOpen;
      case OffersFailure.offerNotPending:
        return l10n.offersErrorOfferNotPending;
      case OffersFailure.unknown:
      case null:
        return l10n.offersErrorGeneric;
    }
  }
}

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({
    required this.state,
    required this.onSortChanged,
    required this.onAccept,
    required this.onRefresh,
  });

  final ClientOffersState state;
  final ValueChanged<OfferSortMode> onSortChanged;
  final void Function(String offerId) onAccept;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final acceptDisabled = state.acceptStatus == AcceptStatus.inFlight ||
        state.acceptStatus == AcceptStatus.succeeded ||
        state.windowExpired ||
        !state.requestIsOpen;
    return OmdsPullToRefresh(
      onRefresh: onRefresh,
      child: ListView(
        key: const Key('offer-list'),
        padding: const EdgeInsetsDirectional.fromSTEB(
          Spacing.medium,
          Spacing.medium,
          Spacing.medium,
          Spacing.xLarge,
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          OfferWindowTimer(
            remaining: state.windowRemaining,
            expired: state.windowExpired,
          ),
          if (!state.requestIsOpen) ...[
            const SizedBox(height: Spacing.small),
            _Banner(
              key: const Key('offer-request-closed-banner'),
              icon: Icons.lock_outline,
              title: l10n.offersRequestClosedTitle,
            ),
          ],
          if (state.acceptStatus == AcceptStatus.succeeded) ...[
            const SizedBox(height: Spacing.small),
            _Banner(
              key: const Key('offer-accepted-banner'),
              icon: Icons.check_circle_outline,
              title: l10n.offersAcceptedBannerTitle,
              body: l10n.offersAcceptedBannerBody,
              positive: true,
            ),
          ],
          if (state.error != null) ...[
            const SizedBox(height: Spacing.small),
            _ErrorBanner(
              message: _errorCopyFor(l10n, state.error!),
              onDismiss: () =>
                  context.read<ClientOffersCubit>().acknowledgeError(),
            ),
          ],
          const SizedBox(height: Spacing.medium),
          Text(
            l10n.offersPanelHeader,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: Spacing.small),
          OfferSortBar(mode: state.sortMode, onChanged: onSortChanged),
          const SizedBox(height: Spacing.xSmall),
          if (!state.hasOffers)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.xLarge),
              child: OmdsEmptyState(
                key: const Key('offer-empty-state'),
                icon: Icons.hourglass_top_outlined,
                title: l10n.offersEmptyTitle,
                subtitle: l10n.offersEmptyBody,
              ),
            )
          else
            ...state.offers.map(
              (offer) => OfferCard(
                offer: offer,
                isAccepting: state.acceptingOfferId == offer.id,
                acceptDisabled: acceptDisabled &&
                    state.acceptingOfferId != offer.id,
                onAccept: () => onAccept(offer.id),
              ),
            ),
        ],
      ),
    );
  }

  static String _errorCopyFor(AppLocalizations l10n, OffersFailure failure) {
    switch (failure) {
      case OffersFailure.network:
        return l10n.offersErrorNetwork;
      case OffersFailure.requestNotOpen:
        return l10n.offersErrorRequestNotOpen;
      case OffersFailure.offerNotPending:
        return l10n.offersErrorOfferNotPending;
      case OffersFailure.unknown:
        return l10n.offersErrorGeneric;
    }
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.positive = false,
  });

  final IconData icon;
  final String title;
  final String? body;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final background = positive
        ? colors.tertiaryContainer
        : colors.surfaceContainerHighest;
    final foreground = positive
        ? colors.onTertiaryContainer
        : colors.onSurface;
    return Container(
      padding: const EdgeInsets.all(Spacing.small),
      decoration: BoxDecoration(
        color: background,
        borderRadius: OmdsBorderRadius.small,
      ),
      child: Row(
        children: [
          Icon(icon, color: foreground),
          const SizedBox(width: Spacing.small),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: foreground),
                ),
                if (body != null) ...[
                  const SizedBox(height: Spacing.twoXSmall),
                  Text(
                    body!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: foreground),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      key: const Key('offer-error-banner'),
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.small,
        vertical: Spacing.small,
      ),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: OmdsBorderRadius.small,
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.onErrorContainer),
          const SizedBox(width: Spacing.small),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colors.onErrorContainer),
            ),
          ),
          IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            icon: Icon(Icons.close, color: colors.onErrorContainer),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
