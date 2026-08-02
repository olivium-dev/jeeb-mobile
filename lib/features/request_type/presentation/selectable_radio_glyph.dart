import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

/// Decorative single-choice radio glyph used by delivery-create cards.
/// No OMDS radio primitive in catalog; draws ring + filled dot from colorScheme roles.
/// Pointer events owned by host card's InkWell (pure visual, no gesture handling).
/// On navy selected card, ring is white (onPrimary); on white unselected card, brand navy (primary).
class SelectableRadioGlyph extends StatelessWidget {
  const SelectableRadioGlyph({super.key, required this.selected, this.ring});

  final bool selected;

  /// Optional explicit ring colour. Defaults to onPrimary when selected, else primary.
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
