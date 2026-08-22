import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_tier_row.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../request_summary/application/compose_request_controller.dart';
import '../../../request_type/presentation/widgets/tier_catalog_lexicon.dart';
import '../../../tier_selection/domain/tier.dart';

/// READ-ONLY disclosure of the tier the request will be POSTed at. The tier is
/// chosen once, on "Choose your request" — this screen shows it, never re-picks.
class ComposeTierSection extends StatelessWidget {
  const ComposeTierSection({super.key});

  @override
  Widget build(BuildContext context) {
    final Tier? tier = sl.isRegistered<ComposeRequestController>()
        ? sl<ComposeRequestController>().tier
        : null;
    // No seeded session (an isolated host, or a deep link straight here): the
    // screen must not invent a tier it cannot price.
    if (tier == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l10n.composeTierHeading,
          style: context.jeebText.h2.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: Spacing.small),
        _TierRow(tier: tier),
        const SizedBox(height: Spacing.medium),
      ],
    );
  }
}

/// The chosen tier, drawn as the catalog draws it but inert.
class _TierRow extends StatelessWidget {
  const _TierRow({required this.tier});

  final Tier tier;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = tierCatalogName(l10n, tier.id);
    final summary = tierCatalogSummary(l10n, tier.id);
    return JeebTierRow.compact(
      mark: tierCatalogMarkOf(tier.id).emoji,
      title: name,
      summary: summary,
      badge: tier.recommended ? l10n.requestTypeMostPickedBadge : null,
      selected: true,
      onTap: null,
      identifier: 'compose_tier_row',
      semanticLabel: l10n.requestTypeTierSemanticLabel(
        title: name,
        speed: tierCatalogSpeed(l10n, tier.id),
        value: summary,
      ),
      selectedHint: l10n.requestTypeTierSelectedHint,
    );
  }
}
