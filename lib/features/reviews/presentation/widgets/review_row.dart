import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_avatar.dart';
import '../../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../domain/reviews_repository.dart';
import '../reviews_l10n.dart';

/// One review row in the all-reviews list (JM-068).
///
/// redesign-2026-08: the row was an [OmdsReviewCard] under a duplicate name
/// label — a divider-separated block that printed the reviewer twice, drew its
/// own bottom `Border`, and laid its images out with a non-directional
/// `EdgeInsets.only(right:)`. It is now a [JeebOutlinedCard] (outline over
/// shadow, r16) holding one identity row + the body + the report affordance,
/// so the list reads as the same product as its redesigned neighbours
/// (order-history's card list, 15-mutual-rating's identity block). The
/// duplicate name is gone: the D58 attribution node IS the visible name.
///
/// D57 still holds — NO Helpful/Reply controls (reviews are immutable); the
/// composition simply never builds them. The D27 report affordance stays a
/// DISTINCT trailing node (`review_<id>_report_cta`) so QA/Maestro can assert +
/// tap it by id, and `review_<id>_reviewer_name` carries the first-name-only
/// attribution (D58) for the flow assertion.
///
/// A dumb widget (40_GUARDRAILS_ARCH §1): data in via constructor, the report
/// event out via [onReport] — it never reaches into `sl`/`context.go`.
class ReviewRow extends StatelessWidget {
  const ReviewRow({
    super.key,
    required this.review,
    required this.copy,
    required this.onReport,
  });

  final ReviewItem review;
  final ReviewsL10n copy;

  /// Fired when the per-row `review_<id>_report_cta` is tapped (D27). The screen
  /// owns the confirm dialog + cubit call.
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String body = review.body?.trim() ?? '';
    return Semantics(
      // Per-row container so a flow can scope assertions to one review.
      identifier: 'review_${review.id}',
      container: true,
      explicitChildNodes: true,
      child: JeebOutlinedCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // The avatar is decorative here: the name beside it is the
                // attribution node, so a second spoken initial would just
                // stutter. No identifier/label ⇒ JeebAvatar emits no node.
                JeebAvatar(initial: review.reviewerFirstName),
                const SizedBox(width: Spacing.small),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // First-name-only attribution (D58) — its own asserted
                      // node, and now the ONLY place the name is printed.
                      Semantics(
                        identifier: 'review_${review.id}_reviewer_name',
                        child: Text(
                          review.reviewerFirstName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.jeebText.cardTitle
                              .copyWith(color: scheme.primary),
                        ),
                      ),
                      const SizedBox(height: Spacing.twoXSmall),
                      _ReviewStars(score: review.score),
                    ],
                  ),
                ),
                const SizedBox(width: Spacing.xSmall),
                Text(
                  copy.relativeTime(review.timestamp),
                  style: context.jeebText.bodySmall
                      .copyWith(color: scheme.onSecondaryContainer),
                ),
              ],
            ),
            if (body.isNotEmpty) ...<Widget>[
              const SizedBox(height: Spacing.small),
              Text(
                body,
                style: context.jeebText.body.copyWith(color: scheme.onSurface),
              ),
            ],
            if (review.reportable)
              // A Row (not an Align): the bare-text CTA centres its label in
              // whatever width it is given, so it must be laid out against an
              // UNBOUNDED main axis to shrink-wrap and sit on the start edge.
              Row(
                children: [
                  JeebCtaButton.text(
                    identifier: 'review_${review.id}_report_cta',
                    label: copy.reportAction,
                    leadingIcon: Icons.flag,
                    iconSize: Sizes.medium,
                    iconSpacing: Spacing.xSmall,
                    // The report link is a *secondary interactive word*
                    // (R-ink): the bare-text variant's brown ink at the meta
                    // size, not the 15.5px footer-CTA default.
                    labelStyle: context.jeebText.bodySmall,
                    contentPadding: EdgeInsetsDirectional.zero,
                    onTap: onReport,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// The five-glyph score. The board draws the EMPTY star as a FILLED grey glyph
/// (15 `tpl 873`, `--jeeb-surface-highest`), never `Icons.star_border`.
///
/// The star stays NAVY: §4.1 rations the one warm ink to the three surfaces
/// where a specific person's rating drives a decision (11/12/15). This list is
/// the drill-down of a meta line, and its parent — `delivery_man_profile_header`
/// — already ratified navy for exactly this reason.
class _ReviewStars extends StatelessWidget {
  const _ReviewStars({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int position = 1; position <= 5; position++)
          Padding(
            padding: EdgeInsetsDirectional.only(
              end: position < 5 ? Sizes.threeXSmall : 0,
            ),
            child: Icon(
              score >= position
                  ? Icons.star
                  : score >= position - 0.5
                      ? Icons.star_half
                      : Icons.star,
              size: Sizes.medium,
              color: score >= position - 0.5
                  ? scheme.primary
                  : scheme.surfaceContainerHighest,
            ),
          ),
      ],
    );
  }
}
