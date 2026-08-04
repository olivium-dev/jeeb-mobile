import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_outlined_card.dart';

/// Selectable location option card on the Client Location screen (MIDNIGHT
/// R11's address card).
///
/// A danger-red location pin, a white title, and an optional meta line beneath
/// it, on rest glass. Selection is a FILL swap to emphasis glass (R8 — never a
/// thicker border), delegated to `JeebOutlinedCard`'s own selected state so the
/// subtree re-tones itself. The radio glyph is gone: the board has none.
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

  /// R11 — the card's pin glyph, 19px, between `Sizes.medium` and `Sizes.large`.
  static const double _pinSize = 19;

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Optional meta line rendered under [label] — keeps its own semantics.
  final Widget? subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final detail = subtitle;
    return Semantics(
      identifier: 'client_location_option_current',
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: label,
      container: true,
      explicitChildNodes: true,
      child: JeebOutlinedCard(
        state: selected ? JeebCardState.selected : JeebCardState.normal,
        onTap: onTap,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.medium,
          vertical: Spacing.small,
        ),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.location_on,
                size: _pinSize,
                color: scheme.error,
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
                          .copyWith(color: scheme.onSurface),
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
      ),
    );
  }
}
