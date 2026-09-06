import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_failure_block.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../reviews/domain/reviews_repository.dart';
import '../application/delivery_man_profile_reviews_cubit.dart';
import '../application/delivery_man_profile_reviews_state.dart';
import '../data/reviews_backed_delivery_man_profile_repository.dart';
import '../domain/delivery_man_profile_repository.dart';
import '../domain/delivery_man_profile_view_data.dart';
import 'widgets/delivery_man_profile_header.dart';
import 'widgets/delivery_reviews_header.dart';
import 'widgets/delivery_reviews_list.dart';

/// Delivery Man public profile / jeeber-profile-reviews (Figma 56580:2697,
/// screen 27; JM-067).
///
/// A read-only profile of a Jeeber as seen by a client, presented modally
/// (close "X", no bottom nav). Identity header + a "Reviews" section.
/// Reuse posture: identity composes OMDS primitives; review cards reuse
/// [OmdsReviewCard] (reuse-table.md Ratings/Feedback → feedback-service).
///
/// redesign-2026-08: re-skinned onto the Jeeb kit. The Material app bar became
/// the in-body [JeebTopBar] close form (the board's only close treatment), the
/// identity block a `JeebAvatar` + `context.jeebText` ramp, and the review
/// cards `JeebOutlinedCard`s on the 24px gutter. Same flow, same copy, same
/// identifiers — this is a re-skin, not a product change.
///
/// MIDNIGHT (M3-10, tile-less — derived from R15's identity block and R16's
/// score/meta inks): the screen mounts the field instead of the flat
/// `scaffoldBackgroundColor` (token sheet §8) and the identity block becomes
/// R15's centred Ø74 glass disc under the close bar.
///
/// JM-067 changes against the divergent baseline (20_GAP_MAP):
///   - NO Helpful/Reply controls — reviews are immutable/read-only (D57).
///   - `profile_view_all_reviews` → `reviews-list` (JM-068), passing the
///     jeeber's id as `?jeeberId=` when known.
///   - Cold-start: the aggregate score is hidden until the jeeber has >=5
///     reviews (D59) — see [DeliveryManProfileHeader].
///   - Reviewer attribution is first-name only (D58) — see [DeliveryReviewCard].
///   - `profile_close` → offer-review-list (pop, since the profile is pushed
///     onto it from the offer card).
class DeliveryManProfileScreen extends StatelessWidget {
  const DeliveryManProfileScreen({
    super.key,
    required this.data,
    this.repositoryOverride,
  });

  /// Test / catalog seam; production resolves through DI.
  final DeliveryManProfileRepository? repositoryOverride;

  /// Canonical screen-root Semantics id (41_GUARDRAILS_TESTING §1.1; the seam
  /// harness W4 + dev_seam `jeeber_has_reviews` assert this exact id).
  static const String rootId = 'delivery_man_profile_screen_root';

  /// Retained legacy widget [Key] (the Arabic-RTL test reads Directionality
  /// off it). The asserted contract is [rootId].
  static const Key rootKey = Key('delivery-man-profile-screen-root');

  final DeliveryManProfileViewData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: rootId,
      container: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // The board's header is an in-body row, not a Material app bar; the
        // close circle is its leading slot (JeebTopBar.close is the one
        // realized close treatment), so `Scaffold.appBar` stays null.
        body: JeebMidnightField(
          // A reading surface, not a hero: base wash + one quiet glow at the
          // majority top-end anchor. Still, like the 20 board-still tiles.
          variant: JeebFieldVariant.content,
          glowPlacement: JeebFieldGlowPlacement.topEnd,
          animateDecor: false,
          child: SafeArea(
            child: Column(
              children: [
                JeebTopBar.close(
                  // Canonical id per JM-067 AC + 41_GUARDRAILS_TESTING §1.1
                  // (`profile_close`) — the bar lands it on the leading circle.
                  identifier: 'profile_close',
                  leadingTooltip: l10n.deliveryManProfileCloseLabel,
                  onLeadingPressed: () => _close(context),
                ),
                Expanded(
                  child: BlocProvider<DeliveryManProfileReviewsCubit>(
                    create: (_) {
                      final cubit = DeliveryManProfileReviewsCubit(
                        repository: _resolveRepository(),
                        jeeberId: data.jeeberId,
                        seedReviews: data.reviews,
                        seedReviewCount: data.reviewCount,
                      );
                      // Seeded rows are already visible: refresh in place
                      // rather than flip them back to the skeleton (R6).
                      if (cubit.canLoad) {
                        if (cubit.state.status ==
                            DeliveryManProfileReviewsStatus.loaded) {
                          cubit.refresh();
                        } else {
                          cubit.load();
                        }
                      }
                      return cubit;
                    },
                    child: _DeliveryManProfileBody(data: data),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The screen's own seam, so it works before Stage 2 wires the DI call.
  DeliveryManProfileRepository? _resolveRepository() {
    if (repositoryOverride != null) return repositoryOverride;
    final GetIt getIt = GetIt.instance;
    if (getIt.isRegistered<DeliveryManProfileRepository>()) {
      return getIt<DeliveryManProfileRepository>();
    }
    if (getIt.isRegistered<ReviewsRepository>()) {
      return ReviewsBackedDeliveryManProfileRepository(
        getIt<ReviewsRepository>(),
      );
    }
    return null;
  }

  /// EDGE (21_NAV_PLAN §C, JM-067): `profile_close` → offer-review-list. The
  /// profile is PUSHED onto offer-review-list from the offer card, so popping
  /// returns there. Falls back to home only on a cold deep-link with no stack.
  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }
}

class _DeliveryManProfileBody extends StatelessWidget {
  const _DeliveryManProfileBody({required this.data});

  final DeliveryManProfileViewData data;

  @override
  Widget build(BuildContext context) {
    final String? jeeberId = data.jeeberId;
    final bool canOpenAll = jeeberId != null && jeeberId.isNotEmpty;
    return BlocBuilder<
      DeliveryManProfileReviewsCubit,
      DeliveryManProfileReviewsState
    >(
      builder: (context, reviews) => ListView(
        key: DeliveryManProfileScreen.rootKey,
        padding: const EdgeInsetsDirectional.only(
          top: Spacing.small,
          bottom: Spacing.xLarge,
        ),
        children: [
          _Header(data: data),
          // Block rhythm between the identity band and the reviews band.
          const SizedBox(height: Spacing.xLarge),
          DeliveryReviewsHeader(
            reviewCount: reviews.reviewCount,
            showCount: reviews.showCount,
            // DMP-02: no id, no route — the link goes inert rather than
            // showing the CLIENT's own reviews.
            onViewAll: canOpenAll ? () => _openAllReviews(context) : null,
          ),
          _ReviewsBand(state: reviews),
        ],
      ),
    );
  }

  /// EDGE (21_NAV_PLAN §C, JM-067): `profile_view_all_reviews` → `reviews-list`
  /// (JM-068). PUSHED (not go) so reviews-list's `reviews_back` returns to THIS
  /// profile (JM-068 AC). The reviews-list route reads the jeeber via
  /// `?jeeberId=`.
  void _openAllReviews(BuildContext context) {
    final jeeberId = data.jeeberId;
    if (jeeberId == null || jeeberId.isEmpty) return;
    context.pushNamed('reviews-list', queryParameters: {'jeeberId': jeeberId});
  }
}

/// The three rungs of the reviews band — error BEFORE empty.
class _ReviewsBand extends StatelessWidget {
  const _ReviewsBand({required this.state});

  final DeliveryManProfileReviewsState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (state.status) {
      case DeliveryManProfileReviewsStatus.loading:
        return Padding(
          padding: const EdgeInsetsDirectional.all(Spacing.xLarge),
          child: JeebEmptyState.compact(
            status: JeebEmptyStateStatus.loading,
            variant: JeebEmptyStateVariant.parcel,
            identifier: 'delivery_man_profile_reviews_loading',
            headline: l10n.deliveryManProfileReviewsLoading,
          ),
        );
      case DeliveryManProfileReviewsStatus.failed:
        return Padding(
          padding: const EdgeInsetsDirectional.all(Spacing.xLarge),
          child: JeebFailureBlock.compact(
            failure: state.error!,
            identifier: 'delivery_man_profile_reviews_error',
            headlineOverride: l10n.deliveryManProfileReviewsUnavailable,
            onRetry: () =>
                context.read<DeliveryManProfileReviewsCubit>().load(),
            retryIdentifier: 'delivery_man_profile_reviews_retry_cta',
          ),
        );
      case DeliveryManProfileReviewsStatus.initial:
      case DeliveryManProfileReviewsStatus.loaded:
        // D57: Helpful/Reply removed — the list renders read-only cards.
        return DeliveryReviewsList(reviews: state.reviews);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.data});

  final DeliveryManProfileViewData data;

  @override
  Widget build(BuildContext context) {
    final DeliveryManProfileReviewsState reviews = context
        .watch<DeliveryManProfileReviewsCubit>()
        .state;
    final bool loaded =
        reviews.status == DeliveryManProfileReviewsStatus.loaded;
    return DeliveryManProfileHeader(
      name: data.name,
      avatarUrl: data.avatarUrl,
      isVerified: data.isVerified,
      rating: data.rating,
      reviewCount: loaded ? reviews.reviewCount : data.reviewCount,
      showCount: reviews.showCount,
      location: data.location,
      isAvailable: data.isAvailable,
      isColdStart: data.isColdStart, // D59 — hide score until N>=5.
    );
  }
}
