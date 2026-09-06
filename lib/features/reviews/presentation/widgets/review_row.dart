import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_semantic_colors.dart';
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
///
/// MIDNIGHT (M3-31): the rung is R21's order-history row — identity band over a
/// meta band inside one [JeebOutlinedCard], `cardTitle`/`onSurface` title and
/// `bodySmall`/`onSurfaceVariant` meta, outlines-as-separation. The stars take
/// R15's amber (token sheet §3 `amber`, "stars/ratings"); they were inked
/// `colorScheme.primary` under a comment reading "the star stays NAVY", which
/// was true in pass 1 and is FALSE under Midnight, where `primary` IS `#D73B00`
/// — five orange glyphs plus an orange reviewer name per row, on a read-only
/// list. The disc moves to [JeebAvatarFill.glass] (wave-B ruling 3): `primary`
/// is opaque navy and vanishes on the field.
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
                JeebAvatar(
                  initial: review.reviewerFirstName,
                  fill: JeebAvatarFill.glass,
                ),
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
                          style: context.jeebText.cardTitle.copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(height: Spacing.twoXSmall),
                      _ReviewStars(score: review.score),
                    ],
                  ),
                ),
                const SizedBox(width: Spacing.xSmall),
                // R21 meta ink: `onSurfaceVariant` (#8A93D8) on a resting row —
                // `onSecondaryContainer` (inkSoft) is reserved for the lit one.
                Text(
                  copy.relativeTime(review.timestamp),
                  style: context.jeebText.bodySmall.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
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
                    // A *secondary interactive word*: the `.text` variant inks
                    // itself `onSurfaceVariant` (periwinkle, never brown now).
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

/// The five-glyph score, R15's star treatment at R21's meta scale: `amber` fill
/// and a FILLED white-22% glyph when empty (the board never draws a hollow
/// star). No halo — R15's is measured on a Ø40 input glyph and would flood a
/// 16dp readout; R21's own row star is a flat mark. Stars never twinkle
/// (motion ruling 4).
class _ReviewStars extends StatelessWidget {
  const _ReviewStars({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final JeebSemanticColors semantic =
        Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
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
                  ? semantic.amber
                  : semantic.glassBorderVivid,
            ),
          ),
      ],
    );
  }
}
