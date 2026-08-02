import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../domain/reviews_repository.dart';
import '../reviews_l10n.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

class ReviewRow extends StatelessWidget {
  const ReviewRow({
    super.key,
    required this.review,
    required this.copy,
    required this.onReport,
  });

  final ReviewItem review;
  final ReviewsL10n copy;

  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'review_${review.id}',
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: Spacing.medium,
              end: Spacing.medium,
              top: Spacing.small,
            ),
            child: Semantics(
              identifier: 'review_${review.id}_reviewer_name',
              child: Text(
                review.reviewerFirstName,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
          OmdsReviewCard(
            userName: review.reviewerFirstName,
            rating: review.score,
            reviewText: review.body ?? '',
            timeAgo: copy.relativeTime(review.timestamp),
            showActions: false,
            starColor: theme.colorScheme.primary,
          ),
          if (review.reportable)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: Spacing.small,
                bottom: Spacing.xSmall,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Semantics(
                  identifier: 'review_${review.id}_report_cta',
                  button: true,
                  child: TextButton.icon(
                    onPressed: onReport,
                    icon: Icon(
                      Icons.flag_outlined,
                      size: Sizes.medium,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    label: Text(
                      copy.reportAction,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
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
// Render tests: test/previews/reviews/review_row_preview_test.dart
// ===========================================================================
//
// Widget previews for [ReviewRow] — run with `flutter widget-preview start`.
//
// The row is a dumb widget (40_GUARDRAILS_ARCH §1): one [ReviewItem] value, one
// [ReviewsL10n] resolver read off the ambient [Localizations], one inert
// `onReport`. There is no cubit and no repository behind it, so these previews
// are network-free by construction rather than by the guard in
// [jeebPreviewHost] — each state is a literal [ReviewItem].
//
// The fixture names and bodies are the ones `StubReviewsRepository` already
// serves (`Sami` / "Fast and friendly.", `Omar` with a null body), so the
// canvas and the screen you get from `jeeb.seam.journey` are looking at the
// same rows.
//
// ## Why the timestamps are relative and not pinned
//
// [ReviewRow] calls `copy.relativeTime(review.timestamp)` with NO `now`
// argument, so the age is resolved against the wall clock. Unlike its sibling
// `NotificationRow`, this widget exposes no injectable clock, so a fixed ISO
// fixture would read "12d ago" one week and "19d ago" the next — an age that
// silently re-renders is not a state anyone can review. The fixtures below are
// therefore anchored to `DateTime.now()` via [_reviewRowAgo], which makes the
// DISPLAYED age stable ("2h ago" is always "2h ago") at the cost of the
// underlying instant moving. That is a workaround for a missing seam, not a
// preference — if a `now` parameter ever lands on [ReviewRow], pin these.
//
// ## What to look for
//
// * **The reviewer's first name is printed TWICE.** [ReviewRow] renders its own
//   D58 attribution node and then hands the SAME string to [OmdsReviewCard] as
//   `userName`, which paints it again in the same `titleSmall` semibold — so
//   every card in the canvas reads "Sami / (avatar) Sami / ★★★★★". The
//   duplication is not visible to the semantics tests (they assert on
//   `review_<id>_reviewer_name`, which resolves fine) and it is the first thing
//   you see here.
//
// * **The report CTA sits BELOW the card's own bottom border.** `OmdsReviewCard`
//   paints a `BorderSide` under itself; the D27 flag button is a sibling AFTER
//   the card in the same [Column]. [_reviewRowHosted] draws the production
//   `ListView.separated` divider too, so the canvas shows the real stacking: a
//   hairline between a review's text and that review's own Report button, and
//   two hairlines between consecutive rows.
//
// * **Nothing on this row clamps.** Neither the attribution, the body, nor the
//   `timeAgo` sets `maxLines`, so long copy wraps and the row GROWS. Measured
//   at 390 pt: the shortest row this widget produces is 159 pt and the
//   canonical one is 194 pt, but [reviewRowLongComment] is 425 pt at 1.0× and
//   **1339 pt at 200 % text** — one review taller than three phone screens.
//   Nothing overflows (the list scrolls), it just buries everything under it.
//
// * **The avatar initial is ASCII-only.** `OmdsReviewCard._buildUserAvatar`
//   accepts a first letter only when it matches `[a-zA-Z]`, so every
//   Arabic-named reviewer falls back to "?" — see [reviewRowArabicReviewer].

/// Canvas box for a normal row: phone width, and tall enough for the
/// attribution + card + report CTA stack at 1.0× text. Measured at 390 pt:
/// 194 pt with a Latin one-line comment, 215 pt with an Arabic one (the Arabic
/// line box is taller), plus the trailing divider.
const Size _reviewRowBox = Size(390, 230);

/// Canvas box for the states that drop a line: no comment (173 pt) or no report
/// button (159 pt, the FLOOR this widget can shrink to).
const Size _reviewRowShortBox = Size(390, 190);

/// Canvas box for the wrapping state — 425 pt measured at 1.0× text. The 200%
/// rendering of the matrix does not fit in any sane box (1339 pt) and is meant
/// to be scrolled.
const Size _reviewRowTallBox = Size(390, 440);

/// An ISO-8601 instant [age] before now, so the rendered relative age is stable
/// across days. See the note above on the missing `now` seam.
String _reviewRowAgo(Duration age) =>
    DateTime.now().toUtc().subtract(age).toIso8601String();

/// Hosts one row the way `_LoadedList` does: full phone width, inside a
/// scrollable, followed by the same `Divider(height: 1, indent: …)` that
/// `ListView.separated` puts between rows.
///
/// The scrollable is not decoration. A `Scaffold` body hands its child TIGHT
/// constraints, so a bare row would stretch to the full canvas box and every
/// card would report the same (wrong) height; and because nothing here clamps,
/// the 200% rendering would paint overflow stripes over the state under review.
/// Production hosts it in a `ListView.separated`, which is exactly this:
/// unbounded height, growth turns into scroll rather than into an error.
///
/// [ReviewsL10n.of] needs a [BuildContext] under the preview's [Localizations],
/// which is what the [Builder] is for — the resolver picks EN or AR off the
/// ambient locale exactly as the production screen does.
Widget _reviewRowHosted(ReviewItem review) => SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Builder(
            builder: (BuildContext context) => ReviewRow(
              review: review,
              copy: ReviewsL10n.of(context),
              onReport: () {},
            ),
          ),
          const Divider(
            height: 1,
            indent: Spacing.medium,
            endIndent: Spacing.medium,
          ),
        ],
      ),
    );

/// The canonical row: a five-star review with a comment and the D27 report
/// affordance, exactly as `StubReviewsRepository` serves it.
///
/// This is the shape every other state is a degradation of, and it carries the
/// matrix because the card is a [Row] of avatar + name/stars + age with a
/// leading-aligned button under it — the AR RTL rendering is the only place the
/// mirroring is visible, and the 200% rendering is where the fixed 40 pt avatar
/// stops lining up with the text beside it.
@JeebPreview(
  group: 'reviews',
  name: 'Five stars · with comment',
  size: _reviewRowBox,
  matrix: true,
)
Widget reviewRowWithComment() => _reviewRowHosted(
      ReviewItem(
        id: 'review-001',
        reviewerFirstName: 'Sami',
        score: 5,
        timestamp: _reviewRowAgo(const Duration(hours: 2)),
        body: 'Fast and friendly.',
      ),
    );

/// A star-only rating: the reviewer tapped four stars and wrote nothing.
///
/// `body` is nullable in the R1m contract and the stub returns `null` for one
/// row in every page, so this is a common row, not an edge case. [ReviewRow]
/// coerces it to `''` and `OmdsReviewCard` then drops the text block entirely —
/// which leaves the unconditional `SizedBox(height: 12)` hanging under the star
/// row with nothing after it. Read this card next to the one above to judge
/// whether the gap reads as deliberate or as a missing line.
@JeebPreview(
  group: 'reviews',
  name: 'Stars only · no comment',
  size: _reviewRowShortBox,
)
Widget reviewRowStarsOnly() => _reviewRowHosted(
      ReviewItem(
        id: 'review-003',
        reviewerFirstName: 'Omar',
        score: 4,
        timestamp: _reviewRowAgo(const Duration(minutes: 45)),
      ),
    );

/// The other branch of the D27 gate: `reportable: false`, so no flag button.
///
/// R1m returns `true` for every row today, so this branch is unreachable
/// against the live source — which is precisely why it needs a card. If the
/// backend ever starts suppressing the affordance (an already-reported review,
/// a review of your own delivery), this is what ships. Note the row does not
/// just lose a button: the CTA carries the row's only bottom padding, so
/// without it the card's border sits flush against the next row's attribution.
///
/// The 3.5 score also exercises the half-star glyph, which no other state here
/// reaches.
@JeebPreview(
  group: 'reviews',
  name: 'Not reportable · half star',
  size: _reviewRowShortBox,
)
Widget reviewRowNotReportable() => _reviewRowHosted(
      ReviewItem(
        id: 'review-004',
        reviewerFirstName: 'Maya',
        score: 3.5,
        timestamp: _reviewRowAgo(const Duration(days: 3)),
        body: 'Took a while to find the building.',
        reportable: false,
      ),
    );

/// Layout ceiling: the longest comment a reviewer plausibly types, on a low
/// score (the reviews people write at length are the angry ones).
///
/// Nothing on this row clamps, so it does not ellipsize — it GROWS, and the
/// question the canvas answers is how far: 425 pt at 1.0× text and 1339 pt at
/// 200%, which is why this state carries the matrix and why its 200% card has
/// to be SCROLLED to be read.
///
/// Look also at the card header while you are here. `timeAgo` is an unflexed
/// child of that [Row], so at 200% it takes its full intrinsic width and the
/// name/stars column absorbs the loss — it does not overflow at 390 pt, but the
/// name wraps to make room for a five-character age, and the fixed 40 pt avatar
/// no longer reads as sitting beside the line it labels.
@JeebPreview(
  group: 'reviews',
  name: 'Long comment · wraps, never clamps',
  size: _reviewRowTallBox,
  matrix: true,
)
Widget reviewRowLongComment() => _reviewRowHosted(
      ReviewItem(
        id: 'review-007',
        reviewerFirstName: 'Abdulrahman',
        score: 2,
        timestamp: _reviewRowAgo(const Duration(days: 12)),
        body: 'He arrived almost an hour after the window I picked and did not '
            'answer the two calls I made in between. The package itself was '
            'fine and he was polite at the door, but I had to reschedule the '
            'rest of my afternoon around a delivery that was supposed to take '
            'twenty minutes.',
      ),
    );

/// An Arabic-named reviewer, rendered in the ENGLISH locale — the mixed-
/// direction case a bilingual user base produces constantly.
///
/// Two things to read here. First, the avatar: `OmdsReviewCard` derives its
/// initial from `[a-zA-Z]` only, so "نور" cannot produce one and every
/// Arabic-named reviewer gets the "?" placeholder — the same "we know nothing
/// about you" glyph a nameless account gets. Second, the RTL body inside an LTR
/// paragraph: the attribution and the comment resolve their own direction from
/// the text, but the surrounding layout does not mirror, so the punctuation
/// lands where the ambient direction puts it.
@JeebPreview(
  group: 'reviews',
  name: 'Arabic reviewer in EN locale',
  size: _reviewRowBox,
)
Widget reviewRowArabicReviewer() => _reviewRowHosted(
      ReviewItem(
        id: 'review-011',
        reviewerFirstName: 'نور',
        score: 5,
        timestamp: _reviewRowAgo(const Duration(days: 1)),
        body: 'وصل قبل الموعد وكان لطيفًا جدًا.',
      ),
    );
