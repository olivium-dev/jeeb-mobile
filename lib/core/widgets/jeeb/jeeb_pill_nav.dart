import 'package:flutter/material.dart';

import '../../theme/jeeb_color_roles.dart';
import '../../theme/jeeb_radii.dart';
import '../../theme/jeeb_semantic_colors.dart';
import '../../theme/jeeb_shadows.dart';
import '../../theme/jeeb_text_styles.dart';

/// One slot of [JeebPillNav]. Product semantics only — the kit never decides
/// which tab points at which route (that is M2-01's call).
@immutable
class JeebPillNavItem {
  const JeebPillNavItem({
    required this.icon,
    required this.label,
    required this.identifier,
    this.semanticLabel,
  });

  /// Glyph drawn above the label. 20 at rest, [JeebPillNav.activeIconSize] on
  /// the orange pill (R1 `tpl 109-127`).
  final IconData icon;

  /// Always visible, both states — R1 never hides an inactive label.
  final String label;

  /// Frozen Maestro / `find.bySemanticsIdentifier` target for this slot.
  final String identifier;

  /// Screen-reader phrase when [label] alone reads badly. Defaults to [label].
  final String? semanticLabel;
}

/// The floating pill nav (MIDNIGHT M1-4, study-notes ruling 2).
///
/// A detached capsule that floats over `JeebMidnightField`: navy [ColorScheme.surface]
/// (`#0B1351`, the token sheet's "card/nav navy"), a 1px `glassBorder` hairline,
/// [JeebRadii.pill] and [JeebShadows.floatNav]. Opaque navy rather than the
/// board's `rgba(255,255,255,.07)` + `blur(16)`: the nav is persistent chrome and
/// the blur budget is 2 per screen, reserved for hero surfaces.
///
/// Five fixed slots, each `flex:1`, icon over an always-visible label. The
/// selected slot draws a `50×28` orange pill behind its icon and switches its
/// label to `onSurface`; every other slot is `onSurfaceVariant` periwinkle. That
/// pill is the ONLY orange the nav is allowed to spend (master plan §2.2).
///
/// Metrics measured off R1 `tpl 108-130` (440px board = dp): margin `0 16 20`,
/// padding `12/8`, icon row 28, gap 4, active pill `50×28`, icons 18 active /
/// 20 at rest, labels 11 → the ramp's [JeebTextStyles.label] (10.5, ±2 tolerance).
///
/// Pattern E: the 48dp minimum is met by HIT TEST, not layout — each slot's
/// [InkWell] spans the full capsule interior (~70dp) because the vertical
/// padding lives inside the tappable region, so no metric is inflated to reach it.
class JeebPillNav extends StatelessWidget {
  const JeebPillNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.margin = defaultMargin,
  })  : assert(items.length == slotCount, 'R1 draws exactly $slotCount slots'),
        assert(
          selectedIndex >= 0 && selectedIndex < slotCount,
          'selectedIndex must address one of the $slotCount slots',
        );

  /// R1 draws five tabs and the layout is tuned for five.
  static const int slotCount = 5;

  /// `0 16px 20px` — the capsule is inset 16 from both screen edges (wider than
  /// the 24 content gutter) and floats 20 above the bottom.
  static const EdgeInsetsGeometry defaultMargin =
      EdgeInsetsDirectional.fromSTEB(16, 0, 16, 20);

  /// Capsule inner inset on the cross axis. The `12` vertical half lives inside
  /// each slot instead, so the whole cell is tappable.
  static const double horizontalPadding = 8;

  /// Vertical inset, applied per slot (see [horizontalPadding]).
  static const double slotVerticalPadding = 12;

  /// Every slot's icon band is 28 tall — the active pill's height, which the
  /// resting icons match via padding rather than a taller box.
  static const double iconRowHeight = 28;

  /// Gap between the icon band and the label.
  static const double iconLabelGap = 4;

  /// The orange active pill, `50×28` at [JeebRadii.pill].
  static const double activePillWidth = 50;

  /// Icon size inside the active pill.
  static const double activeIconSize = 18;

  /// Icon size at rest.
  static const double iconSize = 20;

  /// The a11y floor each slot's hit region clears. Asserted, never imposed as a
  /// layout minimum (Pattern E).
  static const double minTapTarget = 48;

  /// Ceiling on the nav labels' text scale — the slots are fixed-width, so past
  /// this every label ellipsizes away. Icons + a readable label beat neither.
  static const double maxLabelTextScale = 1.3;

  /// Exactly [slotCount] entries, in visual order.
  final List<JeebPillNavItem> items;

  /// Index of the slot that draws the orange pill.
  final int selectedIndex;

  /// Fired with the tapped slot's index — including the already-selected one,
  /// so consumers can implement scroll-to-top / pop-to-root.
  final ValueChanged<int> onSelected;

  /// Outer inset. Directional so RTL mirrors without a call-site branch.
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final JeebSemanticColors semantics =
        Theme.of(context).extension<JeebSemanticColors>() ??
            JeebSemanticColors.midnight();
    final BorderRadius radius = BorderRadius.circular(JeebRadii.pill);

    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: radius,
          border: Border.all(color: semantics.glassBorder),
          boxShadow: JeebShadows.floatNav,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Material(
            type: MaterialType.transparency,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: horizontalPadding,
              ),
              child: Row(
                children: <Widget>[
                  for (int i = 0; i < items.length; i++)
                    Expanded(
                      child: _JeebPillNavSlot(
                        item: items[i],
                        isSelected: i == selectedIndex,
                        onTap: () => onSelected(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _JeebPillNavSlot extends StatelessWidget {
  const _JeebPillNavSlot({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final JeebPillNavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color ink = isSelected ? scheme.onSurface : scheme.onSurfaceVariant;

    return Semantics(
      identifier: item.identifier,
      label: item.semanticLabel ?? item.label,
      button: true,
      selected: isSelected,
      container: true,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: JeebPillNav.slotVerticalPadding,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  height: JeebPillNav.iconRowHeight,
                  child: isSelected
                      ? _ActivePill(icon: item.icon)
                      : Center(
                          child: Icon(
                            item.icon,
                            size: JeebPillNav.iconSize,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                ),
                const SizedBox(height: JeebPillNav.iconLabelGap),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  // Five fixed slots cannot grow, so an unclamped 2.0 scale
                  // ellipsizes every label to one glyph; degrade, don't erase.
                  textScaler: MediaQuery.textScalerOf(
                    context,
                  ).clamp(maxScaleFactor: JeebPillNav.maxLabelTextScale),
                  // Ramp `label` is 10.5/w700; the board drops resting labels to
                  // w600 so only the selected one carries full weight.
                  style: context.jeebText.label.copyWith(
                    color: ink,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The nav's whole orange budget: a `50×28` accent pill behind the active icon.
class _ActivePill extends StatelessWidget {
  const _ActivePill({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final JeebRoles roles = context.jeebRoles;

    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: roles.accent,
          borderRadius: BorderRadius.circular(JeebRadii.pill),
        ),
        child: SizedBox(
          width: JeebPillNav.activePillWidth,
          height: JeebPillNav.iconRowHeight,
          child: Center(
            child: Icon(
              icon,
              size: JeebPillNav.activeIconSize,
              color: roles.onAccent,
            ),
          ),
        ),
      ),
    );
  }
}
