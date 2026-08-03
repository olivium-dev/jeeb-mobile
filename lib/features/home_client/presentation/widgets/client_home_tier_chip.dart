import 'package:flutter/material.dart';

import '../../../../core/widgets/jeeb/jeeb_tier_chip.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/client_home_request.dart';

/// Maps this feature's [ClientRequestTier] onto the kit's [JeebTierChip].
///
/// The kit deliberately imports none of the app's six tier enums and owns no
/// l10n, so every feature supplies this two-line adapter: the tier itself via
/// [JeebTier.fromId] (case/separator-insensitive, so `onTheWay` resolves) and
/// the **localized** name from the ARB. The ⚡🚀🟦🤝🌿 lexicon stays kit-owned —
/// it must never be spelled in this feature.
///
/// [ClientRequestTier.unknown] renders **nothing at all**: an unrecognised
/// server tier is not worth an empty pill, and a card must still be readable
/// when the backend introduces a tier mid-deploy.
class ClientHomeTierChip extends StatelessWidget {
  const ClientHomeTierChip({super.key, required this.tier});

  final ClientRequestTier tier;

  @override
  Widget build(BuildContext context) {
    if (tier == ClientRequestTier.unknown) return const SizedBox.shrink();
    return JeebTierChip(
      tier: JeebTier.fromId(tier.name),
      label: _label(AppLocalizations.of(context)),
    );
  }

  String _label(AppLocalizations l10n) {
    switch (tier) {
      case ClientRequestTier.flash:
        return l10n.tierSelectionTierFlash;
      case ClientRequestTier.express:
        return l10n.tierSelectionTierExpress;
      case ClientRequestTier.standard:
        return l10n.tierSelectionTierStandard;
      case ClientRequestTier.onTheWay:
        return l10n.tierSelectionTierOnTheWay;
      case ClientRequestTier.eco:
        return l10n.tierSelectionTierEco;
      case ClientRequestTier.unknown:
        return '';
    }
  }
}
