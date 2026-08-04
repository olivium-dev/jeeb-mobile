import 'package:flutter/material.dart';

import '../../../../core/accessibility/accessibility.dart';
import '../../../../core/widgets/jeeb/jeeb_select_chip.dart';
import '../../domain/saved_location.dart';

/// The customer's saved places as a horizontal pill row (redesign-2026-08
/// screen 09, HTML tpl 555-558 — `Home` / `Work` / `Mama's`).
///
/// This replaces the stacked full-width saved-address cards. The board draws
/// the saved places as small pills directly under the address card, with no
/// section label above them.
///
/// The row is a **non-lazy** `Row` inside a horizontal scroll view
/// (`JeebChipRow.scrollable`): a `ListView` would build only the visible pills
/// and hide the rest from `find.bySemanticsIdentifier`, silently breaking the
/// per-address identifier contract.
class SavedAddressPillRow extends StatelessWidget {
  const SavedAddressPillRow({
    super.key,
    required this.addresses,
    required this.isSelected,
    required this.onSelect,
  });

  /// tpl 556 — the pill's leading category glyph.
  static const double _glyphSize = 14;

  final List<SavedLocation> addresses;

  /// Whether the address with this id is the current choice.
  final bool Function(String id) isSelected;

  final void Function(String id) onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return JeebChipRow.scrollable(
      identifier: 'client_location_saved_places_row',
      children: [
        for (final address in addresses)
          _SavedPill(
            address: address,
            selected: isSelected(address.id),
            scheme: scheme,
            onTap: () => onSelect(address.id),
          ),
      ],
    );
  }
}

class _SavedPill extends StatelessWidget {
  const _SavedPill({
    required this.address,
    required this.selected,
    required this.scheme,
    required this.onTap,
  });

  final SavedLocation address;
  final bool selected;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = address.address;
    // The wrapper is byte-identical to the one the stacked cards carried —
    // Maestro and the widget tests read these ids and this label composition.
    return Semantics(
      identifier: 'location_select_saved_address_${address.id}',
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: subtitle == null ? address.label : '${address.label}, $subtitle',
      child: ExcludeSemantics(
        // The 8/13-padded pill measures ~34px on its own, well under the 48dp
        // floor; the tap target is lifted here rather than in the kit so
        // selected and unselected pills stay pixel-identical.
        child: MinTapTarget(
          onTap: onTap,
          child: JeebSelectChip(
            role: JeebChipRole.quickReply,
            label: address.label,
            selected: selected,
            leading: Icon(
              _iconFor(address.category),
              size: SavedAddressPillRow._glyphSize,
              // Not orange: the pill glyph is not one of the board's accents.
              color: selected ? scheme.onInverseSurface : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  /// R10 — filled, single-colour glyphs; the outline variants are gone from
  /// the board entirely.
  IconData _iconFor(SavedLocationCategory cat) => switch (cat) {
        SavedLocationCategory.home => Icons.home,
        SavedLocationCategory.work => Icons.work,
        SavedLocationCategory.other => Icons.place,
      };
}
