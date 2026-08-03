import 'package:flutter/material.dart';

import '../../theme/jeeb_color_roles.dart';

/// The onboarding pager indicator (redesign-2026-08 §5 #28).
///
/// The active page is a **pill**, not a bigger dot: `22×8` filled
/// `jeebRoles.accent`. Inactive pages are `Ø8` `colorScheme.surfaceContainerHighest`.
/// Gap 7. `OmdsDotIndicator` cannot express this — it renders
/// `shape: BoxShape.circle` with a single `activeSize` diameter, so the pill is
/// unreachable through it (01 §6).
///
/// **Measurement conflict, resolved in favour of the render.** Plan §5 #28 says
/// active `28×8` / gap 6; screen 01 — the widget's *only* consumer — measures
/// active `22×8` / gap 7 (`01-onboarding.html` `tpl 51-54`, verified here). The
/// HTML wins, as it does for 07's radio glyph, so [defaultActiveWidth] is 22 and
/// [defaultGap] is 7. Pass [planActiveWidth] / `gap: 6` to get the plan reading.
///
/// **Directional by construction.** A plain [Row] means index 0 sits on the
/// start edge — the left in LTR, the right in RTL — with no positional maths and
/// nothing to mirror by hand.
class JeebPageDots extends StatelessWidget {
  const JeebPageDots({
    super.key,
    required this.count,
    required this.activeIndex,
    this.dotSize = defaultDotSize,
    this.activeWidth = defaultActiveWidth,
    this.gap = defaultGap,
    this.duration = defaultDuration,
    this.identifier,
    this.semanticLabel,
  });

  /// Dot diameter, and the pill's height (`8` — 01 `tpl 52`).
  static const double defaultDotSize = 8;

  /// Active pill width as **measured on 01** (`22`).
  static const double defaultActiveWidth = 22;

  /// The width plan §5 #28 asks for (`28`). Kept as a named const so the
  /// conflict stays documented in code rather than in a review comment.
  static const double planActiveWidth = 28;

  /// Gap between dots (`7` — 01 `tpl 51`).
  static const double defaultGap = 7;

  /// Width transition when the active page changes.
  static const Duration defaultDuration = Duration(milliseconds: 200);

  /// How many pages the pager has. Renders nothing when `<= 0`.
  final int count;

  /// The active page, clamped into `0..count-1`. This is a **logical** index —
  /// the caller never flips it for RTL.
  final int activeIndex;

  /// Dot diameter / pill height.
  final double dotSize;

  /// Active pill width.
  final double activeWidth;

  /// Gap between dots.
  final double gap;

  /// Width animation duration. Pass [Duration.zero] to disable.
  final Duration duration;

  /// Maestro/`find.bySemanticsIdentifier` id, applied via an explicit
  /// `Semantics` wrapper (never OMDS's own `identifier:`). 01 passes
  /// `onboarding_page_dots`.
  final String? identifier;

  /// The screen-reader announcement — 01 passes
  /// `l10n.onboardingPageIndicator(current, total)`. The dots themselves carry
  /// no semantics, so this is the only signal.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return const SizedBox.shrink();
    }

    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color accent = context.jeebRoles.accent;
    final int active = activeIndex.clamp(0, count - 1);

    final List<Widget> dots = <Widget>[];
    for (var index = 0; index < count; index++) {
      if (index > 0) {
        dots.add(SizedBox(width: gap));
      }
      final bool isActive = index == active;
      dots.add(
        AnimatedContainer(
          duration: duration,
          curve: Curves.easeOut,
          width: isActive ? activeWidth : dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: isActive ? accent : scheme.surfaceContainerHighest,
            // A stadium, so the inactive dot is a circle and the active one a
            // pill from the same shape.
            borderRadius: BorderRadius.circular(dotSize),
          ),
        ),
      );
    }

    // Plain Row: index 0 lands on the start edge in both directions.
    final Widget row = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: dots,
    );

    if (identifier == null && semanticLabel == null) {
      return row;
    }
    return Semantics(
      identifier: identifier,
      label: semanticLabel,
      container: true,
      child: ExcludeSemantics(child: row),
    );
  }
}
