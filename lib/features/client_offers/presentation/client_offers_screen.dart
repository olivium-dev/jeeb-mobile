import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/formatting/friendly_reference.dart';
import '../../../core/layout/bottom_inset.dart';
import '../../../core/lifecycle/route_resume_refetch.dart';
import '../../../l10n/app_localizations.dart';
import '../../cancel_request/domain/cancel_request_repository.dart';
import '../../cancel_request/presentation/cancel_request_sheet.dart';
import '../../delivery_man_profile/domain/delivery_man_profile_view_data.dart';
import '../application/client_offers_cubit.dart';
import '../application/client_offers_state.dart';
import '../data/fake_offers_repository.dart';
import '../domain/offer.dart';
import '../domain/offers_repository.dart';
import 'widgets/offer_accept_sheet.dart';
import 'widgets/offer_card.dart';
import 'widgets/offer_sort_bar.dart';
import 'widgets/offer_window_timer.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../devtool/catalog/fixtures/client_offers_screen_fixtures.dart';
import '../../../core/previews/jeeb_preview.dart';

typedef ClientOffersCubitFactory =
    ClientOffersCubit Function(OffersRepository repository, String requestId);

class ClientOffersScreen extends StatelessWidget {
  const ClientOffersScreen({
    super.key,
    required this.requestId,
    this.repository,
    this.cancelRepositoryOverride,
    this.cubitFactory,
  });

  final String requestId;

  final OffersRepository? repository;

  final CancelRequestRepository? cancelRepositoryOverride;

  final ClientOffersCubitFactory? cubitFactory;

  OffersRepository _resolveRepository() {
    final explicit = repository;
    if (explicit != null) return explicit;
    if (sl.isRegistered<OffersRepository>()) return sl<OffersRepository>();
    return FakeOffersRepository();
  }

  @override
  Widget build(BuildContext context) {
    final repo = _resolveRepository();
    return BlocProvider<ClientOffersCubit>(
      create: (_) {
        final cubit =
            cubitFactory?.call(repo, requestId) ??
            ClientOffersCubit(
              repository: repo,
              requestId: requestId,
              refreshSignals: resolvePushRefreshStream(
                topics: const {RefreshTopic.order, RefreshTopic.offers},
              ),
            );
        cubit.load();
        return cubit;
      },
      child: RouteResumeRefetch(
        onResume: (context) =>
            context.read<ClientOffersCubit>().refreshOnResume(),
        child: _ClientOffersView(
          requestId: requestId,
          repository: repo,
          cancelRepositoryOverride: cancelRepositoryOverride,
        ),
      ),
    );
  }
}

class _ClientOffersView extends StatelessWidget {
  const _ClientOffersView({
    required this.requestId,
    required this.repository,
    this.cancelRepositoryOverride,
  });

  final String requestId;
  final OffersRepository repository;
  final CancelRequestRepository? cancelRepositoryOverride;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: OMDSAppBar(
        title: l10n.offersScreenTitle,
        showBackButton: true,
        onBackPressed: () => context.canPop() ? context.pop() : context.go('/'),
      ),
      body: Semantics(
        identifier: 'offer_review_list_root',
        explicitChildNodes: true,
        child: BlocBuilder<ClientOffersCubit, ClientOffersState>(
          builder: (context, state) {
            switch (state.status) {
              case OffersScreenStatus.initial:
              case OffersScreenStatus.loading:
                return const OmdsLoadingState();
              case OffersScreenStatus.failed:
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: Sizes.threeHundredLarge,
                    ),
                    child: OmdsErrorState(
                      key: const Key('offer-load-error'),
                      message: offersFailureCopy(
                        l10n,
                        state.error,
                        phase: OffersErrorPhase.load,
                      ),
                      retryLabel: l10n.offersRetryAction,
                      onRetry: () => context.read<ClientOffersCubit>().load(),
                    ),
                  ),
                );
              case OffersScreenStatus.loaded:
                return _LoadedBody(
                  state: state,
                  requestId: requestId,
                  repository: repository,
                  cancelRepositoryOverride: cancelRepositoryOverride,
                  onSortChanged: (mode) =>
                      context.read<ClientOffersCubit>().setSortMode(mode),
                  onRefresh: () => context.read<ClientOffersCubit>().refresh(),
                );
            }
          },
        ),
      ),
    );
  }
}

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({
    required this.state,
    required this.requestId,
    required this.repository,
    required this.onSortChanged,
    required this.onRefresh,
    this.cancelRepositoryOverride,
  });

  final ClientOffersState state;
  final String requestId;
  final OffersRepository repository;
  final ValueChanged<OfferSortMode> onSortChanged;
  final Future<void> Function() onRefresh;
  final CancelRequestRepository? cancelRepositoryOverride;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final acceptDisabled = !state.requestIsOpen;
    final acceptingOfferId = state.acceptingOfferId;
    return OmdsPullToRefresh(
      onRefresh: onRefresh,
      child: ListView(
        key: const Key('offer-list'),
        padding: EdgeInsetsDirectional.fromSTEB(
          Spacing.medium,
          Spacing.medium,
          Spacing.medium,
          Spacing.xLarge + context.scrollBodyBottomInset,
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (state.windowExpiresAt != null || state.requestIsExpired)
            OfferWindowTimer(
              remaining: state.windowRemaining,
              expired: state.requestIsExpired,
            ),
          if (!state.requestIsOpen) ...[
            const SizedBox(height: Spacing.small),
            _Banner(
              key: const Key('offer-request-closed-banner'),
              icon: Icons.lock_outline,
              title: l10n.offersRequestClosedTitle,
            ),
          ],
          if (state.error != null) ...[
            const SizedBox(height: Spacing.small),
            _ErrorBanner(
              message: offersFailureCopy(
                l10n,
                state.error!,
                phase: state.errorSource == OffersErrorSource.load
                    ? OffersErrorPhase.load
                    : OffersErrorPhase.accept,
              ),
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
            ...state.offers.asMap().entries.map(
              (entry) => OfferCard(
                offer: entry.value,
                index: entry.key,
                isAccepting: false,
                acceptDisabled: acceptDisabled || acceptingOfferId != null,
                onAccept: () => _openAcceptSheet(context, entry.value),
                onTapName: () => _openJeeberProfile(context, entry.value),
              ),
            ),
          if (state.hasOffers && state.requestIsOpen) ...[
            const SizedBox(height: Spacing.large),
            Semantics(
              identifier: 'offer_review_cancel_cta',
              container: true,
              button: true,
              label: l10n.offerReviewCancelCta,
              onTap: () => _openCancelSheet(context),
              child: ExcludeSemantics(
                child: OmdsPrimaryButton(
                  key: const Key('offer-review-cancel-cta'),
                  text: l10n.offerReviewCancelCta,
                  variant: OmdsButtonVariant.text,
                  onTap: () => _openCancelSheet(context),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openAcceptSheet(BuildContext context, Offer offer) {
    final cubit = context.read<ClientOffersCubit>();
    if (cubit.state.acceptStatus == AcceptStatus.inFlight) return;
    cubit.beginAccept(offer.id);
    OfferAcceptSheet.show(
      context,
      offer: offer,
      requestId: requestId,
      repository: repository,
    ).whenComplete(cubit.endAccept);
  }

  void _openJeeberProfile(BuildContext context, Offer offer) {
    final l10n = AppLocalizations.of(context);
    context.pushNamed(
      'delivery-man-profile',
      extra: DeliveryManProfileViewData(
        name:
            displayNameOrNull(offer.jeeberName) ??
            l10n.offersCardJeeberFallback,
        rating: offer.rating,
        reviewCount: offer.ratingCount,
        location: '',
        isAvailable: true,
        reviews: const <DeliveryReviewData>[],
        avatarUrl: offer.avatarUrl,
      ),
    );
  }

  void _openCancelSheet(BuildContext context) {
    CancelRequestSheet.show(
      context,
      requestId: requestId,
      repository: cancelRepositoryOverride,
    );
  }
}

enum OffersErrorPhase { load, accept }

String offersFailureCopy(
  AppLocalizations l10n,
  OffersFailure? failure, {
  required OffersErrorPhase phase,
}) {
  switch (failure) {
    case OffersFailure.network:
      return l10n.offersErrorNetwork;
    case OffersFailure.requestNotOpen:
      return l10n.offersErrorRequestNotOpen;
    case OffersFailure.offerNotPending:
      return l10n.offersErrorOfferNotPending;
    case OffersFailure.jeeberAtCapacity:
      return l10n.offersErrorJeeberAtCapacity;
    case OffersFailure.rateLimited:
    case OffersFailure.unknown:
    case null:
      return switch (phase) {
        OffersErrorPhase.load => l10n.offersLoadErrorGeneric,
        OffersErrorPhase.accept => l10n.offersErrorGeneric,
      };
  }
}

class _Banner extends StatelessWidget {
  const _Banner({super.key, required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(Spacing.small),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: OmdsBorderRadius.small,
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.onSurface),
          const SizedBox(width: Spacing.small),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: colors.onSurface,
              ),
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
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onErrorContainer,
              ),
            ),
          ),
          Semantics(
            identifier: 'offer_review_error_dismiss_cta',
            button: true,
            container: true,
            child: IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              icon: Icon(Icons.close, color: colors.onErrorContainer),
              onPressed: onDismiss,
            ),
          ),
        ],
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The phone this screen is designed against.
const Size _clientOffersScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports — and roughly what an Android
/// multi-window split leaves a foreground app.
const Size _clientOffersScreenCompactBox = Size(320, 568);

/// Pins [screen] to a device-sized frame inside whatever box the host gives it.
Widget _clientOffersScreenFramed(
  Widget screen, {
  Size box = _clientOffersScreenPhoneBox,
}) {
  return Align(
    alignment: Alignment.topCenter,
    child: SizedBox(width: box.width, height: box.height, child: screen),
  );
}

/// Builds the screen the way its route builds it — id + repository — with the
/// two seams a preview needs: an inert cubit and a local cancel repository.
Widget _clientOffersScreenHosted(
  OffersRepository repository, {
  ClientOffersCubitFactory cubitFactory =
      ClientOffersScreenPreviewFixtures.inertCubit,
  Size box = _clientOffersScreenPhoneBox,
}) {
  return _clientOffersScreenFramed(
    ClientOffersScreen(
      requestId: ClientOffersScreenPreviewFixtures.requestId,
      repository: repository,
      cancelRepositoryOverride:
          ClientOffersScreenPreviewFixtures.cancelRepository(),
      cubitFactory: cubitFactory,
    ),
    box: box,
  );
}

/// The reference reading: an open request with three bids and 4:30 left.
/// Three card readings at once — a well-rated Jeeber, one with a note, and a
@JeebPreview(
  group: 'client_offers',
  name: 'Fresh window · three bids',
  size: _clientOffersScreenPhoneBox,
  matrix: true,
)
Widget clientOffersScreenFreshWindow() =>
    _clientOffersScreenHosted(ClientOffersScreenPreviewFixtures.freshWindow());

/// A read that SUCCEEDED and came back with zero rows while the window is still
/// wide open: "Waiting for offers".
@JeebPreview(
  group: 'client_offers',
  name: 'Empty · no bids yet',
  size: _clientOffersScreenPhoneBox,
)
Widget clientOffersScreenEmpty() =>
    _clientOffersScreenHosted(ClientOffersScreenPreviewFixtures.noBidsYet());

/// The cold read in flight: an [OmdsLoadingState] spinner and nothing else.
/// Note what is NOT on screen — no window, no sort bar, no copy, and no way to
@JeebPreview(
  group: 'client_offers',
  name: 'Loading · cold read',
  size: _clientOffersScreenPhoneBox,
)
Widget clientOffersScreenLoading() =>
    _clientOffersScreenHosted(ClientOffersScreenPreviewFixtures.stalledLoad());

/// The cold read failed (a dropped transport, a 500): the centred
/// [OmdsErrorState] with classified copy and a Retry that re-enters the full
@JeebPreview(
  group: 'client_offers',
  name: 'Load failed · network',
  size: _clientOffersScreenPhoneBox,
)
Widget clientOffersScreenLoadFailed() =>
    _clientOffersScreenHosted(ClientOffersScreenPreviewFixtures.failingLoad());

/// A pull-to-refresh that failed over a list the customer can still act on.
/// `refresh` is non-destructive by design, so the bid stays, the Accept CTA
@JeebPreview(
  group: 'client_offers',
  name: 'Refresh failed · list kept',
  size: _clientOffersScreenPhoneBox,
)
Widget clientOffersScreenRefreshFailed() => _clientOffersScreenHosted(
  ClientOffersScreenPreviewFixtures.refreshFails(),
  cubitFactory: ClientOffersScreenPreviewFixtures.refreshFailureCubit,
);

/// The display deadline has passed LOCALLY while the gateway still reports the
/// request open.
@JeebPreview(
  group: 'client_offers',
  name: 'Window elapsed locally · offers still live',
  size: _clientOffersScreenPhoneBox,
)
Widget clientOffersScreenElapsedWindow() => _clientOffersScreenHosted(
  ClientOffersScreenPreviewFixtures.elapsedWindow(),
);

/// The gateway has closed the request (matched, or cancelled elsewhere) with no
/// deadline in the snapshot.
@JeebPreview(
  group: 'client_offers',
  name: 'Request closed',
  size: _clientOffersScreenPhoneBox,
)
Widget clientOffersScreenRequestClosed() => _clientOffersScreenHosted(
  ClientOffersScreenPreviewFixtures.closedRequest(),
);

/// The terminal server verdict: `requestIsExpired` AND `requestIsOpen: false`.
/// The state's own comment is that only a terminal server snapshot sets the
@JeebPreview(
  group: 'client_offers',
  name: 'Server-expired · terminal',
  size: _clientOffersScreenPhoneBox,
)
Widget clientOffersScreenServerExpired() => _clientOffersScreenHosted(
  ClientOffersScreenPreviewFixtures.serverExpired(),
);

/// The layout ceiling, on the narrowest phone the app supports.
/// Everything that can be long is long at once: a 42-character name, a non-USD
@JeebPreview(
  group: 'client_offers',
  name: 'Longest content · compact 320',
  size: _clientOffersScreenCompactBox,
  matrix: true,
)
Widget clientOffersScreenLongestContent() => _clientOffersScreenHosted(
  ClientOffersScreenPreviewFixtures.longestContent(),
  box: _clientOffersScreenCompactBox,
);
