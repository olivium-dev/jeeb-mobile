import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

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
        appBar: OMDSAppBar(
          title: '',
          automaticallyImplyLeading: false,
          actions: [_CloseButton(label: l10n.deliveryManProfileCloseLabel)],
        ),
        body: _DeliveryManProfileBody(data: data),
      ),
    );
  }
}

class _DeliveryManProfileBody extends StatelessWidget {
  const _DeliveryManProfileBody({required this.data});

  final DeliveryManProfileViewData data;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: DeliveryManProfileScreen.rootKey,
      padding: const EdgeInsetsDirectional.only(bottom: Spacing.large),
      children: [
        _Header(data: data),
        const SizedBox(height: Spacing.large),
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

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    // Canonical id per JM-067 AC + 41_GUARDRAILS_TESTING §1.1 (`profile_close`).
    return Semantics(
      identifier: 'profile_close',
      button: true,
      label: label,
      child: IconButton(
        key: const Key('delivery-man-profile-close'),
        icon: const Icon(Icons.close),
        tooltip: label,
        color: Theme.of(context).colorScheme.secondaryContainer,
        onPressed: () => _close(context),
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
