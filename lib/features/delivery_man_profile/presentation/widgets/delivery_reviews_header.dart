import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';
import '../../domain/delivery_man_profile_view_data.dart';
import 'delivery_reviews_list.dart';

/// "Reviews" heading + (count · View all) row above the review list
/// (design §2). "View all" uses an [OmdsPrimaryButton] text variant so it is
/// not a raw Material button while still reading as a text affordance; brand
/// primary color comes from the theme (design flag §9.3 — not the un-themed
/// Figma template color).
class DeliveryReviewsHeader extends StatelessWidget {
  const DeliveryReviewsHeader({
    super.key,
    required this.reviewCount,
    required this.onViewAll,
  });

  final int reviewCount;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.large,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ReviewsTitle(),
          const SizedBox(height: Spacing.xSmall),
          _CountAndViewAll(reviewCount: reviewCount, onViewAll: onViewAll),
        ],
      ),
    );
  }
}

class _ReviewsTitle extends StatelessWidget {
  const _ReviewsTitle();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Text(
      l10n.deliveryManProfileReviewsTitle,
      style: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _CountAndViewAll extends StatelessWidget {
  const _CountAndViewAll({required this.reviewCount, required this.onViewAll});

  final int reviewCount;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            l10n.deliveryManProfileReviewsCount(reviewCount),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
        ),
        _ViewAllButton(label: l10n.deliveryManProfileViewAllReviews, onTap: onViewAll),
      ],
    );
  }
}

class _ViewAllButton extends StatelessWidget {
  const _ViewAllButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Canonical id per JM-067 AC + seam harness W4 (`profile_view_all_reviews`).
    return Semantics(
      identifier: 'profile_view_all_reviews',
      button: true,
      child: OmdsPrimaryButton(
        key: const Key('delivery-man-profile-view-all'),
        text: label,
        onTap: onTap,
        variant: OmdsButtonVariant.text,
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
// Render tests: test/previews/delivery_man_profile/delivery_reviews_header_preview_test.dart
// ===========================================================================

// Widget previews for [DeliveryReviewsHeader] — run with
// `flutter widget-preview start`.
//
// The widget owns no state: one `int reviewCount` and one `VoidCallback`. No
// cubit, no repository, so every state below is network-free by construction
// rather than by the guard in `jeebPreviewHost`. The `onViewAll` callbacks are
// deliberately inert — the production one pushes the `reviews-list` route
// (JM-068), which a preview has neither a router nor a reason for.
//
// `reviewCount` is the only input, so the states worth reviewing are the
// *counts* the gateway can actually produce, and the widths/scales they are
// produced at. Fixture counts are lifted from the tests that already assert
// this screen (`test/delivery_man_profile_screen_test.dart` uses 113, 3 and 0)
// rather than invented.
//
// Every preview pins its own width with a [SizedBox], and the one about text
// scale pins its own [TextScaler]. The canvas honours the annotation's `size`,
// but the render tests in `test/previews/` pump onto a fixed 800 × 600 surface
// — a 320 pt state that only asked for a 320 pt canvas would lay out at 800 pt
// under test and silently stop being the state under review.
//
// What is worth looking at, and what these previews already caught:
//
// * **"1 Reviews".** `deliveryManProfileReviewsCount` is `"{count} Reviews"`
//   with a plain `int` placeholder, and the generated accessor is a
//   `replaceFirst('{count}', '$count')` — not an ICU plural. A jeeber with one
//   review is labelled "1 Reviews"; Arabic gets "1 تقييم" for every count,
//   including the 3–10 band that needs `تقييمات`. See
//   [deliveryReviewsHeaderSingleReview].
//
// * **Ink roles.** The title paints with `colorScheme.secondaryContainer` — a
//   *container* role, i.e. a fill meant to sit BEHIND ink; `app_theme.dart`
//   says as much in its own words. It survives in light only because the light
//   scheme hard-codes that role to the brand navy. In dark
//   (`ColorScheme.fromSeed(_jeebNavy, dark)`) it resolves to a dark container
//   tone on a surface of nearly the same tone — under 3:1. The count line
//   below it has the mirror-image problem: it inks with
//   `onSecondaryContainer`, a colour chosen to sit ON that navy fill, but
//   paints it on the plain `surface` instead — muted purple `#777FC0` on
//   white, **3.76:1**, under the 4.5:1 AA floor for 14 pt body text. Both
//   numbers are pinned in this preview's render test. `JeebVerifiedBadge` and
//   `CustomerProfileSectionHeader` ink with the same container role and their
//   preview tests pin the same gap.
//
// * **The count/button split.** The count is [Flexible]; the "View all"
//   button is not. `OmdsPrimaryButton` defaults to `width: null`, so it takes
//   its intrinsic width first and the count is left whatever remains — which
//   is the right priority (the affordance must stay reachable) but means the
//   count is the thing that degrades. It has no `maxLines` and no `overflow`,
//   so it degrades by wrapping. See [deliveryReviewsHeaderNarrowLargeText].

/// A typical phone — the width screen 27 is designed against.
const double _deliveryReviewsHeaderPhoneWidth = 390;

/// The narrowest width the app still has to survive (iPhone SE 1st gen and the
/// small Android estate).
const double _deliveryReviewsHeaderNarrowPhoneWidth = 320;

/// Canvas boxes. The header is a title line + 8 + a 48 pt button row, so the
/// default box is short and wide; the scaled and composed states need room.
const Size _deliveryReviewsHeaderBox = Size(_deliveryReviewsHeaderPhoneWidth, 130);
const Size _deliveryReviewsHeaderLargeTextBox = Size(_deliveryReviewsHeaderPhoneWidth, 300);
const Size _deliveryReviewsHeaderWithListBox = Size(_deliveryReviewsHeaderPhoneWidth, 420);

/// One header, hosted the way `_DeliveryManProfileBody` hosts it: full width
/// inside the page's [ListView].
///
/// [width] and [textScale] are pinned into the tree rather than left to the
/// canvas so the canvas and the render tests lay the widget out identically.
/// [below] composes whatever the live page puts under the header, for the
/// states whose defect is spatial rather than local.
Widget _deliveryReviewsHeaderHosted(
  int reviewCount, {
  double width = _deliveryReviewsHeaderPhoneWidth,
  double? textScale,
  Widget? below,
}) {
  final Widget column = Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      DeliveryReviewsHeader(
        reviewCount: reviewCount,
        // Inert on purpose: the production callback pushes the `reviews-list`
        // route, so a real one would need a router the preview must not build.
        onViewAll: () {},
      ),
      ?below,
    ],
  );

  final Widget sized = Align(
    alignment: AlignmentDirectional.topStart,
    child: SizedBox(
      width: width,
      // Mirrors the live parent: the header sits in a scrolling ListView, so
      // vertical growth scrolls rather than overflowing. Anything that
      // overflows *horizontally* here is real.
      child: SingleChildScrollView(child: column),
    ),
  );

  if (textScale == null) return sized;
  return Builder(
    builder: (BuildContext context) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: sized,
    ),
  );
}

/// The default surface: the established jeeber `delivery_man_profile_screen_test`
/// renders, with 113 reviews behind him.
///
/// The baseline a reviewer signs off. Read the **AR RTL dark** variant of this
/// one before the others: the copy is correct and the row mirrors — "عرض الكل"
/// moves to the left edge and the count to the right — and the "Reviews"
/// heading above it is still barely legible, because its ink resolves to a
/// container tone at under 3:1 against the dark surface (see the library doc).
@JeebPreview(group: 'delivery_man_profile', name: '113 reviews (production)', size: _deliveryReviewsHeaderBox)
Widget deliveryReviewsHeaderProduction() => _deliveryReviewsHeaderHosted(113);

/// Cold start: a jeeber nobody has reviewed yet.
///
/// A real production state — `delivery_man_profile_screen_test.dart` renders
/// it, and every jeeber passes through it on the day they are approved. The
/// header does not special-case it: it still says "Reviews", still labels the
/// count "0 Reviews", and still offers a live "View all" that pushes the
/// paginated reviews route so the client can arrive at another empty list.
/// Nothing here is broken; it is a copy decision that has never been looked at
/// in a picture. See [deliveryReviewsHeaderAboveEmptyList] for what sits under
/// it.
@JeebPreview(group: 'delivery_man_profile', name: 'Cold start · 0 reviews', size: _deliveryReviewsHeaderBox)
Widget deliveryReviewsHeaderColdStart() => _deliveryReviewsHeaderHosted(0);

/// The pluralization defect, made visible.
///
/// `deliveryManProfileReviewsCount` is `"{count} Reviews"` in `app_en.arb` with
/// a plain `int` placeholder — no `plural` select — and `AppLocalizations`
/// resolves it with `replaceFirst('{count}', '$count')`. So the first review a
/// jeeber ever earns is announced as **"1 Reviews"**.
///
/// Reachable the moment any jeeber gets their first rating, i.e. constantly,
/// and invisible to a preview that only ever renders 113. Arabic is worse, not
/// better: `"{count} تقييم"` is a single fixed form, so the 3–10 band
/// (`تقييمات`) and the 11+ band are both wrong there too. Fixing it is an ARB
/// change plus a regenerate, which is out of scope for a preview — this state
/// exists so the bug is on screen instead of in a backlog.
@JeebPreview(group: 'delivery_man_profile', name: 'Single review · "1 Reviews"', size: _deliveryReviewsHeaderBox)
Widget deliveryReviewsHeaderSingleReview() => _deliveryReviewsHeaderHosted(1);

/// The count ceiling on the narrowest phone: a six-figure aggregate.
///
/// Two things only show up here. First, the number is interpolated raw —
/// `'$count'` — so there is no grouping separator and no locale digit shaping:
/// "128450 Reviews" in English and the same Western digits inside the Arabic
/// string. Second, this is where the [Flexible] count starts actually competing
/// with the non-flexible "View all" button for the 280 pt between the gutters.
///
/// 128 450 is far past any real jeeber, and that is the point of a ceiling: it
/// is the widest the label can plausibly get before the layout has to be
/// redesigned rather than tweaked.
@JeebPreview(group: 'delivery_man_profile', name: 'Six figures · 320 pt', size: _deliveryReviewsHeaderBox)
Widget deliveryReviewsHeaderSixFigures() =>
    _deliveryReviewsHeaderHosted(128450, width: _deliveryReviewsHeaderNarrowPhoneWidth);

/// Layout ceiling: the narrowest phone at the 200% accessibility ceiling.
///
/// **This is the preview to open.** The row is
/// `Row(Flexible(count), OmdsPrimaryButton)` with `spaceBetween`, and
/// `OmdsPrimaryButton` defaults to `width: null` — so the button takes its
/// intrinsic width first and the count line is left with the remainder. At 2×
/// on 320 pt that remainder is thin enough that "47 Reviews" wraps onto two
/// lines while the button keeps its full label, and the header's own height
/// roughly doubles.
///
/// That priority is defensible (the affordance must stay tappable), but it is a
/// decision no one has reviewed, and the count `Text` has neither `maxLines`
/// nor `overflow` to fall back on — it degrades by wrapping only because
/// nothing stops it. The scale is pinned into the tree so a widget test
/// reproduces it; see the render test.
@JeebPreview(group: 'delivery_man_profile', name: 'Narrow · 200% text', size: _deliveryReviewsHeaderLargeTextBox)
Widget deliveryReviewsHeaderNarrowLargeText() =>
    _deliveryReviewsHeaderHosted(47, width: _deliveryReviewsHeaderNarrowPhoneWidth, textScale: 2.0);

/// The header in the only place it appears, over the list it heads — with that
/// list empty.
///
/// A section header cannot be reviewed alone: its job is spatial. Composed with
/// `DeliveryReviewsList(reviews: [])` the real page reads
/// "Reviews / 0 Reviews · View all" stacked directly on top of "No reviews
/// yet", which is the screen a brand-new jeeber's profile actually shows and
/// which no amount of staring at the header alone would surface.
///
/// It also pins the vertical rhythm across the seam. The header reserves
/// nothing below its count row — it ends flush with the 48 pt button — so every
/// pixel of air under it belongs to the list, and the list spends a different
/// number in each branch: `Spacing.large` (20) from `_EmptyReviews` here,
/// `Spacing.medium` (16) from `ListView.separated`'s `fromSTEB` once there are
/// cards. The gutters have to agree too: the header indents to `Spacing.large`
/// (20) and so does the list. Change either in isolation and this state goes
/// crooked while every other preview here stays perfect.
@JeebPreview(group: 'delivery_man_profile', name: 'Above the empty list', size: _deliveryReviewsHeaderWithListBox)
Widget deliveryReviewsHeaderAboveEmptyList() => _deliveryReviewsHeaderHosted(
  0,
  below: const DeliveryReviewsList(reviews: <DeliveryReviewData>[]),
);
