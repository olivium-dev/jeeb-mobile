import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
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
  const DeliveryManProfileScreen({super.key, required this.data});

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
                Expanded(child: _DeliveryManProfileBody(data: data)),
              ],
            ),
          ),
        ),
      ),
    );
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
    return ListView(
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
          reviewCount: data.reviewCount,
          onViewAll: () => _openAllReviews(context),
        ),
        // D57: Helpful/Reply removed — the list renders read-only cards.
        DeliveryReviewsList(reviews: data.reviews),
      ],
    );
  }

  /// EDGE (21_NAV_PLAN §C, JM-067): `profile_view_all_reviews` → `reviews-list`
  /// (JM-068). PUSHED (not go) so reviews-list's `reviews_back` returns to THIS
  /// profile (JM-068 AC). The reviews-list route reads the jeeber via
  /// `?jeeberId=`; we pass it when the source supplied it, else the target
  /// resolves the seeded jeeber.
  void _openAllReviews(BuildContext context) {
    final jeeberId = data.jeeberId;
    context.pushNamed(
      'reviews-list',
      queryParameters: {
        if (jeeberId != null && jeeberId.isNotEmpty) 'jeeberId': jeeberId,
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.data});

  final DeliveryManProfileViewData data;

  @override
  Widget build(BuildContext context) {
    return DeliveryManProfileHeader(
      name: data.name,
      avatarUrl: data.avatarUrl,
      isVerified: data.isVerified,
      rating: data.rating,
      reviewCount: data.reviewCount,
      location: data.location,
      isAvailable: data.isAvailable,
      isColdStart: data.isColdStart, // D59 — hide score until N>=5.
    );
  }
}
