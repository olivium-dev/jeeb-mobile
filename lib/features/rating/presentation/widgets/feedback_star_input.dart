import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

/// Interactive 0–5 star row on the feedback terminal, drawn to R15.
///
/// MIDNIGHT: the OMDS row is retired here — it draws a hollow `star_border`
/// for the unselected glyphs and carries no halo, and R15 draws neither. Amber
/// fill, a FILLED muted glyph when unselected, and the static amber halo the
/// tile's caption calls for. It does NOT twinkle (03-MOTION-NOTES R15: zero
/// animated elements; motion ruling 4 bans a star twinkle by name).
class FeedbackStarInput extends StatelessWidget {
  const FeedbackStarInput({
    super.key,
    required this.stars,
    required this.onChanged,
  });

  static const Key rootKey = Key('feedback_star_rating');

  /// Board glyph 37 tile-px ÷ 1.1 ≈ 34dp drawn inside a 40dp box; the 12dp gap
  /// reproduces the measured 57 tile-px star-to-star pitch.
  static const double starSize = 40;
  static const double starGap = Spacing.small;
  static const int starCount = 5;

  /// The measured halo: ≈12 % amber at the glyph edge, linear to nothing 30dp
  /// out. A gradient, never a `BoxShadow` — a shadow paints nothing here.
  static const double glowInset = -10;
  static const double glowAlpha = 0.32;

  final int stars;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final JeebSemanticColors semantic =
        Theme.of(context).extension<JeebSemanticColors>() ??
            JeebSemanticColors.midnight();
    return Semantics(
      identifier: 'feedback_star_rating',
      container: true,
      label: l10n.mutualRatingStarsA11yLabel(stars),
      child: Center(
        key: rootKey,
        // A plain `Row` mirrors under `ar`, so star 1 lands at the end edge and
        // the fill grows inward — the board's own RTL behaviour.
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int value = 1; value <= starCount; value++) ...<Widget>[
              if (value > 1) const SizedBox(width: starGap),
              _FeedbackStar(
                value: value,
                filled: stars >= value,
                fill: semantic.amber,
                // White 22 % is the board's unselected star over navy.
                emptyFill: semantic.glassBorderVivid,
                onTap: () => onChanged(value),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeedbackStar extends StatelessWidget {
  const _FeedbackStar({
    required this.value,
    required this.filled,
    required this.fill,
    required this.emptyFill,
    required this.onTap,
  });

  final int value;
  final bool filled;
  final Color fill;
  final Color emptyFill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'feedback_star_$value',
      button: true,
      selected: filled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: FeedbackStarInput.starSize,
          child: Stack(
            // The halo is `Positioned` beyond the box on purpose: it must not
            // widen the row, and it must not be clipped to the glyph.
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: <Widget>[
              if (filled)
                Positioned(
                  left: FeedbackStarInput.glowInset,
                  top: FeedbackStarInput.glowInset,
                  right: FeedbackStarInput.glowInset,
                  bottom: FeedbackStarInput.glowInset,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: <Color>[
                          fill.withValues(alpha: FeedbackStarInput.glowAlpha),
                          fill.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              Icon(
                Icons.star,
                size: FeedbackStarInput.starSize,
                color: filled ? fill : emptyFill,
              ),
            ],
          ),
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

/// The fill boundary, mid-row. Every glyph is decided by `stars >= value`, so
/// this specimen exercises both branches at once.
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

/// The upper bound: every glyph filled, every halo lit.
@JeebPreview(
  group: 'rating',
  name: 'All five',
  size: _feedbackStarInputSpecimenBox,
)
Widget feedbackStarInputAllFive() => const _FeedbackStarInputSpecimen(
      title: 'All five',
      note: 'Upper bound. Filled = amber + halo, empty = white 22 % glass.',
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
