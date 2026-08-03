import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

/// Interactive 0–5 star row on the feedback screen (Figma 56614:20132).
/// Wraps the OMDS [OmdsStarRating] catalog component. OMDS does not expose a
/// per-star semantics identifier, so the container announces the current value
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

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// Phone width, with room for a title, a note, the row and its readout. The row
/// itself is only 216 × 40 — the height is for the label at 200% text.
const Size _feedbackStarInputSpecimenBox = Size(390, 280);

/// Title + note + the star row + a live readout of the value driving it.
/// Stateful only so the canvas is interactive and so the readout is fed by the
/// same field as the widget — there is no controller, no ticker and nothing to
class _FeedbackStarInputSpecimen extends StatefulWidget {
  const _FeedbackStarInputSpecimen({
    required this.title,
    required this.note,
    required this.seed,
  });

  final String title;
  final String note;
  final int seed;

  @override
  State<_FeedbackStarInputSpecimen> createState() =>
      _FeedbackStarInputSpecimenState();
}

class _FeedbackStarInputSpecimenState
    extends State<_FeedbackStarInputSpecimen> {
  late int _stars = widget.seed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(Spacing.medium),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(widget.title, style: theme.textTheme.titleSmall),
          const SizedBox(height: Spacing.twoXSmall),
          Text(
            widget.note,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.medium),
          FeedbackStarInput(
            stars: _stars,
            onChanged: (int value) => setState(() => _stars = value),
          ),
          const SizedBox(height: Spacing.xSmall),
          Text('value $_stars / 5', style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

/// The state every rater lands on, and the only one that blocks the screen.
/// `/orders/:id/feedback` opens with `_stars = 0` and `_onSubmit` returns early
@JeebPreview(
  group: 'rating',
  name: 'Unrated',
  size: _feedbackStarInputSpecimenBox,
)
Widget feedbackStarInputUnrated() => const _FeedbackStarInputSpecimen(
      title: 'Unrated',
      note: 'Where every rater starts. Submit is inert until a star is picked.',
      seed: 0,
    );

/// One filled glyph — the entire difference between "blocked" and
/// "submittable".
@JeebPreview(
  group: 'rating',
  name: 'One star',
  size: _feedbackStarInputSpecimenBox,
)
Widget feedbackStarInputOneStar() => const _FeedbackStarInputSpecimen(
      title: 'One star',
      note: 'The minimum valid rating. One glyph separates it from unrated.',
      seed: 1,
    );

/// The fill boundary, mid-row.
/// [OmdsStarRating] decides each glyph with `rating >= starValue`, so this is
@JeebPreview(
  group: 'rating',
  name: 'Three of five',
  size: _feedbackStarInputSpecimenBox,
)
Widget feedbackStarInputThreeOfFive() => const _FeedbackStarInputSpecimen(
      title: 'Three of five',
      note: 'Both branches of the fill test in one row. Mirrors visibly.',
      seed: 3,
    );

/// The upper bound: every glyph filled.
/// Pinned mostly for colour review — filled stars must use the brand
@JeebPreview(
  group: 'rating',
  name: 'All five',
  size: _feedbackStarInputSpecimenBox,
)
Widget feedbackStarInputAllFive() => const _FeedbackStarInputSpecimen(
      title: 'All five',
      note: 'Upper bound. Filled = brand terracotta, empty = cool neutral.',
      seed: 5,
    );

/// **The state that breaks.** A value outside 0–5 is rendered, not rejected.
/// `stars` is an unvalidated `int`: [FeedbackStarInput] asserts nothing and
@JeebPreview(
  group: 'rating',
  name: 'Out of range',
  size: _feedbackStarInputSpecimenBox,
)
Widget feedbackStarInputOutOfRange() => const _FeedbackStarInputSpecimen(
      title: 'Out of range',
      note: 'stars: 9, unclamped. Pixel-identical to a genuine five-star row.',
      seed: 9,
    );
