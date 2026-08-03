import 'package:flutter/material.dart';

import '../../theme/jeeb_radii.dart';
import '../../theme/jeeb_semantic_colors.dart';
import '../../theme/jeeb_text_styles.dart';

const BorderRadius _pillRadius =
    BorderRadius.all(Radius.circular(JeebRadii.pill));

/// Gap between segments (`5` — R5 language toggle).
const double _segmentGap = 5;

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
    this.padding = defaultPadding,
    this.segmentPadding = defaultSegmentPadding,
    this.borderWidth = 1,
    this.identifier,
  });

  /// Track padding (`4` — 20 `tpl 1188`).
  static const EdgeInsetsGeometry defaultPadding = EdgeInsetsDirectional.all(4);

  /// Segment padding (`9/0` — 20 `tpl 1189`). Vertical only: the segments are
  /// `flex:1`, so horizontal padding would fight the flex.
  static const EdgeInsetsGeometry defaultSegmentPadding =
      EdgeInsetsDirectional.symmetric(vertical: 9);

  /// The segments, in logical order. Two on the board; more render fine.
  final List<JeebSegment> segments;

  /// Index of the selected segment. Values outside `0..segments.length-1` select
  /// nothing rather than throwing — a locale the app does not list must not
  /// crash Settings.
  final int selectedIndex;

  /// Fired with the tapped segment's index. Also fired when the already-selected
  /// segment is tapped: swallowing that would make the control feel dead.
  final ValueChanged<int> onChanged;

  /// Track padding.
  final EdgeInsetsGeometry padding;

  /// Per-segment padding.
  final EdgeInsetsGeometry segmentPadding;

  /// Track border width (`1` — the glass hairline).
  final double borderWidth;

  /// Maestro id for the track itself. Segments carry their own
  /// ([JeebSegment.identifier]); this one is optional and adds no node when null,
  /// so it cannot swallow them.
  final String? identifier;

  @override
  Widget build(BuildContext context) {
    final JeebSemanticColors semantics = _semantics(context);

    Widget track = DecoratedBox(
      decoration: BoxDecoration(
        color: semantics.glassFill,
        borderRadius: _pillRadius,
        border:
            Border.all(color: semantics.glassBorderStrong, width: borderWidth),
      ),
      child: Padding(
        // Border-box correction: the board's stroke sits outside the 4px track
        // padding, but Flutter paints it over the child.
        padding: padding.add(EdgeInsets.all(borderWidth)),
        child: Row(
          children: <Widget>[
            for (var index = 0; index < segments.length; index++) ...<Widget>[
              if (index > 0) const SizedBox(width: _segmentGap),
              Expanded(
                child: _Segment(
                  segment: segments[index],
                  selected: index == selectedIndex,
                  padding: segmentPadding,
                  onTap: () => onChanged(index),
                ),
              ),
            ],
          ],
        ),
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
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.segment,
    required this.selected,
    required this.padding,
    required this.onTap,
  });

  final JeebSegment segment;
  final bool selected;
  final EdgeInsetsGeometry padding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final JeebSemanticColors semantics = _semantics(context);

    final Widget body = DecoratedBox(
      decoration: BoxDecoration(
        // Selection is a fill swap, never a border (§5 #4). White fill + navy
        // ink; `onPrimary` is the sheet's `#FFFFFF`, `surface` its `#0B1351`.
        color: selected ? scheme.onPrimary : Colors.transparent,
        borderRadius: _pillRadius,
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
