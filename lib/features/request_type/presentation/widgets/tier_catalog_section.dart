import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../../core/widgets/jeeb/jeeb_tier_row.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../tier_selection/domain/tier.dart';
import '../request_type_radio_id.dart';
import 'tier_catalog_lexicon.dart';

/// The tier catalog (redesign-2026-08 · screen 08), rendered as the picker
/// section of `/request-type`.
///
/// 08 is drawn standalone on the board, but the app has no standalone tier
/// screen — `/tier-selection` was deliberately deleted and the create flow
/// standardized on `/request-type`, so the live picker *is* this section
/// (`screen-repo-map.md` §"The four corrections"). What 08 contributes over
/// the plain picker is the honest price signal: the indicative dollar range is
/// gone, replaced by a relative four-dot meter, an SLA chip and a vehicle line
/// per tier, closed by the note explaining that Jeebers — not the app — set
/// the price.
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

  /// The customer's choice, or null before they make one. Nothing is
  /// pre-selected: the catalog never chooses on their behalf.
  final TierId? selectedTierId;

  final ValueChanged<TierId> onTierSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final JeebSemanticColors semantics =
        Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.light();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l10n.tierCatalogSubtitle,
          style: context.jeebText.body.copyWith(color: semantics.mutedText),
        ),
        const SizedBox(height: Spacing.medium),
        for (final tier in tiers) ...<Widget>[
          _TierCatalogRow(
            tier: tier,
            selected: selectedTierId == tier.id,
            onTap: () => onTierSelected(tier.id),
          ),
          // Board list gap is 9; `xSmall` (8) is the nearest token.
          if (tier != tiers.last) const SizedBox(height: Spacing.xSmall),
        ],
        const SizedBox(height: Spacing.medium),
        // The one thing the board says out loud: there are no fixed prices,
        // the meter is relative and real money arrives as offers.
        JeebInfoNote.muted(
          icon: Icons.info,
          text: l10n.tierCatalogPricingNote,
        ),
      ],
    );
  }
}

/// One catalog row. Everything visible is resolved here and handed to the kit
/// as plain strings — `lib/core/widgets/jeeb/` cannot import [TierId].
class _TierCatalogRow extends StatelessWidget {
  const _TierCatalogRow({
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
    final String sla = tierCatalogSlaLabel(l10n, tier.slaMinutes);
    final String meta = tierCatalogMetaLabel(l10n, tier.id);
    final String price = tierCatalogPriceCaption(l10n, tier.id);

    return JeebTierRow.catalog(
      emoji: mark.emoji,
      name: name,
      priceLevel: mark.priceLevel,
      priceCaption: price,
      slaLabel: sla,
      metaLabel: meta,
      metaIcon: tierCatalogVehicleIcon(tier.vehicleClass),
      // Rendered wherever the catalog flags a tier — never hardcoded to one.
      badgeLabel: tier.recommended ? l10n.requestTypeMostPickedBadge : null,
      selected: selected,
      onTap: onTap,
      // JM-024 / 63_W1_TEST_PLAN §2.2: the EXACT `request_type_<tier>_radio`
      // id the create-flow Maestro flow asserts (on-the-way → on_the_way).
      identifier: requestTypeRadioId(tier.id),
      semanticLabel: l10n.tierCatalogCardSemanticLabel(
        name: name,
        sla: sla,
        meta: meta,
        price: price,
      ),
      selectedHint: l10n.requestTypeTierSelectedHint,
      // `≤ 1 hr` is a latin-numeric run RTL would reorder into `hr 1 ≥`; the
      // null-SLA label is pure prose and must follow the ambient direction.
      slaForceLtr: tier.slaMinutes != null,
    );
  }
}
