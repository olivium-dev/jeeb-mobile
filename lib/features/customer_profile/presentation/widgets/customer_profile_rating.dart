import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

/// Per-role rating chip on the customer-profile header (JM-035 AC1, D6).
///
/// Always rendered (with the `customer_profile_rating` identifier) so the
/// Maestro presence assertion holds for every account — a rated account shows
/// "★ 4.9 · 312 Reviews", an unrated account shows a deterministic "No reviews
/// yet" state. The id is presence-only (i18n-safe); the value is never asserted.
///
/// Copy reuses the existing `deliveryManProfile*` rating keys (same rating-row
/// semantics) — no new ARB keys (l10n is integrator-owned). A dedicated
/// `customerProfileRating*` set is requested in `50_ROUTE_REQUESTS.md` for a
/// later copy-polish pass; Maestro keys on the identifier, not the text.
class CustomerProfileRating extends StatelessWidget {
  const CustomerProfileRating({
    super.key,
    required this.rating,
    required this.ratingCount,
  });

  final double? rating;
  final int ratingCount;

  bool get _hasRating => rating != null && ratingCount > 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final colorScheme = theme.colorScheme;

    final ratingText = (rating ?? 0).toStringAsFixed(1);
    final label = _hasRating
        ? l10n.deliveryManProfileRatingSummary(ratingText, ratingCount)
        : l10n.deliveryManProfileEmptyReviewsTitle;

    // Identifier-only + `container: true`, mirroring the proven
    // `DeliveryManMetaRow` pattern. A competing explicit `label` on this wrapper
    // fights the text-emitting child below for the accessible name, which folds
    // the `customer_profile_rating` identifier away when it merges up into the
    // header node (the name node then swallows it). `container: true` forces a
    // first-class node so the identifier survives; the visible `Text` already
    // exposes the rating summary as the readable label.
    return Semantics(
      identifier: 'customer_profile_rating',
      container: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _hasRating ? Icons.star_rounded : Icons.star_border_rounded,
            size: Sizes.large,
            color: colorScheme.primary,
          ),
          const SizedBox(width: Spacing.twoXSmall),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
// Render tests: test/previews/customer_profile/customer_profile_rating_preview_test.dart
// ===========================================================================

// Widget previews for [CustomerProfileRating] — run with
// `flutter widget-preview start`.
//
// The widget has no cubit and no repository: it is two fields of the getMe
// payload (`rating`, `ratingCount`) turned into one [Icon] and one [Text]. So
// there is no "loading" or "error" state to seed, and these previews are
// network-free because there is nothing to fetch, not merely because
// [jeebPreviewHost] guards the wire. Its real states are the shapes that
// payload arrives in — including the two the widget folds together — crossed
// with the host states the matrix renders (AR RTL, 200% text).
//
// The fixture values are the ones `test/customer_profile_screen_test.dart`
// already uses (4.9/312 rated, null/0 unrated), extended with the boundary
// payloads that test does not cover.
//
// Four things these previews surface, all in the widget or its copy rather
// than in the previews — see the notes on the individual states:
//
//  * the score appears at ONE review, while the sibling jeeber header hides it
//    until five (D59) using the very same ARB keys;
//  * `rating` and `ratingCount` are folded through a single `&&`, so a payload
//    carrying one without the other renders the cold-start copy and says
//    "No reviews yet" over an account that has reviews;
//  * the borrowed `deliveryManProfileRatingSummary` key has no plural form and
//    no number formatting in either locale — "1 Reviews", "1284" ungrouped;
//  * the star is a raw 20dp [Icon] that does not grow with text scale, and the
//    label it sits beside truncates rather than wraps, so the accessibility
//    ceiling silently eats the review count instead of showing it.

/// The width the chip actually gets inside `CustomerProfileHeader` on a 390pt
/// phone: `Spacing.xLarge` gutters on both sides, an `Sizes.eightXLarge` avatar
/// and a `Spacing.small` gap. `390 - 24 - 24 - 80 - 12 = 250`.
///
/// Pinned in the fixture rather than left to the canvas [Size], for the same
/// reason `jeeb_verified_badge`'s previews pin it: the canvas honours `size`,
/// but the render tests pump onto a fixed 800 × 600 surface, so a chip left to
/// fill its host would truncate on the phone and not truncate under test — the
/// state that breaks would break in only one of the two places it is looked at.
///
/// Applied as a `maxWidth`, not a fixed width, because production hands the chip
/// a LOOSE constraint (a [Column] child inside an [Expanded]) and the row is
/// `MainAxisSize.min`. Keeping it loose means the measured width of each preview
/// is the chip's own intrinsic width, which is what tells the long states apart
/// from the short ones.
const double _customerProfileRatingIdentityWidth = 250;

/// The same column on a 320pt phone (iPhone SE, small Android):
/// `320 - 24 - 24 - 80 - 12 = 180`. Used by the longest state, where the
/// smallest column and the longest label meet.
const double _customerProfileRatingSmallIdentityWidth = 180;

/// Canvas box for the chip: phone width, and tall enough for the 200% rendering
/// (a single 32pt line — this label truncates rather than wrapping).
const Size _customerProfileRatingChipBox = Size(390, 96);

/// Renders the chip under the constraint the profile header really gives it,
/// leading-aligned the way `CrossAxisAlignment.start` places it in the identity
/// column.
Widget _customerProfileRatingHosted({
  required double? rating,
  required int ratingCount,
  double width = _customerProfileRatingIdentityWidth,
}) =>
    Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: CustomerProfileRating(rating: rating, ratingCount: ratingCount),
      ),
    );

/// The state the widget was written for: an established customer, filled star,
/// "4.9 . 312 Reviews" (the exact pair named in the class doc comment).
///
/// Look at the separator in the EN light rendering. The doc comment on the
/// widget and the copy request in `50_ROUTE_REQUESTS.md` both write this as
/// "4.9 · 312", but the borrowed `deliveryManProfileRatingSummary` value is
/// `{rating} . {count}` — a full stop with a space on either side. What ships
/// reads "4.9 . 312 Reviews", which parses as a sentence break rather than as a
/// separator, and a screen reader announces it as one.
///
/// This is also the control for the truncation the other states hit: at 200%
/// text the label is 209pt of the 226pt the 250pt column leaves it, so English
/// survives the accessibility ceiling on a 390pt phone with about 17pt to spare.
@JeebPreview(
  group: 'customer_profile',
  name: 'Rated (production)',
  size: _customerProfileRatingChipBox,
)
Widget customerProfileRatingRated() =>
    _customerProfileRatingHosted(rating: 4.9, ratingCount: 312);

/// The state most accounts are actually in: the seeded customer carries no
/// rating at all, so `rating` is null and `ratingCount` is 0.
///
/// Outline star + "No reviews yet", and — the point of the widget — the
/// `customer_profile_rating` identifier is still emitted, so the Maestro
/// presence assertion in `.maestro/flows/jm-035-customer-profile.yaml` holds for
/// an account that has never been rated. Pinned in the render test by reading
/// the semantics node back, not just by the text.
///
/// Compare the EN 200% and AR RTL renderings: "لا توجد تقييمات بعد" is half
/// again as wide as "No reviews yet", and at 200% it is the one string in this
/// section that runs out of column on a full-size phone — the empty state, in
/// the locale half the users read, is where the chip truncates first.
@JeebPreview(
  group: 'customer_profile',
  name: 'Unrated (cold start)',
  size: _customerProfileRatingChipBox,
)
Widget customerProfileRatingUnrated() =>
    _customerProfileRatingHosted(rating: null, ratingCount: 0);

/// Reviews on file, no average computed — and the header denies both.
///
/// `_hasRating` is `rating != null && ratingCount > 0`, one boolean over two
/// independent fields of the getMe payload, and the false branch renders the
/// cold-start copy. A customer with 42 ratings whose average has not been
/// aggregated yet (or was dropped by a gateway serialization change — the same
/// class of drift the July contract fixes chased) is told "No reviews yet",
/// which is a stronger claim than "we don't have your score": it contradicts the
/// reviews the account demonstrably has.
///
/// The mirror payload (`rating: 4.8, ratingCount: 0`) collapses the same way,
/// silently discarding a score the server sent. Only one of the two is previewed
/// because they are pixel-identical — which is itself the finding.
@JeebPreview(
  group: 'customer_profile',
  name: 'Reviews, no average',
  size: _customerProfileRatingChipBox,
)
Widget customerProfileRatingCountWithoutAverage() =>
    _customerProfileRatingHosted(rating: null, ratingCount: 42);

/// One review, and the header presents it as a score.
///
/// Two defects share this frame:
///
///  * **D59.** `customer_profile_view_data.dart` documents `ratingCount` as
///    driving "the cold-start copy, D59-consistent". D59 is *hide the aggregate
///    score until N ≥ 5*, and the sibling `DeliveryManProfileHeader._RatingRow`
///    implements exactly that — under five reviews it drops the score and shows
///    `deliveryManProfileReviewsCount` instead. This widget shows the aggregate
///    from the first review, so the same account renders a confident "5.0" here
///    and no score at all on the jeeber surface, out of the same two ARB keys.
///  * **Plural.** The label reads "5.0 . 1 Reviews". `AppLocalizations` resolves
///    a key by `_get(...).replaceFirst('{count}', '$count')` — a literal
///    substitution with no ICU plural support — so this cannot be fixed by
///    writing a plural form into the ARB. Arabic has the same hole from the
///    other side: `{rating} . {count} تقييم` is the singular for every count.
@JeebPreview(
  group: 'customer_profile',
  name: 'Single review',
  size: _customerProfileRatingChipBox,
)
Widget customerProfileRatingSingleReview() =>
    _customerProfileRatingHosted(rating: 5.0, ratingCount: 1);

/// A genuinely badly-rated account: 0.0 across 3 ratings.
///
/// `_hasRating` is true, so this takes the SOLID `Icons.star_rounded` inked with
/// `colorScheme.primary` — the same filled, brand-coloured star the 4.9 account
/// gets. The icon encodes "has a score", the number encodes "the score is
/// zero", and at a glance the first reads louder than the second. Worth putting
/// beside [customerProfileRatingRated] in the canvas: nothing but the digits
/// distinguishes the best-rated account in the app from the worst.
@JeebPreview(
  group: 'customer_profile',
  name: 'Zero score, rated',
  size: _customerProfileRatingChipBox,
)
Widget customerProfileRatingZeroScore() =>
    _customerProfileRatingHosted(rating: 0.0, ratingCount: 3);

/// Longest plausible content in the narrowest column: a long-standing account,
/// 4.96 over 1284 ratings, on a 320pt phone (180pt of column).
///
/// Three defects in one frame:
///
///  * `(rating ?? 0).toStringAsFixed(1)` rounds 4.96 UP to "5.0", so an account
///    that is not perfect is presented as perfect — the one direction this
///    rounding must not go for a trust signal;
///  * the count is interpolated as `'$count'`, so it renders "1284" with no
///    grouping separator in English and with Western digits in Arabic, where the
///    rest of the label is Arabic script;
///  * at 200% text the label wants 224pt and the column has 156pt after the star
///    and its gap, so it is ellipsized — and because `Text` truncates the END of
///    the string, what is cut is the review count, leaving a bare score with no
///    idea how many ratings back it. The same string clears the 390pt column
///    with 2pt to spare, so this failure is invisible on a test device that
///    happens to be big.
@JeebPreview(
  group: 'customer_profile',
  name: 'Longest plausible (small phone)',
  size: _customerProfileRatingChipBox,
)
Widget customerProfileRatingLongest() => _customerProfileRatingHosted(
      rating: 4.96,
      ratingCount: 1284,
      width: _customerProfileRatingSmallIdentityWidth,
    );
