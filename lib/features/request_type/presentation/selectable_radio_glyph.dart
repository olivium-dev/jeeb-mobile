import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

/// A decorative single-choice radio glyph used by the delivery-create cards
/// (Request type tier cards + Client Location option cards). There is no OMDS
/// radio primitive in the catalog, so this draws the ring + filled dot purely
/// from `colorScheme` roles. Pointer events are owned by the host card's
/// `InkWell`, so this is a pure visual (no gesture handling here).
///
/// On a navy selected card the ring is white (`onPrimary`); on a white
/// unselected card it is the brand navy (`primary`). The recon-flagged peach
/// (#FFB5A0) is a dark-scheme misuse and is deliberately not reproduced.
class SelectableRadioGlyph extends StatelessWidget {
  const SelectableRadioGlyph({super.key, required this.selected, this.ring});

  final bool selected;

  /// Optional explicit ring colour. Defaults to `onPrimary` when [selected],
  /// else `primary`.
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = ring ?? (selected ? scheme.onPrimary : scheme.primary);
    return SizedBox.square(
      dimension: Sizes.xLarge,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _Ring(color: color),
          if (selected) _Dot(color: color),
        ],
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: Sizes.threeXSmall),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Spacing.small,
      height: Spacing.small,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
