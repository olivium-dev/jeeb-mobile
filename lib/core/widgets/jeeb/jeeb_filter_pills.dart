import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../theme/jeeb_color_roles.dart';
import '../../theme/jeeb_text_styles.dart';
import 'jeeb_select_chip.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../previews/jeeb_preview.dart';

/// One applied filter, accent-tinted because an applied filter IS state. Two
/// separate targets: the label reopens the sheet, the ✕ drops just this facet.
class JeebFilterPill extends StatelessWidget {
  const JeebFilterPill({
    super.key,
    required this.label,
    required this.onClear,
    required this.clearSemanticLabel,
    this.onTap,
    this.identifier,
    this.clearIdentifier,
  });

  /// The 1px accent hairline.
  static const double borderWidth = 1;

  /// Accent at 45% — a stroke, never a fill behind content.
  static const double borderAlpha = 0.45;

  /// The dismiss glyph.
  static const double clearGlyphSize = 14;

  /// The visible facet summary, e.g. "Status: Pending". Always its own `Text`
  /// so `find.text` keeps working on the consuming screens.
  final String label;

  /// Removes this facet. Required — a pill with no way off is a dead end.
  final VoidCallback onClear;

  /// Accessibility label for the dismiss target, e.g. "Clear status filter".
  final String clearSemanticLabel;

  /// Tapping the pill body reopens the sheet. Null leaves the body inert.
  final VoidCallback? onTap;

  /// Maestro id for the pill body.
  final String? identifier;

  /// Maestro id for the dismiss target.
  final String? clearIdentifier;

  @override
  Widget build(BuildContext context) {
    final JeebRoles roles = context.jeebRoles;
    final Color ink = roles.onAccentContainer;
    final TextStyle style = context.jeebText.caption.copyWith(
      fontWeight: FontWeight.w700,
      color: ink,
    );

    return Semantics(
      // Both flags are mandatory: without them this node swallows the two ids
      // below into one unreachable target.
      container: true,
      explicitChildNodes: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: roles.accentContainer,
          borderRadius: jeebPillRadius,
          border: Border.all(
            color: roles.accent.withValues(alpha: borderAlpha),
            width: borderWidth,
          ),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            Spacing.small,
            Spacing.twoXSmall,
            Spacing.twoXSmall,
            Spacing.twoXSmall,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Semantics(
                  identifier: identifier,
                  button: onTap != null,
                  onTap: onTap,
                  container: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onTap,
                    child: Text(
                      label,
                      style: style,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: JeebSelectChip.contentSpacing),
              Semantics(
                identifier: clearIdentifier,
                label: clearSemanticLabel,
                button: true,
                onTap: onClear,
                container: true,
                child: ExcludeSemantics(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onClear,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.all(
                        Spacing.twoXSmall,
                      ),
                      child: Icon(
                        Icons.close,
                        size: clearGlyphSize,
                        color: ink,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The applied-filter strip: a `Wrap`, so no pill parks off-screen, and an
/// empty `SizedBox.shrink()` when [pills] is empty.
class JeebFilterPillRow extends StatelessWidget {
  const JeebFilterPillRow({
    super.key,
    required this.pills,
    this.padding = EdgeInsetsDirectional.zero,
  });

  /// Gap between pills, both axes.
  static const double spacing = 6;

  /// The pills. Pass `JeebFilterPill`s; the row only lays them out.
  final List<Widget> pills;

  /// Gutter around the strip.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (pills.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: padding,
      child: Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: pills,
      ),
    );
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// Phone width, room for two runs of pills.
const Size _jeebFilterPillBox = Size(390, 200);

/// One pill with the callbacks stubbed.
Widget _jeebFilterPillOne(String label) => JeebFilterPill(
      label: label,
      onClear: () {},
      clearSemanticLabel: 'Clear $label',
      onTap: () {},
    );

/// Caption over a strip, on the preview surface.
Widget _jeebFilterPillSpecimen(String caption, List<Widget> pills) {
  return Padding(
    padding: const EdgeInsetsDirectional.all(Spacing.medium),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(caption),
        const SizedBox(height: Spacing.small),
        JeebFilterPillRow(pills: pills),
      ],
    ),
  );
}

/// The single-facet case — the shape most sessions actually show.
@JeebPreview(group: 'core', name: 'One pill', size: _jeebFilterPillBox)
Widget jeebFilterPillSingle() => _jeebFilterPillSpecimen(
      'One applied facet',
      <Widget>[_jeebFilterPillOne('Status: Pending')],
    );

/// A summary long enough to hit the ellipsis. Matrix: AR runs longer still.
@JeebPreview(
  group: 'core',
  name: 'Long label ellipsizes',
  size: _jeebFilterPillBox,
  matrix: true,
)
Widget jeebFilterPillLongLabel() => _jeebFilterPillSpecimen(
      'Label longer than the strip',
      <Widget>[
        _jeebFilterPillOne('Dropped off between 12 Aug and 22 Aug, any city'),
      ],
    );

/// Enough facets to wrap — the run-spacing case.
@JeebPreview(group: 'core', name: 'Row wraps', size: _jeebFilterPillBox)
Widget jeebFilterPillRowWrapping() => _jeebFilterPillSpecimen(
      'Four applied facets',
      <Widget>[
        _jeebFilterPillOne('Status: Pending'),
        _jeebFilterPillOne('Tier: Express'),
        _jeebFilterPillOne('Last 7 days'),
        _jeebFilterPillOne('Beirut'),
      ],
    );

/// Nothing applied: the strip must occupy no space at all.
@JeebPreview(group: 'core', name: 'Row empty', size: _jeebFilterPillBox)
Widget jeebFilterPillRowEmpty() =>
    _jeebFilterPillSpecimen('No facets applied', const <Widget>[]);
