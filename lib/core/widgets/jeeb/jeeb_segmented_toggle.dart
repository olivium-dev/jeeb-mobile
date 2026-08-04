import 'package:flutter/material.dart';

import '../../theme/jeeb_radii.dart';
import '../../theme/jeeb_semantic_colors.dart';
import '../../theme/jeeb_text_styles.dart';

const BorderRadius _pillRadius =
    BorderRadius.all(Radius.circular(JeebRadii.pill));

/// Gap between segments (`5` — R5 language toggle).
const double _segmentGap = 5;

/// Where the segments sit (wave-A ruling — E1 draws no enclosing track).
enum JeebSegmentedPlacement {
  /// R5/20: segments inside one glass track (`glassFill` + 1px
  /// `glassBorderStrong`, radius `pill`, padding 4). The default.
  tracked,

  /// E1: free-standing pills. No track; the UNSELECTED segments are glass
  /// chips (`glassFill` + 1px `glassBorder`), the selected one stays white.
  trackless,
}

/// One segment of a [JeebSegmentedToggle].
///
/// Carries its own [key] and [identifier] because screen 20's language rows are
/// frozen: `Key('settings-row-language-en')` / `settings_language_en_option` and
/// the `-ar` pair are tapped by `settings_screen_test.dart:161` and by Maestro
/// (20 §8 K1). A toggle that only took `List<String>` could not preserve them.
@immutable
class JeebSegment {
  const JeebSegment({
    required this.label,
    this.key,
    this.identifier,
    this.semanticLabel,
  });

  /// Visible, already-localized label (`English`, `العربية`).
  final String label;

  /// Widget key kept on the segment's tap target.
  final Key? key;

  /// Maestro/`find.bySemanticsIdentifier` id for this segment.
  final String? identifier;

  /// Accessibility label when [label] is not enough. Defaults to [label].
  final String? semanticLabel;
}

/// The two-up pill switch (redesign-2026-08 §5 #19).
///
/// MIDNIGHT (R5 language toggle · E1 chip row · R17 ETA row): the outer track is
/// glass — `glassFill` + `1px glassBorderStrong`, radius `pill`, padding 4,
/// segments 5 apart. Segments are `flex:1`, padding `9/0`; the selected one is a
/// **white fill with navy (`#0B1351`) ink at 13.5/w700**, the rest stay
/// transparent with `inkSoft` ink at 13.5/w600. Orange is not in this control.
///
/// **Two placements** ([JeebSegmentedPlacement]): `tracked` (R5, the default)
/// and `trackless` (E1 — free-standing pills, no enclosing glass, and the
/// *unselected* segments carry the glass chip themselves).
///
/// **Scope, deliberately narrow:**
///  * 20's language switch is the only kit consumer.
///  * 01 uses a *screen-local* dark-on-navy variant (`OnboardingLanguageToggle`)
///    — §5 #19 says so explicitly; do not widen this widget for it.
///  * **17's ETA row is not this widget.** That is a flat row of `flex:1`
///    `JeebSelectChip(role: choice)` with **no outer track**. Merging them
///    would put a border around 17's row that the board does not draw.
///
/// **Directional by construction.** A plain [Row] puts segment 0 on the start
/// edge, so an EN/AR pair mirrors under RTL for free. 20 drives
/// [selectedIndex] from the locale, never from a positional guess.
class JeebSegmentedToggle extends StatelessWidget {
  const JeebSegmentedToggle({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
    this.placement = JeebSegmentedPlacement.tracked,
    this.padding = defaultPadding,
    this.segmentPadding,
    this.borderWidth = 1,
    this.identifier,
  });

  /// Track padding (`4` — 20 `tpl 1188`).
  static const EdgeInsetsGeometry defaultPadding = EdgeInsetsDirectional.all(4);

  /// Segment padding (`9/0` — 20 `tpl 1189`). Vertical only: the segments are
  /// `flex:1`, so horizontal padding would fight the flex.
  static const EdgeInsetsGeometry defaultSegmentPadding =
      EdgeInsetsDirectional.symmetric(vertical: 9);

  /// Free-pill segment padding (`10/18` — E1). Horizontal too: a trackless
  /// segment hugs its label instead of sharing the width.
  static const EdgeInsetsGeometry tracklessSegmentPadding =
      EdgeInsetsDirectional.symmetric(vertical: 10, horizontal: 18);

  /// Gap between free pills (`10` — E1), against the tracked control's 5.
  static const double tracklessGap = 10;

  /// The segments, in logical order. Two on the board; more render fine.
  final List<JeebSegment> segments;

  /// Index of the selected segment. Values outside `0..segments.length-1` select
  /// nothing rather than throwing — a locale the app does not list must not
  /// crash Settings.
  final int selectedIndex;

  /// Fired with the tapped segment's index. Also fired when the already-selected
  /// segment is tapped: swallowing that would make the control feel dead.
  final ValueChanged<int> onChanged;

  /// Tracked (R5, default) or trackless free pills (E1).
  final JeebSegmentedPlacement placement;

  /// Track padding. Ignored when [placement] is trackless.
  final EdgeInsetsGeometry padding;

  /// Per-segment padding. Null takes the placement's own default —
  /// [defaultSegmentPadding] tracked, [tracklessSegmentPadding] trackless.
  final EdgeInsetsGeometry? segmentPadding;

  /// Glass hairline width — the track's, or a free pill's own (`1`).
  final double borderWidth;

  /// Maestro id for the track itself. Segments carry their own
  /// ([JeebSegment.identifier]); this one is optional and adds no node when null,
  /// so it cannot swallow them.
  final String? identifier;

  @override
  Widget build(BuildContext context) {
    final JeebSemanticColors semantics = _semantics(context);
    final bool trackless = placement == JeebSegmentedPlacement.trackless;
    final EdgeInsetsGeometry resolvedSegmentPadding = segmentPadding ??
        (trackless ? tracklessSegmentPadding : defaultSegmentPadding);

    final Row row = Row(
      mainAxisSize: trackless ? MainAxisSize.min : MainAxisSize.max,
      children: <Widget>[
        for (var index = 0; index < segments.length; index++) ...<Widget>[
          if (index > 0)
            SizedBox(width: trackless ? tracklessGap : _segmentGap),
          // Tracked segments are `flex:1`; E1's free pills hug their labels.
          if (trackless)
            Flexible(child: _segmentAt(index, resolvedSegmentPadding))
          else
            Expanded(child: _segmentAt(index, resolvedSegmentPadding)),
        ],
      ],
    );

    Widget track = trackless
        ? row
        : DecoratedBox(
            decoration: BoxDecoration(
              color: semantics.glassFill,
              borderRadius: _pillRadius,
              border: Border.all(
                color: semantics.glassBorderStrong,
                width: borderWidth,
              ),
            ),
            child: Padding(
              // Border-box correction: the board's stroke sits outside the 4px
              // track padding, but Flutter paints it over the child.
              padding: padding.add(EdgeInsets.all(borderWidth)),
              child: row,
            ),
          );

    if (identifier != null) {
      track = Semantics(
        identifier: identifier,
        // Both flags are mandatory (§7.5): without them this node swallows the
        // per-segment ids the Settings tests tap.
        container: true,
        explicitChildNodes: true,
        child: track,
      );
    }

    return track;
  }

  Widget _segmentAt(int index, EdgeInsetsGeometry resolvedPadding) => _Segment(
        segment: segments[index],
        selected: index == selectedIndex,
        padding: resolvedPadding,
        borderWidth: borderWidth,
        trackless: placement == JeebSegmentedPlacement.trackless,
        onTap: () => onChanged(index),
      );
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.segment,
    required this.selected,
    required this.padding,
    required this.borderWidth,
    required this.trackless,
    required this.onTap,
  });

  final JeebSegment segment;
  final bool selected;
  final EdgeInsetsGeometry padding;
  final double borderWidth;
  final bool trackless;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final JeebSemanticColors semantics = _semantics(context);
    // Trackless: the unselected pill carries the glass the track would have.
    final bool glassPill = trackless && !selected;

    final Widget body = DecoratedBox(
      decoration: BoxDecoration(
        // Selection is a fill swap, never a border (§5 #4). White fill + navy
        // ink; `onPrimary` is the sheet's `#FFFFFF`, `surface` its `#0B1351`.
        color: selected
            ? scheme.onPrimary
            : (trackless ? semantics.glassFill : Colors.transparent),
        borderRadius: _pillRadius,
        border: glassPill
            ? Border.all(
                color: semantics.glassBorderStrong,
                width: borderWidth,
              )
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: segment.key,
          onTap: onTap,
          borderRadius: _pillRadius,
          child: Padding(
            padding: padding,
            child: Text(
              segment.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // 13.5 is between the `bodySmall`/`body` rungs — design-exact px
              // are legal inside the kit (§4.4).
              style: context.jeebText.body.copyWith(
                fontSize: 13.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? scheme.surface : semantics.inkSoft,
              ),
            ),
          ),
        ),
      ),
    );

    return Semantics(
      identifier: segment.identifier,
      label: segment.semanticLabel ?? segment.label,
      button: true,
      container: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      child: ExcludeSemantics(child: body),
    );
  }
}

/// A bare `!` read crashes under harnesses themed with `ThemeData.light()`.
JeebSemanticColors _semantics(BuildContext context) =>
    Theme.of(context).extension<JeebSemanticColors>() ??
    JeebSemanticColors.midnight();
