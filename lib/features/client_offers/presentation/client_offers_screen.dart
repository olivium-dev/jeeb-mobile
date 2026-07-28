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

/// Signature for the optional cubit factory the screen exposes for tests.
/// Production wiring leaves it `null` so the default ticker-driven cubit is
/// used; tests pass a factory that injects an empty `refreshSignals` /
/// `clockTicks` so the test binding doesn't complain about pending timers.
typedef ClientOffersCubitFactory =
    ClientOffersCubit Function(OffersRepository repository, String requestId);

/// `offer-review-list` (JM-028) — the client's view of the per-Jeeber offer
/// cards for one request, reached at `/requests/:id/offers`.
///
/// Renders the offer-window countdown, the price/rating sort bar, and the
/// sorted offer list. Each card shows the Jeeber identity, price, ETA, rating
/// and the "Pay $X cash on delivery" line (D11). The consequential edges are:
///   - tap a Jeeber name  → `jeeber-profile-reviews` (JM-067)
///   - tap Accept on a card → the JM-029 `offer-accept-confirm` sheet
///     (NOT an inline accept — the D11/D71 comprehension gate)
///   - tap Cancel request → the JM-030 `cancel-request-confirm` sheet (free
///     pre-accept, D69)
///
/// Owns the [ClientOffersCubit] lifecycle (load + poll); the host route just
/// passes the request id. [repository] is optional — when omitted the screen
/// resolves [OffersRepository] from GetIt (DioOffersRepository in release).
/// Pass an explicit repository only in widget tests.
///
/// Semantics identifiers exposed (EXACT, 63_W1_TEST_PLAN §2.8):
///   - `offer_review_list_root`     — screen root (signature id)
///   - `offer_review_sort_price` / `offer_review_sort_rating` — sort controls
///   - `offer_card_<n>` (+ per-Jeeber alias) with `_price` / `_eta` /
///     `_cash_on_delivery_label` / `_name` / `_accept_cta` (see [OfferCard])
///   - `offer_review_cancel_cta`    — cancel request → cancel-request-confirm
class ClientOffersScreen extends StatelessWidget {
  const ClientOffersScreen({
    super.key,
    required this.requestId,
    this.repository,
    this.cancelRepositoryOverride,
    this.cubitFactory,
  });

  final String requestId;

  /// Optional repository override. Production builds leave this null and
  /// resolve DioOffersRepository from DI. Widget tests inject a scripted
  /// instance via this parameter.
  final OffersRepository? repository;

  /// Optional override forwarded to the JM-030 cancel sheet so a widget test
  /// can avoid the live cancel repository. Null in production (the sheet
  /// resolves its own repo from DI).
  final CancelRequestRepository? cancelRepositoryOverride;

  /// Test seam — see [ClientOffersCubitFactory].
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
              // b02 wave C / N8: the 5s `Stream.periodic` that used to drive
              // this list is gone. A `type=offer` push now re-reads it, through
              // the ONE existing resolver — no second bus.
              //
              // b02 wave D — `{order, offers}`. `offers` is the bid set this
              // screen renders; `order` keeps the accept/cancel transition
              // (`type=delivery`) landing, since accepting closes this list.
              // `fetchOffers` fans out into TWO gateway reads, so keeping a
              // `chat` message out of here removes two wire calls per message.
              refreshSignals: resolvePushRefreshStream(
                topics: const {RefreshTopic.order, RefreshTopic.offers},
              ),
            );
        cubit.load();
        return cubit;
      },
      // N8 RESUME BACKSTOP — the twin of N9's, same widget, same reason.
      // `cubit.load()` above is the MOUNT one-shot; a push delivered while the
      // app is backgrounded never reaches the refresh bus, so without this the
      // bid list stayed stale after resume. Milder than N9 only because
      // pull-to-refresh (`_LoadedBody`'s `OmdsPullToRefresh`) lets the customer
      // self-rescue — which is not a fix, it is a workaround the user has to
      // know to perform.
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
        // P2: this screen is now a push-tap stack ROOT (`go`, not `push`), so
        // the default `maybePop()` is a dead arrow on an empty stack. Pop when
        // we can (in-app Replies CTA entry), else return to the shell.
        onBackPressed: () => context.canPop() ? context.pop() : context.go('/'),
      ),
      // offer_review_list_root — signature id for the offer-review-list route.
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
    // Request status is the action authority. A locally elapsed display
    // deadline cannot disable a server-live offer.
    final acceptDisabled = !state.requestIsOpen;
    // B-01: the id whose accept-confirm sheet is currently open/in flight (null
    // when none). Drives the accept-exactly-ONE list guard below.
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
                // B-01: while ANY accept-confirm sheet is open (its POST may be
                // in flight), EVERY card's Accept CTA disables so a second offer
                // can't be accepted concurrently (double-accept). The sheet owns
                // the in-flight spinner; the cards behind it just go inert until
                // the sheet closes (endAccept).
                isAccepting: false,
                acceptDisabled: acceptDisabled || acceptingOfferId != null,
                // Accept → JM-029 offer-accept-confirm sheet (not inline).
                onAccept: () => _openAcceptSheet(context, entry.value),
                // Name → jeeber-profile-reviews (JM-067).
                onTapName: () => _openJeeberProfile(context, entry.value),
              ),
            ),
          if (state.hasOffers && state.requestIsOpen) ...[
            const SizedBox(height: Spacing.large),
            // offer_review_cancel_cta → cancel-request-confirm sheet (JM-030).
            // `container: true` makes this an explicit, id-addressable child of
            // the `offer_review_list_root` node (which sets
            // `explicitChildNodes: true`) — without it the CTA's Semantics is
            // merged into the surrounding ListView subtree and Maestro can't
            // resolve the identifier (W2 QA RD-3). Mirrors the offer-card CTAs
            // (each `container: true`) and the cancel-sheet confirm CTA.
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

  /// EDGE (63_W1_TEST_PLAN §3 jm-028, JM-029, D11/D71):
  /// `offer_card_<id>_accept_cta` → offer-accept-confirm sheet. The sheet owns
  /// the accept call + the post-accept navigation to order-chat; the list never
  /// accepts inline.
  void _openAcceptSheet(BuildContext context, Offer offer) {
    // B-01: mark this offer as accepting on the LIST cubit before opening the
    // sheet (disables every sibling Accept CTA) and clear it when the sheet
    // closes — wiring the dead `acceptingOfferId` guard into the real accept
    // path. `whenComplete` fires on cancel / failure-dismiss; on success the
    // sheet has navigated to order-chat and `endAccept`'s isClosed guard no-ops.
    final cubit = context.read<ClientOffersCubit>();
    // B-01: a same-frame double-tap (or a double semantics activation) can fire
    // onAccept twice before the `acceptingOfferId` rebuild disables the sibling
    // CTAs. beginAccept no-ops the second time, but show() would still stack a
    // second accept sheet — so bail here when an accept is already in flight.
    if (cubit.state.acceptStatus == AcceptStatus.inFlight) return;
    cubit.beginAccept(offer.id);
    OfferAcceptSheet.show(
      context,
      offer: offer,
      requestId: requestId,
      repository: repository,
    ).whenComplete(cubit.endAccept);
  }

  /// EDGE (63_W1_TEST_PLAN §3 jm-028, JM-067): `offer_card_<id>_name` →
  /// jeeber-profile-reviews. We hand the registered `delivery-man-profile`
  /// route a [DeliveryManProfileViewData] built from the offer's identity +
  /// rating; the reviews list is loaded by the target screen (R1m). Cold-start
  /// rating-hiding (under 5 reviews, D59) and first-name attribution (D58) are the
  /// profile screen's concern (JM-067).
  void _openJeeberProfile(BuildContext context, Offer offer) {
    // W6/SW-08: hand the profile a resolved display name so a synthetic handle
    // / UUID from the un-enriched offer row never reaches the profile header
    // (its own leak-suppression is SW-13's lane, but the offer surface must not
    // be the one that feeds it an identifier-as-name).
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

  /// EDGE (63_W1_TEST_PLAN §3 jm-028, JM-030, D69): offer_review_cancel_cta →
  /// cancel-request-confirm sheet (free pre-accept). The sheet routes home on
  /// confirm; it dismisses (returns false) on keep.
  void _openCancelSheet(BuildContext context) {
    CancelRequestSheet.show(
      context,
      requestId: requestId,
      repository: cancelRepositoryOverride,
    );
  }
}

/// Which phase of the offer-review flow raised the failure — the classified
/// branches share copy, only the unclassified/`unknown` fallback is
/// phase-specific (F9): a load failure must never say "accepting".
enum OffersErrorPhase { load, accept }

/// Single shared source of truth for offer-review failure copy (F9). Both the
/// full-screen load error ([OmdsErrorState]) and the inline accept banner route
/// through here so the five [OffersFailure] strings stay consistent; only the
/// generic fallback diverges by [phase].
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
    // rateLimited is a TRANSIENT state the cubit handles by staying in loading
    // and auto-retrying — it must never reach a rendered error surface. Fold it
    // into the generic fallback for switch-exhaustiveness (defensive only).
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
