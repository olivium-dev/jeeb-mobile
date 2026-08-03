import 'package:flutter/material.dart';

import '../../theme/jeeb_color_roles.dart';
import '../../theme/jeeb_text_styles.dart';

/// The five realized pill scales on the redesign board (§5 #6, 02-PLAN R2).
///
/// Lanes pass a **role, never a size**. The board draws five different pills
/// and the unselected ink is *not* constant — filters and sorts use the brown
/// `onSurfaceVariant`, while choices, quick replies and inline actions use
/// navy. One chip with one padding is visibly wrong on four of the ten spine
/// screens, so the whole table lives here.
///
/// | Role | Padding | Type | Unselected ink | Measured on |
/// |---|---|---|---|---|
/// | [filter] | `11/20` | 14.5/w600 | `onSurfaceVariant` | 04 `tpl 183-184`, 16, 24 |
/// | [sort] | `8/15` | 12.5/w600 (**w700 selected**) | `onSurfaceVariant` | 11 `tpl 661-663`, 19 |
/// | [choice] | `11/0` + `flex:1` | 13.5/w600 | `primary` | 17 `tpl 1005-1007` |
/// | [quickReply] | `8/13` | 12/w600 | `primary` | 21 `tpl 53-55`, 09 |
/// | [inlineAction] | `9/18` | 13/w600 | `primary` | 11 `tpl 678`, 04, 15, 24, 06 |
enum JeebChipRole {
  /// Tab-style filters above a list (04 `Pending 1`, 16 `Nearby 12`,
  /// 24 `Active 1`). The largest pill on the board.
  filter,

  /// Sort/period selectors (11 `Lowest price`, 19 `Today`). The only role whose
  /// **selected** state also steps up to w700 — measured, not invented.
  sort,

  /// Equal-width options in a flat row (17's ETA pills). Horizontal padding is
  /// **0** because the width comes from [JeebChipRow.expanded]'s `flex: 1`;
  /// the label centres itself.
  choice,

  /// Chat quick replies (21) and 09's saved-place pills.
  quickReply,

  /// A pill that reads as a button inside a card (04 `View offers`,
  /// 11 `Accept`, 15's tags, 24 `Track` / `Jeeb it again`, 06's quick-adds).
  inlineAction,
}

/// The Jeeb pill (§5 #6).
///
/// Selected: `colorScheme.primary` fill, `onPrimary` ink. Unselected: white
/// fill, `1.5px colorScheme.outline`, ink per [JeebChipRole]. Radius is always
/// a full pill.
///
/// **Height stays under 48dp on purpose.** 11's `client_offers_screen_test`
/// asserts the visual capsule is smaller than its tap target, so this widget
/// never applies a minimum height — wrap it in `MinTapTarget` (or a
/// `ConstrainedBox(minHeight: 48)`) at the call site, exactly as 09/11/16
/// already do.
///
/// **Semantics.** A node is added only when [identifier] or [semanticLabel] is
/// given. `onTap` alone adds nothing, because the dominant call-site idiom is
/// an outer `Semantics(identifier:, button:, selected:, label:, onTap:)` +
/// `ExcludeSemantics(child: chip)` with frozen ids (04 09 11 15 16 24) — a
/// second node there would either duplicate or swallow those ids.
///
/// **Light surfaces only.** The board has no on-navy unselected chip
/// (23 §5 states this explicitly), so this widget deliberately does not read
/// `JeebSurfaceTone`; 21's white `Track` pill and 23's starter-credit pill stay
/// screen-local shapes. `JeebTierChip` is the chip that re-tones.
class JeebSelectChip extends StatelessWidget {
  const JeebSelectChip({
    super.key,
    required this.role,
    required this.label,
    this.selected = false,
    this.onTap,
    this.count,
    this.leading,
    this.identifier,
    this.semanticLabel,
  });

  /// Gap between [leading], [label] and [count] — 6px on every measured pill
  /// (04 `tpl 184`, 09 `tpl 556`, 24 `tpl 1419`).
  static const double contentSpacing = 6;

  /// The 1.5px unselected stroke. Painted by the decoration, so it does **not**
  /// inset the child: a selected and an unselected pill in the same row have
  /// identical size and the row cannot jitter on tap. (This is the one place
  /// the kit does not fold the stroke into the padding the way
  /// `JeebOutlinedCard` does — there, folding keeps the box stable; here, it
  /// would be the thing that makes it move.)
  static const double borderWidth = 1.5;

  /// Which of the five measured scales to draw.
  final JeebChipRole role;

  /// The visible text. Always its own `Text` — never concatenated with
  /// [count], because `find.text('Active')` / `find.text('Pending')` are pinned
  /// on 04, 16 and 24.
  final String label;

  /// Navy fill + white ink.
  final bool selected;

  /// Makes the pill tappable. `null` renders a static pill.
  final VoidCallback? onTap;

  /// Optional trailing count. The board renders it **two ways** and both are
  /// honoured: selected → inline text in the label's own style
  /// (`Pending 1`, 04 `tpl 183`); unselected → a Ø18 solid-orange badge with
  /// white 11/w800 (04 `tpl 185`). Either way it is a separate `Text`.
  ///
  /// 16 bakes its counts into the localized label string instead
  /// (`jeeberFeedNearbyCount`) and passes `null` here.
  final int? count;

  /// Optional leading glyph — 24's 14px tune icon, 09's 14px category icon.
  /// Size and ink belong to the caller; the chip only places it.
  final Widget? leading;

  /// Maestro/`find.bySemanticsIdentifier` id, applied via an explicit
  /// `Semantics` wrapper (never OMDS's own `identifier:`).
  final String? identifier;

  /// Accessibility label when it must differ from [label].
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final _JeebChipMetrics metrics = _metricsFor(role);
    final TextStyle base = context.jeebText.bodySmall;
    final Color ink = selected
        ? scheme.onPrimary
        : (metrics.navyInk ? scheme.primary : scheme.onSurfaceVariant);
    final TextStyle labelStyle = base.copyWith(
      fontSize: metrics.fontSize,
      fontWeight: selected ? metrics.selectedWeight : base.fontWeight,
      color: ink,
    );

    Widget content = Padding(
      padding: metrics.padding,
      child: Row(
        // `min` shrink-wraps a free-standing pill; under `JeebChipRow.expanded`
        // the constraints are tight and `center` is what does the work.
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (leading != null) ...<Widget>[
            leading!,
            const SizedBox(width: contentSpacing),
          ],
          Text(
            label,
            style: labelStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (count != null) ...<Widget>[
            const SizedBox(width: contentSpacing),
            if (selected)
              Text('$count', style: labelStyle, maxLines: 1)
            else
              _JeebChipCountBadge(count: count!),
          ],
        ],
      ),
    );

    if (onTap != null) {
      // The splash must land above the fill and inside the capsule, so the
      // Material sits inside the decoration and the InkWell owns the shape.
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: content,
        ),
      );
    }

    Widget pill = DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? scheme.primary : scheme.surface,
        borderRadius: jeebPillRadius,
        border: selected
            ? null
            : Border.all(color: scheme.outline, width: borderWidth),
      ),
      child: content,
    );

    if (identifier != null || semanticLabel != null) {
      pill = Semantics(
        identifier: identifier,
        label: semanticLabel,
        button: onTap != null,
        selected: selected,
        onTap: onTap,
        // Both flags are mandatory: without them this node swallows the ids of
        // anything the consumer nests in `leading`.
        container: true,
        explicitChildNodes: true,
        child: pill,
      );
    }

    return pill;
  }
}

/// The row that lays chips out (§5 #6).
///
/// Three forms, all direction-agnostic (a plain `Row` mirrors itself):
///  * unnamed — a fixed row, gap [spacing] (11's sort bar, 04's tab bar);
///  * [JeebChipRow.expanded] — every child wrapped in `Expanded`, which is
///    17's ETA row (`flex: 1` + `padding: 11px 0`);
///  * [JeebChipRow.scrollable] — a **non-lazy** `Row` inside a horizontal
///    `SingleChildScrollView` (09, 16, 24). Non-lazy matters: a `ListView`
///    hides off-screen pills from `find.bySemanticsIdentifier`, which 09 calls
///    out as a real regression risk. Do not wrap this form in a second
///    scroll view.
class JeebChipRow extends StatelessWidget {
  const JeebChipRow({
    super.key,
    required this.children,
    this.spacing = defaultSpacing,
    this.padding = EdgeInsetsDirectional.zero,
    this.identifier,
  })  : expanded = false,
        scrollable = false;

  /// 17's ETA row: equal-width pills, no horizontal padding of their own.
  const JeebChipRow.expanded({
    super.key,
    required this.children,
    this.spacing = defaultSpacing,
    this.padding = EdgeInsetsDirectional.zero,
    this.identifier,
  })  : expanded = true,
        scrollable = false;

  /// 09 / 16 / 24: horizontally scrollable, non-lazy, direction-inheriting.
  const JeebChipRow.scrollable({
    super.key,
    required this.children,
    this.spacing = defaultSpacing,
    this.padding = EdgeInsetsDirectional.zero,
    this.identifier,
  })  : expanded = false,
        scrollable = true;

  /// `Spacing.xSmall` — 8px, the measured inter-chip gap on 11, 16, 19 and 24.
  /// (04's board gap is 10; it passes that explicitly.)
  static const double defaultSpacing = 8;

  /// The chips. Pass `JeebSelectChip`s; the row only lays them out.
  final List<Widget> children;

  /// Gap between chips.
  final double spacing;

  /// Gutter. On [JeebChipRow.scrollable] it becomes the scroll view's own
  /// padding, so the trailing gutter scrolls with the last pill instead of
  /// clipping it.
  final EdgeInsetsGeometry padding;

  /// Optional Maestro id for the row container (09's
  /// `client_location_saved_places_row`). Adds nothing when null.
  final String? identifier;

  /// True for [JeebChipRow.expanded].
  final bool expanded;

  /// True for [JeebChipRow.scrollable].
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final List<Widget> spaced = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      if (i > 0) {
        spaced.add(SizedBox(width: spacing));
      }
      spaced.add(
        expanded ? Expanded(child: children[i]) : children[i],
      );
    }

    Widget row = Row(
      // A scrolling row gets unbounded width, so it must shrink-wrap; a fixed
      // row fills so its chips pack at the *start* (which mirrors under RTL).
      mainAxisSize: scrollable ? MainAxisSize.min : MainAxisSize.max,
      children: spaced,
    );

    if (scrollable) {
      row = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        // No `reverse:`/`textDirection:` — direction is inherited so AR mirrors.
        padding: padding,
        child: row,
      );
    } else if (padding != EdgeInsetsDirectional.zero) {
      row = Padding(padding: padding, child: row);
    }

    if (identifier != null) {
      row = Semantics(
        identifier: identifier,
        container: true,
        explicitChildNodes: true,
        child: row,
      );
    }

    return row;
  }
}

/// The Ø18 orange count badge (04 `tpl 185`) — unselected chips only.
class _JeebChipCountBadge extends StatelessWidget {
  const _JeebChipCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final JeebRoles roles = context.jeebRoles;
    return Container(
      height: 18,
      constraints: const BoxConstraints(minWidth: 18),
      alignment: AlignmentDirectional.center,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: roles.accent,
        borderRadius: jeebPillRadius,
      ),
      child: Text(
        '$count',
        // 11/w800 has no ramp entry; `badge` is the nearest (10.5/w800) and the
        // kit is exempt from the `fontSize:` ban (§4.4).
        style: context.jeebText.badge.copyWith(
          fontSize: 11,
          color: roles.onAccent,
        ),
        maxLines: 1,
      ),
    );
  }
}

/// `border-radius: 999px` — the board's pill, shared by every chip here and by
/// `JeebTierChip`.
const BorderRadius jeebPillRadius = BorderRadius.all(Radius.circular(999));

/// The measured geometry of one [JeebChipRole].
@immutable
class _JeebChipMetrics {
  const _JeebChipMetrics({
    required this.padding,
    required this.fontSize,
    required this.selectedWeight,
    required this.navyInk,
  });

  final EdgeInsetsGeometry padding;
  final double fontSize;
  final FontWeight selectedWeight;

  /// Unselected ink: navy when true, brown `onSurfaceVariant` when false.
  final bool navyInk;
}

_JeebChipMetrics _metricsFor(JeebChipRole role) {
  switch (role) {
    case JeebChipRole.filter:
      return const _JeebChipMetrics(
        padding: EdgeInsetsDirectional.symmetric(vertical: 11, horizontal: 20),
        fontSize: 14.5,
        selectedWeight: FontWeight.w600,
        navyInk: false,
      );
    case JeebChipRole.sort:
      return const _JeebChipMetrics(
        padding: EdgeInsetsDirectional.symmetric(vertical: 8, horizontal: 15),
        fontSize: 12.5,
        // 11 `tpl 661` is the one measured selected pill that steps to w700.
        selectedWeight: FontWeight.w700,
        navyInk: false,
      );
    case JeebChipRole.choice:
      return const _JeebChipMetrics(
        padding: EdgeInsetsDirectional.symmetric(vertical: 11),
        fontSize: 13.5,
        selectedWeight: FontWeight.w600,
        navyInk: true,
      );
    case JeebChipRole.quickReply:
      return const _JeebChipMetrics(
        padding: EdgeInsetsDirectional.symmetric(vertical: 8, horizontal: 13),
        fontSize: 12,
        selectedWeight: FontWeight.w600,
        navyInk: true,
      );
    case JeebChipRole.inlineAction:
      return const _JeebChipMetrics(
        padding: EdgeInsetsDirectional.symmetric(vertical: 9, horizontal: 18),
        fontSize: 13,
        selectedWeight: FontWeight.w600,
        navyInk: true,
      );
  }
}
