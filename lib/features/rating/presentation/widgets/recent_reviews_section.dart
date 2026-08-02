import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

class RecentReviewPreview {
  const RecentReviewPreview({
    required this.userName,
    required this.rating,
    required this.reviewText,
    required this.timeAgo,
    this.userImageUrl,
    this.isVerifiedPurchase = false,
  });

  final String userName;
  final double rating;
  final String reviewText;
  final String timeAgo;
  final String? userImageUrl;
  final bool isVerifiedPurchase;
}

class RecentReviewsSection extends StatelessWidget {
  const RecentReviewsSection({
    super.key,
    required this.reviews,
    this.onViewAllTap,
    this.maxItems = 3,
    this.title = 'Reviews',
    this.viewAllText = 'View all',
  });

  final List<RecentReviewPreview> reviews;
  final VoidCallback? onViewAllTap;
  final int maxItems;
  final String title;
  final String viewAllText;

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) return const SizedBox.shrink();
    final visible = reviews.take(maxItems).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReviewsHeader(
          title: title,
          count: reviews.length,
          viewAllText: viewAllText,
          onViewAllTap: onViewAllTap,
        ),
        const SizedBox(height: Spacing.xSmall),
        for (final review in visible) _ReviewCardItem(review: review),
      ],
    );
  }
}

class _ReviewsHeader extends StatelessWidget {
  const _ReviewsHeader({
    required this.title,
    required this.count,
    required this.viewAllText,
    required this.onViewAllTap,
  });

  final String title;
  final int count;
  final String viewAllText;
  final VoidCallback? onViewAllTap;

  @override
  Widget build(BuildContext context) {
    return OmdsSectionHeader(
      title: '$title ($count)',
      showAllText: viewAllText,
      onShowAllTap: onViewAllTap,
      showShowAll: onViewAllTap != null,
    );
  }
}

class _ReviewCardItem extends StatelessWidget {
  const _ReviewCardItem({required this.review});

  final RecentReviewPreview review;

  @override
  Widget build(BuildContext context) {
    return OmdsReviewCard(
      userName: review.userName,
      rating: review.rating,
      reviewText: review.reviewText,
      timeAgo: review.timeAgo,
      userImageUrl: review.userImageUrl,
      isVerifiedPurchase: review.isVerifiedPurchase,
      showActions: false,
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
// Render tests: test/previews/rating/recent_reviews_section_preview_test.dart
// ===========================================================================
//
// Widget previews for [RecentReviewsSection] — run with
// `flutter widget-preview start`.
//
// The section is a pure props widget: a `List<RecentReviewPreview>` in, an
// [OmdsSectionHeader] over N [OmdsReviewCard]s out. There is no cubit and no
// repository to stub — `RatingsRepository` does not exist yet
// (`T-MOB-RATING-001`, see the doc on [RecentReviewPreview]) — so every state
// below is network-free by construction rather than by the guard in
// [jeebPreviewHost]. The one exception is the avatar URL on the happy path,
// which is deliberate: [OmdsProfileAvatar] paints its initial placeholder
// whenever the image has not loaded, and that placeholder is what the canvas
// and the tests should see.
//
// Nothing in `lib/` constructs this widget yet — grep says the only callers are
// the previews below. That makes the canvas the ONLY place it is currently
// looked at, and it is why these states are chosen for where the section gives
// way rather than for how it looks with three tidy reviews.
//
// FIVE DEFECTS THESE PREVIEWS EXPOSE, all in the widget (or the OMDS card it
// delegates to) and none fixed here — previews are additive, the shipping half
// of this file is untouched:
//
// 1. **Both header strings are hardcoded English defaults.** `title:
//    'Reviews'` and `viewAllText: 'View all'` are constructor defaults, not ARB
//    lookups, so the section renders English in Arabic unless every caller
//    remembers to pass both — and there are no callers yet to copy from. The
//    keys already exist: `deliveryManProfileReviewsTitle` ("التقييمات") and
//    `deliveryManProfileViewAllReviews` ("عرض الكل"). Worse,
//    `OmdsReviewCard.verifiedPurchaseLabel` is not exposed by this widget at
//    all, so the verified badge is UNREACHABLE English — "Verified Purchase"
//    with no override, next to `reviewerVerifiedBadge` ("عميل موثّق") sitting
//    unused in the ARB. [recentReviewsSectionArabicReviewer] is that state.
//
// 2. **The header counts what it does not show.** `count: reviews.length`
//    while only `maxItems` cards are built, so a jeeber with twelve reviews
//    gets "Reviews (12)" over three cards — see
//    [recentReviewsSectionTruncated]. Defensible when the "View all" CTA is
//    there to absorb the difference; with `onViewAllTap == null` the header
//    still promises twelve and the header's own CTA is suppressed
//    (`showShowAll: onViewAllTap != null`), leaving no route to the other nine.
//
// 3. **A non-Latin reviewer name gets a "?" avatar.**
//    `OmdsReviewCard._buildUserAvatar` derives its initial through
//    `RegExp(r'[a-zA-Z]')` and falls back to "?" for everything else. This is
//    the exact defect `DeliveryReviewCard` works around by building
//    [OmdsProfileAvatar] itself (see its comment at the header row);
//    [RecentReviewsSection] delegates to the OMDS card wholesale and so
//    inherits it. Every Arabic-named reviewer is anonymised into a "?".
//
// 4. **The card's header Row has no give, and `timeAgo` is a free-form
//    String.** The trailing stamp is neither `Flexible` nor `maxLines`-capped,
//    so it is laid out at its full intrinsic width and the `Expanded` name
//    column absorbs every squeeze. At 200% text on a phone the row overflows —
//    the same defect the `DeliveryReviewCard` previews pin, reached here
//    through a different caller. [recentReviewsSectionLongContent] is the state
//    that shows it.
//
//    It is worse here than there, because `RecentReviewPreview.timeAgo` is an
//    unformatted `String` with no contract: whatever the mapping at the screen
//    boundary produces goes straight into the row. The 25-character
//    "11 months and 3 weeks ago" this preview was first written with measures
//    310 px of the 318 px content row at ONE-TO-ONE text scale — a 44 px
//    overflow, with the `Expanded` name column handed ZERO width, so
//    "Abdulrahman Al-Muhandis Al-Trabulsi" wraps to a column of single
//    characters. The fixture below uses
//    "365 days ago" — the longest stamp the shipping formatters can actually
//    emit (`ReviewsL10n.relativeTime` tops out at `"{d}d ago"`,
//    `reviewRelativeDaysAgo` at "365 days ago") — so the preview shows the
//    real 200% ceiling rather than a fixture the app could not produce. A
//    caller that spells its own timestamps out in words breaks this row on the
//    DEFAULT rendering, and nothing in the type stops one.
//
// 5. **The stars are OMDS gold, not the brand.** `_ReviewCardItem` passes no
//    `starColor`, so the cards paint `const Color(0xFFFFB800)` while the two
//    review surfaces that actually ship (`ReviewRow`,`DeliveryReviewCard`)
//    both pass `colorScheme.primary`. Three review widgets, two star colours.
//
// A sixth, smaller one is only visible in the `AR RTL dark` renderings: the
// OMDS star row spaces itself with `EdgeInsets.only(right:)` rather than
// `EdgeInsetsDirectional.only(end:)`, so in Arabic the 2pt gaps sit on the
// leading side of each star and the row's spare pixel lands under the wrong
// edge. `DeliveryReviewCard._ReviewStars` already uses the directional form.
//
// **About the caption.** [recentReviewsSectionEmpty] renders NOTHING — that is
// its whole contract — so `find.text` has nothing of the widget's to address it
// by, and a render test could pass while it silently drew a full section. It
// therefore carries a one-line caption used by the test only to *reach* it; the
// assertion that proves the state is the measured zero height in
// `test/previews/rating/recent_reviews_section_preview_test.dart`. The five
// production states carry no caption.

/// The phone the rating surfaces are drawn for.
///
/// Pinned as a real [SizedBox] rather than left to the canvas [Size]: the canvas
/// honours `size`, but the render tests pump onto a fixed 800 x 600 surface, so
/// a section left to fill its host would wrap on the phone and not wrap under
/// test — the state that breaks would only break in one of the two places it is
/// looked at.
const double _recentReviewsSectionPhoneWidth = 390;

/// The horizontal gutter a rating screen gives its content column, restated
/// from `rating_screen.dart` so the section gets the `390 - 40 = 350`pt it
/// really has rather than the full canvas width.
const double _recentReviewsSectionGutter = Spacing.large;

/// Canvas box for the three-card feed: header + 3 cards.
///
/// Every box below is sized from what the section actually MEASURES at 390
/// logical px and 1.0 text scale (528, 76, 215, 490, 406 px of content plus the
/// host's 32 px of vertical padding), not guessed. The `EN 200% text` rendering
/// of the matrix states runs past them by design — the host scrolls, and a box
/// stretched to fit 200% would leave every other rendering floating in dead
/// space.
const Size _recentReviewsSectionFeedBox = Size(390, 540);

/// A single card plus its header (215 px measured).
const Size _recentReviewsSectionSingleBox = Size(390, 230);

/// The empty state collapses to nothing; the box only has to hold the caption.
const Size _recentReviewsSectionEmptyBox = Size(390, 120);

/// Two cards of Arabic content (406 px measured).
const Size _recentReviewsSectionArabicBox = Size(390, 430);

/// The longest plausible review: a wrapped name over a four-line body
/// (490 px measured).
const Size _recentReviewsSectionTallBox = Size(390, 520);

/// The Figma comp's review body, as `DevDeliveryManProfileFixtures` spells it —
/// the longest body any review surface in this app is drawn with.
const String _recentReviewsSectionLorem =
    'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed ut leo '
    'facilisis, mollis dolor bibendum, tempor dolor. Lorem ipsum dolor sit '
    'amet, consectetur adipiscing elit.';

/// Three reviews as feedback-service would hand them over, using the names and
/// scores the existing review tests already use
/// (`test/delivery_man_profile_screen_test.dart`: "Karl Assaf", 4 stars,
/// "2 days ago"; the half-star and 3-star fixtures from the
/// `DeliveryReviewCard` previews).
const List<RecentReviewPreview> _recentReviewsSectionFeed =
    <RecentReviewPreview>[
  RecentReviewPreview(
    userName: 'Karl Assaf',
    rating: 4,
    reviewText: 'Great delivery, fast and friendly.',
    timeAgo: '2 days ago',
    userImageUrl: 'https://i.pravatar.cc/150?img=15',
    isVerifiedPurchase: true,
  ),
  RecentReviewPreview(
    userName: 'Rami Khoury',
    rating: 4.5,
    reviewText: 'Arrived on time, but the bag was a little squashed.',
    timeAgo: '12 days ago',
  ),
  RecentReviewPreview(
    userName: 'Nadia Chehab',
    rating: 5,
    reviewText: '',
    timeAgo: '3 weeks ago',
  ),
];

/// Twelve reviews — what a jeeber with a few months on the platform has, and
/// four times what the section will draw.
List<RecentReviewPreview> _recentReviewsSectionHistory() =>
    <RecentReviewPreview>[
      ..._recentReviewsSectionFeed,
      for (int week = 4; week <= 12; week++)
        RecentReviewPreview(
          userName: 'Client $week',
          rating: 4,
          reviewText: 'Older review from $week weeks ago.',
          timeAgo: '$week weeks ago',
        ),
    ];

/// Hosts the section the way a rating screen does: a fixed-width phone, the
/// screen's horizontal gutters, a [SingleChildScrollView], and a
/// `CrossAxisAlignment.stretch` [Column].
///
/// None of that is decoration.
///
///  * The **scroll view** is what makes the 200% rendering honest. It hands its
///    child unbounded height, so the section's own `Column` — which leaves
///    `mainAxisSize` at [MainAxisSize.max] — shrink-wraps instead of swelling
///    to fill the canvas and pinning three cards to the top of it. Drop the
///    section straight into a bounded parent and every state looks identically
///    tall.
///  * The **stretch** gives it the full `width - 40` content column. Without it
///    the section shrink-wraps to its own glyphs and the header's
///    title/"View all" `Row` never has to make its trailing-edge decision.
Widget _recentReviewsSectionHosted(
  Widget child, {
  double width = _recentReviewsSectionPhoneWidth,
  String? caption,
}) => Align(
      alignment: AlignmentDirectional.topStart,
      child: SizedBox(
        width: width,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: _recentReviewsSectionGutter,
            vertical: Spacing.medium,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              child,
              if (caption != null) ...<Widget>[
                const SizedBox(height: Spacing.small),
                Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

/// The state a rating screen is designed around: three recent reviews under a
/// counted header, with the "View all" CTA wired.
///
/// Read it for the three things only the full feed shows: the OMDS card's
/// hairline divider repeating between entries (and, at the bottom, under the
/// last one, where there is nothing to separate it from), the verified badge
/// pushing the first card's header row taller than its neighbours, and the
/// third card's empty body collapsing the card to its header — three visibly
/// different card heights from one uniform list.
///
/// The stars here are `#FFB800` gold, not the brand orange the two shipping
/// review surfaces use (defect 5 above).
@JeebPreview(
  group: 'rating',
  name: 'Three reviews, view all',
  size: _recentReviewsSectionFeedBox,
)
Widget recentReviewsSectionThreeReviews() => _recentReviewsSectionHosted(
      RecentReviewsSection(
        reviews: _recentReviewsSectionFeed,
        onViewAllTap: () {},
      ),
    );

/// The empty state, which is the one a parent is most likely to get wrong.
///
/// [RecentReviewsSection] returns `SizedBox.shrink()` for an empty list — no
/// header, no "No reviews yet", no space. That is a deliberate contract ("the
/// parent can use it unconditionally") and it is also a trap: a rating screen
/// that stacks this between two spaced siblings gets a doubled gap and no
/// explanation of why the reviews block vanished. The ARB already carries
/// `deliveryManProfileEmptyReviewsTitle` / `…Subtitle` for the surface that
/// does render an empty state.
///
/// The outline is drawn only so the collapse is visible; the caption is how the
/// render test addresses a state that puts no text of its own on screen.
@JeebPreview(
  group: 'rating',
  name: 'Empty (renders nothing)',
  size: _recentReviewsSectionEmptyBox,
)
Widget recentReviewsSectionEmpty() => _recentReviewsSectionHosted(
      Builder(
        builder: (BuildContext context) => DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: const RecentReviewsSection(
            reviews: <RecentReviewPreview>[],
          ),
        ),
      ),
      caption: 'Empty list — the section collapses to zero height',
    );

/// Defect 2 above, made visible: twelve reviews, three cards, one header that
/// says "Reviews (12)".
///
/// The count is `reviews.length` and the cards are `reviews.take(maxItems)`, so
/// the header is a promise the block does not keep on its own. Here the "View
/// all" CTA is wired, which is the arrangement that makes it defensible — the
/// nine missing reviews are one tap away. Compare
/// [recentReviewsSectionNoViewAll], where they are not.
@JeebPreview(
  group: 'rating',
  name: 'Twelve reviews, three shown',
  size: _recentReviewsSectionFeedBox,
)
Widget recentReviewsSectionTruncated() => _recentReviewsSectionHosted(
      RecentReviewsSection(
        reviews: _recentReviewsSectionHistory(),
        onViewAllTap: () {},
      ),
    );

/// No `onViewAllTap`, so the header suppresses its own CTA
/// (`showShowAll: onViewAllTap != null`) and collapses to a bare counted title.
///
/// Worth its own preview for two reasons. The title is `Expanded`, so with the
/// CTA gone it silently takes the full width — nothing here proves the header
/// still reads as a header rather than as a stray headline. And this is the
/// half of defect 2 with no escape hatch: paired with a list longer than
/// `maxItems` it renders a count the user cannot act on. A single review is the
/// honest use of this configuration.
@JeebPreview(
  group: 'rating',
  name: 'No view-all CTA',
  size: _recentReviewsSectionSingleBox,
)
Widget recentReviewsSectionNoViewAll() => _recentReviewsSectionHosted(
      const RecentReviewsSection(
        reviews: <RecentReviewPreview>[
          RecentReviewPreview(
            userName: 'Tarek Aoun',
            rating: 3,
            reviewText: 'Took a while to find the building.',
            timeAgo: '30 days ago',
          ),
        ],
      ),
    );

/// Layout ceiling: the longest plausible name, the Figma lorem body, a
/// year-old stamp and the verified badge, all in one card.
///
/// This is the preview the matrix is for. The card's header `Row` gives the
/// name column `Expanded` but leaves the trailing stamp unconstrained and
/// uncapped, so the stamp wins every squeeze and the name is what gives —
/// invisible in the `EN light` rendering, an overflow in `EN 200% text`
/// (defect 4). The `AR RTL dark` rendering is where the header's
/// title/CTA `Row` and the card's avatar/stamp `Row` have to mirror together,
/// and where the OMDS star row's non-directional padding shows.
@JeebPreview(
  group: 'rating',
  name: 'Long name and body',
  size: _recentReviewsSectionTallBox,
  matrix: true,
)
Widget recentReviewsSectionLongContent() => _recentReviewsSectionHosted(
      RecentReviewsSection(
        reviews: const <RecentReviewPreview>[
          RecentReviewPreview(
            userName: 'Abdulrahman Al-Muhandis Al-Trabulsi',
            rating: 5,
            reviewText: _recentReviewsSectionLorem,
            timeAgo: '365 days ago',
            isVerifiedPurchase: true,
          ),
        ],
        onViewAllTap: () {},
      ),
    );

/// An Arabic reviewer, which is the majority case in Lebanon and the state
/// defects 1 and 3 both land on.
///
/// Two things to look for, and both are widget defects rather than fixture
/// artefacts:
///
///  * The avatar reads **"?"**. `OmdsReviewCard` derives its initial with
///    `RegExp(r'[a-zA-Z]')` and has no branch for Arabic, so every Arabic-named
///    reviewer is anonymised. `DeliveryReviewCard` avoids this by not using the
///    OMDS card's avatar at all.
///  * The chrome stays **English** — "Reviews (2)", "View all" and "Verified
///    Purchase" — around Arabic content, in BOTH the EN and the AR RTL
///    renderings, because all three are hardcoded defaults rather than ARB
///    lookups. The AR rendering is the one that makes it obvious: mirrored
///    layout, Arabic reviews, English furniture.
@JeebPreview(
  group: 'rating',
  name: 'Arabic reviewer',
  size: _recentReviewsSectionArabicBox,
  matrix: true,
)
Widget recentReviewsSectionArabicReviewer() => _recentReviewsSectionHosted(
      RecentReviewsSection(
        reviews: const <RecentReviewPreview>[
          RecentReviewPreview(
            userName: 'ليلى الحاج',
            rating: 5,
            reviewText: 'وصل الطلب بسرعة والسائق كان لطيفاً جداً.',
            timeAgo: '2 days ago',
            isVerifiedPurchase: true,
          ),
          RecentReviewPreview(
            userName: 'عبد الرحمن المهندس',
            rating: 4,
            reviewText: 'تأخر قليلاً بسبب الزحمة لكن الطلب وصل سليماً.',
            timeAgo: '5 days ago',
          ),
        ],
        onViewAllTap: () {},
      ),
    );
