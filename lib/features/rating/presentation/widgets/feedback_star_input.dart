import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

/// Interactive 0–5 star row on the feedback screen (Figma 56614:20132).
///
/// Wraps the OMDS [OmdsStarRating] catalog component. OMDS does not expose a
/// per-star semantics identifier, so the container announces the current value
/// (e.g. "3 of 5 stars") for screen readers; the per-star-id gap is disclosed
/// in the screen's reuse-note.md rather than reimplementing the star row.
class FeedbackStarInput extends StatelessWidget {
  const FeedbackStarInput({
    super.key,
    required this.stars,
    required this.onChanged,
  });

  static const Key rootKey = Key('feedback_star_rating');

  final int stars;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'feedback_star_rating',
      slider: true,
      value: '$stars / 5',
      child: Center(
        key: rootKey,
        // Size, spacing and empty-star ink are matched to
        // `MutualRatingScreen._StarSection` so both rating terminals draw one
        // star row. The active colour is deliberately NOT passed — the app-wide
        // `OmdsColorTokens.starRatingColor` is already the redesign's amber.
        child: OmdsStarRating(
          rating: stars,
          starSize: Sizes.threeXLarge,
          spacing: Spacing.xSmall,
          inactiveColor: scheme.surfaceContainerHighest,
          onRatingChanged: onChanged,
        ),
      ),
    );
  }
}
