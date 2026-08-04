import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/widgets/jeeb/jeeb_tier_row.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../tier_selection/domain/tier.dart';
import '../request_type_radio_id.dart';
import 'tier_catalog_lexicon.dart';

/// The tier picker of `/request-type` (MIDNIGHT · R9).
///
/// The board draws screen 08's catalog standalone, but `/tier-selection` was
/// deliberately deleted and the create flow standardized on `/request-type`, so
/// the live picker *is* this section (`screen-repo-map.md`).
///
/// R9 (doc-13 P0-3) rules the shape back to a **radio list**: five compact rows
/// — emoji, name, an optional `Most picked` badge, one ellipsized summary line
/// and a trailing Ø22 indicator — with no subtitle band above them and no
/// pricing note below them. The comparison-table anatomy (SLA chip, vehicle
/// line, four-dot price meter) is `JeebTierRow.catalog`, which no screen draws.
class TierCatalogSection extends StatelessWidget {
  const TierCatalogSection({
    super.key,
    required this.tiers,
    required this.selectedTierId,
    required this.onTierSelected,
  });

  /// The catalog in display order (Flash → Express → Standard → On-the-Way →
  /// Eco), exactly as the repository returns it.
  final List<Tier> tiers;

  /// The customer's choice. The cubit seeds it with the recommended tier on
  /// load (doc-13 P0-4 — R9 paints a lit row on first frame).
  final TierId? selectedTierId;

  final ValueChanged<TierId> onTierSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final tier in tiers) ...<Widget>[
          _TierRadioRow(
            tier: tier,
            selected: selectedTierId == tier.id,
            onTap: () => onTierSelected(tier.id),
          ),
          // Board list gap is 9; `xSmall` (8) is the nearest token.
          if (tier != tiers.last) const SizedBox(height: Spacing.xSmall),
        ],
      ],
    );
  }
}

/// One radio row. Everything visible is resolved here and handed to the kit as
/// plain strings — `lib/core/widgets/jeeb/` cannot import [TierId].
class _TierRadioRow extends StatelessWidget {
  const _TierRadioRow({
    required this.tier,
    required this.selected,
    required this.onTap,
  });

  final Tier tier;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final TierCatalogMark mark = tierCatalogMarkOf(tier.id);
    final String name = tierCatalogName(l10n, tier.id);
    final String summary = tierCatalogSummary(l10n, tier.id);

    return JeebTierRow.compact(
      mark: mark.emoji,
      title: name,
      summary: summary,
      // Rendered wherever the catalog flags a tier — never hardcoded to one.
      badge: tier.recommended ? l10n.requestTypeMostPickedBadge : null,
      selected: selected,
      onTap: onTap,
      // JM-024 / 63_W1_TEST_PLAN §2.2: the EXACT `request_type_<tier>_radio`
      // id the create-flow Maestro flow asserts (on-the-way → on_the_way).
      identifier: requestTypeRadioId(tier.id),
      semanticLabel: l10n.requestTypeTierSemanticLabel(
        title: name,
        speed: tierCatalogSpeed(l10n, tier.id),
        value: summary,
      ),
      selectedHint: l10n.requestTypeTierSelectedHint,
    );
  }
}
