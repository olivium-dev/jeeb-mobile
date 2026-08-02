import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

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
    return Semantics(
      identifier: 'feedback_star_rating',
      slider: true,
      value: '$stars / 5',
      child: Center(
        key: rootKey,
        child: OmdsStarRating(
          rating: stars,
          starSize: Sizes.threeXLarge,
          onRatingChanged: onChanged,
        ),
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
// Render tests: test/previews/rating/feedback_star_input_preview_test.dart
// ===========================================================================
//
// Widget previews for [FeedbackStarInput] — run with
// `flutter widget-preview start`.
//
// [FeedbackStarInput] takes a plain `int` and a callback. It has no cubit, no
// repository and nothing to fetch, so these previews are network-free because
// there is nothing to fetch, not merely because [jeebPreviewHost] guards them.
// What varies between states is the ONE number the widget is handed.
//
// The widget renders no text of its own — it is five glyphs from
// [OmdsStarRating] — so every state below is wrapped in
// [_FeedbackStarInputSpecimen], which names the state and prints the value
// currently driving the row. That readout is not decoration: the specimen is
// stateful and feeds `onChanged` straight back into the same `_stars` field it
// hands to the widget, so the canvas is interactive (tap a star and watch both
// the glyphs and the readout move) and a preview that silently ignored its seed
// would show a readout that disagrees with the glyphs.
//
// Three things are worth staring at in the matrix, none of which are visible
// in the EN light rendering alone:
//
// * **AR RTL** — [OmdsStarRating] spaces its stars with a physical
//   `EdgeInsets.only(right: …)`, not [EdgeInsetsDirectional]. Mirrored, the
//   4 dp gap lands on the wrong side of every glyph: the row gains a stray
//   inset on its leading edge and the last two stars end up touching.
// * **EN 200% text** — [Icon] does not scale with the text scaler, so the row
//   is the same 216 × 40 at 200% as at 100%. The label above it doubles; the
//   control the label describes does not.
// * **Either** — each star is a bare 40 dp [Icon] inside a [GestureDetector].
//   That is 8 dp under [A11y.minTapTargetSize], the floor AC T-mobile-036
//   sets for every tappable element.
//
// Scenario titles are deliberately unlocalized: they name the *state*, not the
// product, so seeing English in the AR RTL rendering is expected.

/// Phone width, with room for a title, a note, the row and its readout. The row
/// itself is only 216 × 40 — the height is for the label at 200% text.
const Size _feedbackStarInputSpecimenBox = Size(390, 280);

/// Title + note + the star row + a live readout of the value driving it.
///
/// Stateful only so the canvas is interactive and so the readout is fed by the
/// same field as the widget — there is no controller, no ticker and nothing to
/// settle.
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
///
/// `/orders/:id/feedback` opens with `_stars = 0` and `_onSubmit` returns early
/// while it stays 0, so this is a modal dead end: the screen suppresses system
/// back (`PopScope(canPop: false)`) and carries no skip control (D56). Five
/// empty outlines are the entire instruction the user gets — there is no "tap
/// to rate" copy anywhere on the row.
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
///
/// Worth its own state because it is the hardest reading in the set: 1 vs 0 is
/// a single 40 dp icon changing from outline to fill, with no count, no label
/// and no colour change anywhere else on the screen to confirm the tap landed.
/// If the empty and filled colours ever converge in a theme, this is the state
/// where it becomes a bug report and `All five` is the state where it does not.
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
///
/// [OmdsStarRating] decides each glyph with `rating >= starValue`, so this is
/// the only kind of state that exercises both branches in one rendering. It is
/// also the reading the AR RTL rendering is really for: with three filled and
/// two empty the row is asymmetric, so a mirroring mistake shows up as the fill
/// starting from the wrong edge — invisible in `Unrated` and `All five`, both
/// of which look identical mirrored or not.
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
///
/// Pinned mostly for colour review — filled stars must use the brand
/// `starRatingColor` token against the empty `starInactiveColor`, and this is
/// the state where the two are furthest apart. The AR RTL rendering doubles as
/// the dark-theme contrast check for both tokens at once.
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
///
/// `stars` is an unvalidated `int`: [FeedbackStarInput] asserts nothing and
/// [OmdsStarRating] only ever asks `rating >= starValue`, so 9 paints five
/// filled stars and is pixel-identical to a real five-star rating. The mirror
/// case is worse — a negative value is pixel-identical to *unrated*, which is
/// the one state the submit gate treats as special.
///
/// This is reachable from data, not just from a typo: `CounterpartRating`
/// parses the score-taking service's payload with
/// `(raw as num?)?.toInt() ?? 0`, tolerating both the `stars` and the `score`
/// key and clamping neither. Any upstream drift to a 0–10 scale arrives here
/// silently, and the readout below is the only thing in this preview that can
/// tell you it happened.
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
