import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../request_type/presentation/selectable_radio_glyph.dart';

/// Selectable location option card on the Client Location screen
/// (Figma 56539:1444).
///
/// Selected: navy fill (`colorScheme.primary`), white label, filled radio.
/// Unselected: white surface, navy outline + navy label, empty radio. The
/// whole card is one tap target with merged radio semantics. The radio glyph
/// is the shared [SelectableRadioGlyph] (no OMDS radio primitive exists).
class ClientLocationOptionCard extends StatelessWidget {
  const ClientLocationOptionCard({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'client_location_option_current',
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? scheme.primary : scheme.surface,
          borderRadius: OmdsBorderRadius.uiLarge,
          child: InkWell(
            borderRadius: OmdsBorderRadius.uiLarge,
            onTap: onTap,
            child: _body(scheme),
          ),
        ),
      ),
    );
  }

  Widget _body(ColorScheme scheme) {
    final foreground = selected ? scheme.onPrimary : scheme.primary;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.large,
      ),
      decoration: BoxDecoration(
        borderRadius: OmdsBorderRadius.uiLarge,
        border: Border.all(
          color: selected ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Expanded(child: _Label(label: label, color: foreground)),
          const SizedBox(width: Spacing.medium),
          SelectableRadioGlyph(selected: selected, ring: foreground),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
      overflow: TextOverflow.ellipsis,
    );
  }
}
