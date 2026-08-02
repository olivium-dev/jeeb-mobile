import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/delivery_man_profile_view_data.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

/// Wraps a [DeliveryReviewData] in the shared [OmdsReviewCard] (reuse-table.md:
/// Ratings/Feedback → feedback-service, use-as-is). Supplies brand-orange stars
/// ([ColorScheme.primary]) and the verified-client subtitle. Bordered + rounded
/// to match the Figma card; index drives the Semantics ids QA/Maestro target.
///
/// JM-067: read-only. Helpful/Reply actions are suppressed (`showActions:
/// false`, D57 — immutable reviews); the reviewer is attributed by first name
/// only (`reviewerFirstName`, D58).
class DeliveryReviewCard extends StatelessWidget {
  const DeliveryReviewCard({
    super.key,
    required this.review,
    required this.index,
  });

  final DeliveryReviewData review;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'delivery_man_profile_review_card_$index',
      container: true,
      explicitChildNodes: true,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(Sizes.small),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: _ReviewCardBody(review: review),
      ),
    );
  }
}

class _ReviewCardBody extends StatelessWidget {
  const _ReviewCardBody({required this.review});

  final DeliveryReviewData review;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final firstName = review.reviewerFirstName;
    final isAnonymous = firstName.isEmpty;
    final displayName = isAnonymous ? l10n.reviewerAnonymousLabel : firstName;
    return Padding(
      padding: const EdgeInsets.all(Spacing.medium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // OmdsReviewCard derives "?" for every non-Latin initial. Using
              // the OMDS avatar directly lets an Arabic anonymous label remain
              // visible while its privacy-safe neutral initial stays stable.
              OmdsProfileAvatar(
                initial: isAnonymous ? 'J' : firstName,
                profilePicUrl: isAnonymous ? null : review.reviewerAvatarUrl,
                size: Sizes.large * 2,
              ),
              const SizedBox(width: Spacing.small),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (review.isVerified) ...[
                      const SizedBox(height: Spacing.twoXSmall),
                      Text(
                        l10n.reviewerVerifiedBadge,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: Sizes.small,
                        ),
                      ),
                    ],
                    const SizedBox(height: Spacing.twoXSmall),
                    _ReviewStars(
                      rating: review.rating,
                      semanticsLabel: l10n.reviewRatingStarsLabel(
                        _formatRating(review.rating),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                l10n.reviewRelativeDaysAgo(review.daysAgo),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: Sizes.small,
                ),
              ),
            ],
          ),
          if (review.body.isNotEmpty) ...[
            const SizedBox(height: Spacing.small),
            Text(
              review.body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatRating(double rating) =>
      rating == rating.roundToDouble() ? rating.toStringAsFixed(0) : '$rating';
}

class _ReviewStars extends StatelessWidget {
  const _ReviewStars({required this.rating, required this.semanticsLabel});

  final double rating;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      container: true,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            final value = index + 1;
            final icon = rating >= value
                ? Icons.star
                : rating >= value - 0.5
                ? Icons.star_half
                : Icons.star_border;
            return Padding(
              padding: EdgeInsetsDirectional.only(
                end: index < 4 ? Sizes.threeXSmall : 0,
              ),
              child: Icon(
                icon,
                size: Sizes.small,
                color: Theme.of(context).colorScheme.primary,
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/delivery_man_profile/delivery_review_card_preview_test.dart
// ===========================================================================

// Widget previews for [DeliveryReviewCard] — run with
// `flutter widget-preview start`.
//
// The card is a pure props widget: it takes one [DeliveryReviewData] and an
// index, and reads nothing but [Theme] and [AppLocalizations]. So every state
// below is a plain const fixture — there is no cubit and no repository to
// stub, which makes these previews network-free by construction rather than by
// the guard in `jeebPreviewHost`. (The avatar URLs below are the one exception
// and are deliberate: `OmdsProfileAvatar` renders its initial placeholder
// whenever the image has not loaded, which is exactly what the canvas and the
// tests should see.)
//
// Fixture values are lifted from the existing tests and dev fixtures rather
// than invented — `test/features/delivery_man_profile/delivery_review_card_a11y_test.dart`
// (the blank-reviewer regression), `test/delivery_man_profile_screen_test.dart`
// ("Karl Assaf", 4 stars, 2 days ago) and
// `lib/features/delivery_man_profile/data/dev_delivery_man_profile_fixtures.dart`
// (the lorem body the Figma comp uses).
//
// The states are chosen for where the card BREAKS: the header is a `Row` whose
// name column is `Expanded` and whose trailing "N days ago" stamp is not, so
// the long-name and 200%-text renderings are the ones worth looking at.
//
// TWO DEFECTS THESE PREVIEWS EXPOSE, both visible in the canvas and neither
// fixed here (previews are additive; the card is untouched):
//
// 1. **The header Row overflows at 200% text, in every single state.** At 390
//    logical px the stamp measures 244–293 px of the 318 px content row, the
//    40 px avatar does not shrink, and the `Expanded` name column is squeezed
//    past zero — `RenderFlex overflowed by 4.4…48 px on the right`, AR
//    included. Nothing in the header sets `maxLines`/`ellipsis`, and the stamp
//    is not `Flexible`.
// 2. **`reviewRelativeDaysAgo` has no plural form.** It is a bare
//    `"{count} days ago"` in both ARBs, so a day-old review reads "1 days ago"
//    (EN) / "قبل 1 يوم" (AR, which also wants the dual for 2).
//    `deliveryReviewCardNoBody` is seeded with `daysAgo: 1` so the canvas
//    shows it.

/// A review card with a one-or-two-line body: phone width, plus the list
/// padding. Boxes below are sized from what the card actually measures at 390
/// logical px (160–181 px of card + 36 px of list padding), not guessed.
const Size _deliveryReviewCardBox = Size(390, 230);

/// A body-less card collapses to the header row only (~106 px of card).
const Size _deliveryReviewCardCompactBox = Size(390, 155);

/// The longest plausible body needs ~327 px of card on its own.
const Size _deliveryReviewCardTallBox = Size(390, 380);

/// The Figma comp's review body (`DevDeliveryManProfileFixtures`).
const String _deliveryReviewCardLorem =
    'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed ut leo '
    'facilisis, mollis dolor bibendum, tempor dolor. Lorem ipsum dolor sit '
    'amet, consectetur adipiscing elit.';

/// Hosts one card the way [DeliveryReviewsList] does: the same directional list
/// padding, and — the part that matters — an UNBOUNDED height.
///
/// The card's body is a `Column` with the default `mainAxisSize.max`, so handed
/// a tight height (dropped straight into a Scaffold body, say) it stretches to
/// fill the canvas and every state looks identically tall. Under the page's
/// scroll view it hugs its content, which is what these previews need to show.
Widget _deliveryReviewCardHosted(DeliveryReviewData review, {int index = 0}) =>
    SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.large,
        Spacing.medium,
        Spacing.large,
        Spacing.large,
      ),
      child: DeliveryReviewCard(review: review, index: index),
    );

/// The happy path, as the screen test builds it: a named, verified reviewer
/// with a whole-number score and a short body.
///
/// Attribution is FIRST NAME ONLY (D58) — this must read "Karl", never
/// "Karl Assaf".
@JeebPreview(group: 'delivery_man_profile', name: 'Verified, 4 stars', size: _deliveryReviewCardBox)
Widget deliveryReviewCardVerified() => _deliveryReviewCardHosted(
      const DeliveryReviewData(
        id: 'r1',
        reviewerName: 'Karl Assaf',
        rating: 4,
        body: 'Great delivery, fast and friendly.',
        daysAgo: 2,
        reviewerAvatarUrl: 'https://i.pravatar.cc/150?img=15',
      ),
    );

/// The blank-reviewer regression, made visible.
///
/// A review can arrive from feedback-service with an empty client name. The
/// card must show the localized "Jeeb customer" label and the neutral "J"
/// initial, and must NOT fall through to `OmdsReviewCard`'s "?" — which is what
/// it did before, and which is why the card builds the avatar itself. The
/// stored avatar URL is dropped on purpose: an anonymous review must not leak a
/// recognizable face. Guarded by `delivery_review_card_a11y_test.dart`; the AR
/// rendering is the half that test cannot show you.
@JeebPreview(group: 'delivery_man_profile', name: 'Anonymous reviewer', size: _deliveryReviewCardBox)
Widget deliveryReviewCardAnonymous() => _deliveryReviewCardHosted(
      const DeliveryReviewData(
        id: 'anonymous',
        reviewerName: '   ',
        rating: 4,
        body: 'Great delivery.',
        daysAgo: 2,
        reviewerAvatarUrl: 'https://example.com/private-avatar.png',
      ),
      index: 1,
    );

/// A star-only review: the client rated but wrote nothing.
///
/// The body block is dropped entirely (`review.body.isNotEmpty`), so the card
/// collapses to its header. Worth its own preview because the trailing padding
/// is easy to get wrong when the last child disappears — a card that keeps a
/// body-sized gap under the stars reads as a failed load.
///
/// Also seeded with `daysAgo: 1` to surface defect 2 above: this card renders
/// the ungrammatical "1 days ago".
@JeebPreview(group: 'delivery_man_profile', name: 'Rating only, no body', size: _deliveryReviewCardCompactBox)
Widget deliveryReviewCardNoBody() => _deliveryReviewCardHosted(
      const DeliveryReviewData(
        id: 'r-no-body',
        reviewerName: 'Nadia Chehab',
        rating: 5,
        body: '',
        daysAgo: 1,
        helpfulCount: 24,
      ),
      index: 2,
    );

/// A half-star score — the only state that renders `Icons.star_half`.
///
/// It is also the only state where `_formatRating` takes its non-integer
/// branch, so the screen-reader label reads "4.5 of 5 stars" rather than
/// "4.5000000 of 5 stars". The visual stars are wrapped in `ExcludeSemantics`,
/// which means this label is the ONLY thing a screen reader gets from the
/// score.
@JeebPreview(group: 'delivery_man_profile', name: 'Half star', size: _deliveryReviewCardBox)
Widget deliveryReviewCardHalfStar() => _deliveryReviewCardHosted(
      const DeliveryReviewData(
        id: 'r-half',
        reviewerName: 'Rami Khoury',
        rating: 4.5,
        body: 'Arrived on time, but the bag was a little squashed.',
        daysAgo: 12,
      ),
      index: 3,
    );

/// An unverified reviewer: the "Verified Client" subtitle disappears and the
/// name sits directly above the stars.
///
/// The badge is the card's only two-line header element, so this is the state
/// that proves the header still aligns when it is gone — and the state that
/// proves the badge is not being drawn unconditionally.
@JeebPreview(group: 'delivery_man_profile', name: 'Unverified reviewer', size: _deliveryReviewCardBox)
Widget deliveryReviewCardUnverified() => _deliveryReviewCardHosted(
      const DeliveryReviewData(
        id: 'r-unverified',
        reviewerName: 'Tarek Aoun',
        rating: 3,
        body: 'Took a while to find the building.',
        daysAgo: 30,
        isVerified: false,
      ),
      index: 4,
    );

/// Layout ceiling: the longest plausible first name, the Figma lorem body, and
/// a year-old timestamp all at once.
///
/// The header `Row` gives the name column `Expanded` but leaves the trailing
/// "365 days ago" stamp unconstrained, so the stamp wins every squeeze and the
/// name is what gives. Neither the name nor the stamp sets `maxLines`. This is
/// the preview the AR RTL and 200%-text renderings exist for — the EN light
/// rendering still looks fine long after the other two have broken.
///
/// This is the worst case of defect 1 above: at 200% text the stamp alone
/// measures 293 px of a 318 px content row and is drawn past the card's right
/// border (right edge 382 vs a card ending at 370), clipped by the container's
/// `Clip.antiAlias`.
@JeebPreview(group: 'delivery_man_profile', name: 'Long name and body', size: _deliveryReviewCardTallBox)
Widget deliveryReviewCardLongContent() => _deliveryReviewCardHosted(
      const DeliveryReviewData(
        id: 'r-long',
        reviewerName: 'Abdulrahman Al-Muhandis',
        rating: 5,
        body: _deliveryReviewCardLorem,
        daysAgo: 365,
        reviewerAvatarUrl: 'https://i.pravatar.cc/150?img=33',
      ),
      index: 5,
    );
