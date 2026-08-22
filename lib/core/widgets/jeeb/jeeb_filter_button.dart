import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../accessibility/accessibility.dart';
import '../../theme/jeeb_color_roles.dart';
import '../../theme/jeeb_semantic_colors.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../previews/jeeb_preview.dart';

/// The list-header filter disc that opens a filter sheet: a Ø[diameter] glass
/// circle, accent hairline + END-corner badge dot once [active].
class JeebFilterButton extends StatelessWidget {
  const JeebFilterButton({
    super.key,
    required this.onTap,
    required this.semanticLabel,
    this.active = false,
    this.identifier,
  });

  /// The visible circle, matching `JeebTopBar.circleDiameter`.
  static const double diameter = 40;

  /// The 1px glass stroke every circle carries (token sheet §4).
  static const double borderWidth = 1;

  /// The accent dot itself.
  static const double badgeDiameter = 9;

  /// Surface-coloured ring around the dot, so it separates from the stroke.
  static const double badgeRingWidth = Sizes.threeXSmall;

  /// Opens the filter sheet. Required — a disc that does nothing is not a
  /// state this widget draws.
  final VoidCallback onTap;

  /// Accessibility label, e.g. "Filter requests". The glyph has no text.
  final String semanticLabel;

  /// At least one facet is applied: accent border + badge dot.
  final bool active;

  /// Maestro / `find.bySemanticsIdentifier` id for the disc.
  final String? identifier;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final JeebSemanticColors glass = _glassOf(context);
    final JeebRoles roles = context.jeebRoles;

    Widget disc = SizedBox.square(
      dimension: diameter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: glass.glassFill,
          shape: BoxShape.circle,
          border: Border.all(
            color: active ? roles.accent : glass.glassBorder,
            width: borderWidth,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.tune,
            size: Sizes.medium,
            color: scheme.onSurface,
          ),
        ),
      ),
    );

    if (active) {
      disc = Stack(
        // The badge overhangs the circle's corner by design.
        clipBehavior: Clip.none,
        children: <Widget>[
          disc,
          const PositionedDirectional(
            top: -borderWidth,
            end: -borderWidth,
            child: _FilterBadgeDot(),
          ),
        ],
      );
    }

    return Semantics(
      identifier: identifier,
      label: semanticLabel,
      button: true,
      container: true,
      onTap: onTap,
      child: ExcludeSemantics(
        child: MinTapTarget(onTap: onTap, child: disc),
      ),
    );
  }
}

/// The accent dot in its surface-coloured ring.
class _FilterBadgeDot extends StatelessWidget {
  const _FilterBadgeDot();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final JeebRoles roles = context.jeebRoles;
    return SizedBox.square(
      dimension:
          JeebFilterButton.badgeDiameter + 2 * JeebFilterButton.badgeRingWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: SizedBox.square(
            dimension: JeebFilterButton.badgeDiameter,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: roles.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Read defensively: a bare `!` crashes under harnesses that theme with a
/// plain `ThemeData`, and every kit widget must survive that.
JeebSemanticColors _glassOf(BuildContext context) =>
    Theme.of(context).extension<JeebSemanticColors>() ??
    JeebSemanticColors.midnight();

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// Room for a caption and one Ø40 disc with its 48 dp target.
const Size _jeebFilterButtonBox = Size(390, 140);

/// Caption over one disc, so the two states can be compared at a glance.
Widget _jeebFilterButtonSpecimen(String caption, {required bool active}) {
  return Padding(
    padding: const EdgeInsetsDirectional.all(Spacing.xLarge),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(caption),
        const SizedBox(height: Spacing.medium),
        JeebFilterButton(
          onTap: () {},
          semanticLabel: 'Filter requests',
          active: active,
        ),
      ],
    ),
  );
}

/// Rest: glass hairline, no orange spent.
@JeebPreview(group: 'core', name: 'Rest', size: _jeebFilterButtonBox)
Widget jeebFilterButtonRest() =>
    _jeebFilterButtonSpecimen('Rest — no filter applied', active: false);

/// Active. Rendered as a matrix because the badge is pinned to the END corner
/// and RTL is the case that would expose a `left:`/`right:` slip.
@JeebPreview(
  group: 'core',
  name: 'Active with badge',
  size: _jeebFilterButtonBox,
  matrix: true,
)
Widget jeebFilterButtonActive() =>
    _jeebFilterButtonSpecimen('Active — a facet is applied', active: true);
