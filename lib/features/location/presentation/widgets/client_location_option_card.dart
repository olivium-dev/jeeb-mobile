import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_text_styles.dart';

/// Selectable location option card on the Client Location screen
/// (redesign-2026-08 screen 09, HTML tpl 549).
///
/// The board's address card: a red location pin, a navy title, and an optional
/// meta line beneath it. Unselected is white with a `1.5px colorScheme.outline`
/// stroke; selected swaps the FILL to navy (R8 — selection is a fill swap,
/// never a border swap) and inverts the ink. The radio glyph is gone: the
/// redesign has no radio anywhere.
///
/// [subtitle] is a SLOT, not a string, because the current-location card feeds
/// its live GPS state through it and that widget carries its own Semantics
/// identifiers. The outer node is therefore `explicitChildNodes` so those ids
/// survive (the canonical idiom, see `active_request_card.dart`).
class ClientLocationOptionCard extends StatelessWidget {
  const ClientLocationOptionCard({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  /// tpl 550 — the pin glyph, 19px, between `Sizes.medium` and `Sizes.large`.
  static const double _pinSize = 19;

  /// The redesign's outline weight (§5 #3).
  static const double _borderWidth = 1.5;

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Optional meta line rendered under [label] — keeps its own semantics.
  final Widget? subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'client_location_option_current',
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: label,
      container: true,
      explicitChildNodes: true,
      child: Material(
        color: selected ? scheme.primary : scheme.surface,
        borderRadius: OmdsBorderRadius.medium,
        child: InkWell(
          borderRadius: OmdsBorderRadius.medium,
          onTap: onTap,
          child: _body(context, scheme),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, ColorScheme scheme) {
    final foreground = selected ? scheme.onPrimary : scheme.primary;
    final detail = subtitle;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.small,
      ),
      decoration: BoxDecoration(
        borderRadius: OmdsBorderRadius.medium,
        border: Border.all(
          // Corrected rule: a brown ring on the navy fill reads as a defect,
          // so only the UNSELECTED branch moves to `outline`.
          color: selected ? scheme.primary : scheme.outline,
          width: _borderWidth,
        ),
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.location_on,
              size: _pinSize,
              color: selected ? scheme.onPrimary : scheme.error,
            ),
          ),
          const SizedBox(width: Spacing.small),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Text(
                    label,
                    style: context.jeebText.cardTitle
                        .copyWith(color: foreground),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: Spacing.twoXSmall),
                  detail,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
