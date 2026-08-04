import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_outlined_card.dart';

/// "New Location" row on the Client Location screen: a start-aligned label and
/// a trailing circular add button, inside a [JeebOutlinedCard] so it reads as a
/// peer of the address card above it. The board draws no such row at all, so
/// this is a minimum restyle, not a rebuild — and the disc is PERIWINKLE, not
/// orange: the orange budget covers tile-drawn CTAs only (kit ruling 3).
class ClientLocationAddRow extends StatelessWidget {
  const ClientLocationAddRow({
    super.key,
    required this.label,
    required this.addSemanticLabel,
    required this.onTap,
    this.identifier = 'client_location_add_new',
  });

  final String label;
  final String addSemanticLabel;
  final VoidCallback onTap;

  /// Semantics identifier for the row. Defaults to the legacy
  /// `client_location_add_new` (kept for the existing delivery-create tests);
  /// the JM-024 location-select screen passes `location_select_new_location_cta`
  /// (63_W1_TEST_PLAN §2.3).
  final String identifier;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: identifier,
      button: true,
      label: addSemanticLabel,
      // The tap lives on the card so the ripple paints INSIDE the white fill;
      // an outer InkWell would splash underneath it and never be seen.
      child: ExcludeSemantics(
        child: _RowContent(label: label, onTap: onTap),
      ),
    );
  }
}

class _RowContent extends StatelessWidget {
  const _RowContent({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return JeebOutlinedCard(
      onTap: onTap,
      // The trailing disc already carries a 48dp box, so the card's own 13px
      // vertical inset would push the row past 70px — trim it back.
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.twoXSmall,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: context.jeebText.cardTitle
                  .copyWith(color: scheme.onSurface),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: Spacing.medium),
          _AddButton(onTap: onTap),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: Sizes.fourXLarge,
      child: Center(
        child: Container(
          width: Sizes.threeXLarge,
          height: Sizes.threeXLarge,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.secondary,
          ),
          // R10 — 20px is the board's content-circle glyph size.
          child: Icon(
            Icons.add,
            size: Sizes.large,
            color: scheme.onSecondary,
          ),
        ),
      ),
    );
  }
}
