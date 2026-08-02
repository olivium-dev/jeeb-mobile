/// Widget previews for [DeliveryReviewsList] — run with
/// `flutter widget-preview start`.
///
/// The widget owns no state: it takes a `List<DeliveryReviewData>` and either
/// renders it through `DeliveryReviewCard`s or swaps the whole list for an
/// `OmdsEmptyState`. There is no cubit and no repository, so every state below
/// is network-free by construction rather than by the guard in
/// `jeebPreviewHost` — and the single preview that carries a
/// `reviewerAvatarUrl` is the anonymous one, where the card is *required* to
/// throw the URL away before it reaches an image loader.
///
/// Fixture values are lifted from the tests that already assert this contract
/// (`test/delivery_man_profile_screen_test.dart`,
/// `test/features/delivery_man_profile/delivery_review_card_a11y_test.dart`)
/// and the Figma seed in `DevDeliveryManProfileFixtures`, so a preview and a
/// failing test describe the same review.
///
/// Every preview pins its own width with a [SizedBox]. The canvas honours the
/// annotation's `size`, but the render tests in `test/previews/` pump onto a
/// fixed 800 × 600 surface, so a state that only asked for a 390 pt canvas
/// would lay out at 800 pt under test — and 800 pt is exactly wide enough to
/// hide the finding below.
///
/// Each preview is wrapped in a [SingleChildScrollView] because the live parent
/// (`_DeliveryManProfileBody`) is a [ListView] and this list is shrink-wrapped
/// and non-scrollable inside it. Vertical growth is therefore normal here, not
/// a defect; anything that overflows *horizontally* inside a card is real.
///
/// ## What these previews surface
///
/// Both problems are in `DeliveryReviewCard`, not in the list, and both are
/// invisible in the EN-light rendering — measured in the preview render
/// harness, whose test font is monospaced, so treat the pixel figures as the
/// shape of the problem rather than as device-exact.
///
///  * **At 200% text the reviewer's name is squeezed out of existence.** The
///    card header is `Row(avatar, gap, Expanded(name/badge/stars), Text(daysAgo))`
///    and the relative timestamp has no [Flexible] around it, so it takes its
///    full natural width and the [Expanded] column pays for all of it. On a
///    390 pt card the timestamp grows 149 pt → 293 pt between 1× and 2× while
///    the name column collapses from 115 pt to **zero**, and the row overflows
///    its trailing edge. Open the EN 200% rendering of
///    [deliveryReviewsListYearOld]; it is pinned in this preview's render test.
///  * **The stars do not scale with text at all.** `_ReviewStars` builds
///    `Icon(..., size: Sizes.small)` with no `applyTextScaling`, so the five
///    stars measure 12 × 12 at 1× *and* at 2×. A user who has doubled their
///    text size gets a review card of 24 pt type wrapped around a 12 pt rating
///    — the one element on the card that carries the score.
///
/// RTL itself is clean: the list padding is [EdgeInsetsDirectional], the star
/// gaps are `EdgeInsetsDirectional.only(end:)`, and the AR renderings mirror
/// properly.
library;

import 'package:flutter/material.dart';

import '../../features/delivery_man_profile/domain/delivery_man_profile_view_data.dart';
import '../../features/delivery_man_profile/presentation/widgets/delivery_reviews_list.dart';
import '../harness/jeeb_preview.dart';

/// A typical phone — the width screen 27 is designed against.
const double _phoneWidth = 390;

/// Canvas boxes, sized to the state each one holds.
const Size _twoCardBox = Size(_phoneWidth, 320);
const Size _oneCardBox = Size(_phoneWidth, 200);
const Size _starsOnlyBox = Size(_phoneWidth, 180);
const Size _emptyBox = Size(_phoneWidth, 320);
const Size _longBodyBox = Size(_phoneWidth, 280);

/// The Figma seed body (`DevDeliveryManProfileFixtures`) — the longest review
/// copy the design was drawn against.
const String _lorem =
    'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed ut leo '
    'facilisis, mollis dolor bibendum, tempor dolor. Lorem ipsum dolor sit '
    'amet, consectetur adipiscing elit.';

DeliveryReviewData _review({
  required String id,
  required String reviewerName,
  required String body,
  double rating = 4,
  int daysAgo = 2,
  bool isVerified = true,
  String? reviewerAvatarUrl,
}) => DeliveryReviewData(
  id: id,
  reviewerName: reviewerName,
  rating: rating,
  body: body,
  daysAgo: daysAgo,
  isVerified: isVerified,
  reviewerAvatarUrl: reviewerAvatarUrl,
  // Retained on the model, never rendered (D57) — carried here so a regression
  // that resurrects the Helpful control shows up as "Helpful (24)".
  helpfulCount: 24,
);

/// One list, hosted the way `_DeliveryManProfileBody` hosts it.
///
/// No preview pins a [TextScaler]: the 200% state of this widget *overflows*,
/// and `testPreviewsRender` asserts that every preview builds cleanly. Pinning
/// 2× into the tree would turn the shared suite red for a defect it does not
/// own, so the render test applies the scale externally instead — and the
/// canvas gets its EN 200% rendering from [JeebPreview] regardless.
Widget _hosted(List<DeliveryReviewData> reviews) {
  return Align(
    alignment: AlignmentDirectional.topStart,
    child: SizedBox(
      width: _phoneWidth,
      // Mirrors the live ListView parent: the list is shrink-wrapped and
      // non-scrollable, so vertical growth scrolls rather than overflowing.
      child: SingleChildScrollView(
        child: DeliveryReviewsList(reviews: reviews),
      ),
    ),
  );
}

/// The default surface: the two-review list the Figma comp and
/// `delivery_man_profile_screen_test.dart` both render.
///
/// The baseline worth keeping because it is the only state that exercises the
/// [ListView.separated] separator and the D58 first-name rule side by side —
/// "Karl Assaf" and "Nour Haddad" must render as "Karl" and "Nour", never with
/// their family names attached.
@JeebPreview(name: 'Two reviews', size: _twoCardBox)
Widget deliveryReviewsListTwoReviews() => _hosted(<DeliveryReviewData>[
  _review(
    id: 'r1',
    reviewerName: 'Karl Assaf',
    body: 'Great delivery, fast and friendly.',
  ),
  _review(
    id: 'r2',
    reviewerName: 'Nour Haddad',
    rating: 5,
    body: 'Arrived early and called ahead.',
    daysAgo: 9,
  ),
]);

/// The other half of the widget: `reviews.isEmpty` replaces the list entirely
/// with `OmdsEmptyState` rather than rendering a zero-height [ListView].
///
/// A real production state — a newly approved jeeber has no reviews at all, and
/// D59 cold-start means the profile above it is also hiding its aggregate score
/// — and the one most likely to be broken silently, because it is the branch a
/// happy-path-only preview never renders.
@JeebPreview(name: 'Empty', size: _emptyBox)
Widget deliveryReviewsListEmpty() => _hosted(const <DeliveryReviewData>[]);

/// Longest plausible content: the Figma seed body on a single card.
///
/// The body is an unconstrained [Text] with no `maxLines`, so it wraps
/// indefinitely — three lines at 1×, eight-plus at the 200% ceiling. That is
/// correct here (the parent scrolls), and this preview exists so the wrap point
/// and the 1.5 line-height stay reviewable without booting the app. Contrast it
/// with [deliveryReviewsListYearOld], where growth in the *header* is not
/// absorbed by anything.
@JeebPreview(name: 'Long body', size: _longBodyBox)
Widget deliveryReviewsListLongBody() => _hosted(<DeliveryReviewData>[
  _review(id: 'r1', reviewerName: 'Maroun Khoury', body: _lorem),
]);

/// Privacy regression guard, made visible
/// (`delivery_review_card_a11y_test.dart`).
///
/// A review whose client name is blank must attribute to the localized
/// "Jeeb customer" and show the neutral "J" initial — never a bare "?", and
/// never the client's own avatar. The card drops `reviewerAvatarUrl` for
/// exactly this case, which is why passing a URL here is still network-free: if
/// this preview ever renders an image, the suppression has broken and a private
/// photo is being shown next to an anonymised name.
@JeebPreview(name: 'Anonymous reviewer', size: _oneCardBox)
Widget deliveryReviewsListAnonymous() => _hosted(<DeliveryReviewData>[
  _review(
    id: 'anonymous',
    reviewerName: '   ',
    body: 'Great delivery.',
    reviewerAvatarUrl: 'https://example.com/private-avatar.png',
  ),
]);

/// A star-only review from an unverified client: `body` is empty and
/// `isVerified` is false, so two of the card's three optional blocks are gone.
///
/// Both are bare `if`s in `_ReviewCardBody`, and together they cut the card down
/// to its header row — the state where a stray gap shows up as visible dead
/// space and where the card is at its least tall against a fixed 40 pt avatar.
/// The 3.5 rating also drives the `star_half` branch of `_ReviewStars`, which no
/// other preview reaches.
@JeebPreview(name: 'Stars only', size: _starsOnlyBox)
Widget deliveryReviewsListStarsOnly() => _hosted(<DeliveryReviewData>[
  _review(
    id: 'r1',
    reviewerName: 'Rania Sfeir',
    rating: 3.5,
    body: '',
    daysAgo: 30,
    isVerified: false,
  ),
]);

/// Layout ceiling: a year-old review from a long-named client — the widest
/// header the model can produce at phone width.
///
/// **This is the preview to open, and the rendering to open is EN 200% text.**
/// At 1× it is unremarkable, which is the whole point: the header only fails
/// once the relative timestamp gets long. `reviewRelativeDaysAgo` has no upper
/// bound (the gateway returns the real age, and Arabic renders it longer), and
/// the timestamp [Text] is the one child of the header row with no [Flexible]
/// around it. It therefore takes its natural width and the [Expanded] name
/// column absorbs the entire deficit: 115 pt → 0 pt between 1× and 2×, with the
/// row overflowing its trailing edge. The reviewer's name and the "Verified
/// Client" badge disappear; the timestamp does not.
///
/// Pinned as a defect in this preview's render test — delete that test when the
/// timestamp learns to yield.
@JeebPreview(name: 'Year-old review', size: _oneCardBox)
Widget deliveryReviewsListYearOld() => _hosted(<DeliveryReviewData>[
  _review(
    id: 'r1',
    reviewerName: 'Abdulrahman Al-Muhandis',
    rating: 5,
    body: 'Handled a bulky order without a scratch.',
    daysAgo: 365,
  ),
]);
