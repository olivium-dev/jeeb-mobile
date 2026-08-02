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

/// Canvas box for a normal row: phone width, and tall enough for the
/// attribution + card + report CTA stack at 1.0× text. Measured at 390 pt:
const Size _reviewRowBox = Size(390, 230);

/// Canvas box for the states that drop a line: no comment (173 pt) or no report
/// button (159 pt, the FLOOR this widget can shrink to).
const Size _reviewRowShortBox = Size(390, 190);

/// Canvas box for the wrapping state — 425 pt measured at 1.0× text. The 200%
/// rendering of the matrix does not fit in any sane box (1339 pt) and is meant
const Size _reviewRowTallBox = Size(390, 440);

/// An ISO-8601 instant [age] before now, so the rendered relative age is stable
/// across days. See the note above on the missing `now` seam.
String _reviewRowAgo(Duration age) =>
    DateTime.now().toUtc().subtract(age).toIso8601String();

/// Hosts one row the way `_LoadedList` does: full phone width, inside a
/// scrollable, followed by the same `Divider(height: 1, indent: …)` that
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
/// `body` is nullable in the R1m contract and the stub returns `null` for one
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
/// R1m returns `true` for every row today, so this branch is unreachable
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
