import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../../l10n/app_localizations.dart';

/// ETA strip rendered above the stepper while the parcel is in transit.
/// Hidden by the screen layer in every other lifecycle state.
///
/// redesign-2026-08: was a bespoke `primaryContainer` pill with three inline
/// runs. It is the kit's muted strip now — the same shape 12 gives its
/// door-code row (`[glyph] label … value`), so two neighbouring surfaces state
/// a fact the same way.
class DeliveryEtaBadge extends StatelessWidget {
  const DeliveryEtaBadge({super.key, required this.minutes});

  static const Key rootKey = Key('delivery-status-eta-badge');

  final int minutes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final isArriving = minutes <= 1;
    return JeebInfoNote.muted(
      key: rootKey,
      // Filled glyph (R10), inked navy rather than the muted tone's periwinkle
      // — the same call 12's door-code row makes for its key.
      icon: Icons.timer,
      iconSize: Sizes.large,
      iconColor: scheme.primary,
      gap: Spacing.small,
      // `label` rather than `text`: the board's periwinkle fails AA on
      // `surface-high` at this size by the repo's own pinned contrast guard.
      label: Text(
        l10n.deliveryEtaLabel,
        style: context.jeebText.bodySmall
            .copyWith(color: scheme.onSurfaceVariant),
      ),
      // The minutes are what the user came for — navy, card-title weight.
      trailing: Text(
        isArriving
            ? l10n.deliveryEtaArriving
            : l10n.deliveryEtaMinutes(minutes),
        style: context.jeebText.cardTitle.copyWith(color: scheme.primary),
      ),
    );
  }
}
