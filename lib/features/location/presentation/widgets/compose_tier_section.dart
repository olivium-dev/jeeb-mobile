import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/jeeb_scrim.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../../core/widgets/jeeb/jeeb_tier_row.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../request_summary/application/compose_request_controller.dart';
import '../../../request_type/presentation/widgets/tier_catalog_lexicon.dart';
import '../../../tier_selection/data/tier_repository.dart';
import '../../../tier_selection/domain/tier.dart';

/// The delivery tier the request will be POSTed at. The voice path picks one
/// for the customer, so it has to be visible and changeable before submit.
class ComposeTierSection extends StatefulWidget {
  const ComposeTierSection({super.key});

  @override
  State<ComposeTierSection> createState() => _ComposeTierSectionState();
}

class _ComposeTierSectionState extends State<ComposeTierSection> {
  ComposeRequestController? get _compose =>
      sl.isRegistered<ComposeRequestController>()
      ? sl<ComposeRequestController>()
      : null;

  @override
  Widget build(BuildContext context) {
    final tier = _compose?.tier;
    // No seeded session (an isolated host, or a deep link straight here): the
    // screen must not invent a tier it cannot price.
    if (tier == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final canChange = sl.isRegistered<TierRepository>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                l10n.composeTierHeading,
                style: context.jeebText.h2.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            if (canChange)
              Semantics(
                identifier: 'compose_tier_change',
                button: true,
                label: l10n.requestTypeChangeCta,
                container: true,
                child: TextButton(
                  onPressed: _openPicker,
                  child: Text(l10n.requestTypeChangeCta),
                ),
              ),
          ],
        ),
        const SizedBox(height: Spacing.small),
        _TierRow(
          tier: tier,
          identifier: 'compose_tier_row',
          onTap: canChange ? _openPicker : null,
        ),
        const SizedBox(height: Spacing.medium),
      ],
    );
  }

  Future<void> _openPicker() async {
    // The description field above is usually still focused; the sheet's modal
    // route RESTORES that focus when it pops, and the re-raised keyboard hides
    // the "Confirm location" CTA (two failed submits on device). Dropping focus
    // before the push leaves nothing to restore; the post-pop unfocus covers
    // the case where the framework re-focuses on the next frame.
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await _ComposeTierSheet.show(context);
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusManager.instance.primaryFocus?.unfocus();
    });
    final compose = _compose;
    if (picked == null || compose == null) return;
    setState(() => compose.changeTier(picked));
  }
}

/// One catalog row, display-only when [onTap] is null.
class _TierRow extends StatelessWidget {
  const _TierRow({
    required this.tier,
    required this.identifier,
    required this.onTap,
    this.selected = true,
  });

  final Tier tier;
  final String identifier;
  final VoidCallback? onTap;
  final bool selected;

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
      selected: selected,
      onTap: onTap ?? () {},
      identifier: identifier,
      semanticLabel: l10n.requestTypeTierSemanticLabel(
        title: name,
        speed: tierCatalogSpeed(l10n, tier.id),
        value: summary,
      ),
      selectedHint: l10n.requestTypeTierSelectedHint,
    );
  }
}

/// The change affordance. A sheet, not a route: the create session lives in a
/// singleton the tier step would otherwise re-seed and blank.
class _ComposeTierSheet extends StatefulWidget {
  const _ComposeTierSheet();

  static Future<Tier?> show(BuildContext context) {
    return showModalBottomSheet<Tier>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      barrierColor: JeebScrim.barrier(context),
      shape: const RoundedRectangleBorder(
        borderRadius: OmdsBorderRadius.topXLarge,
      ),
      builder: (_) => const _ComposeTierSheet(),
    );
  }

  @override
  State<_ComposeTierSheet> createState() => _ComposeTierSheetState();
}

class _ComposeTierSheetState extends State<_ComposeTierSheet> {
  late Future<List<Tier>> _tiers = _fetch();

  Future<List<Tier>> _fetch() => sl<TierRepository>().fetchTiers();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = sl.isRegistered<ComposeRequestController>()
        ? sl<ComposeRequestController>().tier
        : null;
    return Semantics(
      identifier: 'compose_tier_sheet',
      explicitChildNodes: true,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                l10n.composeTierSheetTitle,
                style: context.jeebText.h2.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: Spacing.medium),
              Flexible(
                child: SingleChildScrollView(
                  child: FutureBuilder<List<Tier>>(
                    future: _tiers,
                    builder: (context, snapshot) =>
                        _body(context, l10n, snapshot, selected),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l10n,
    AsyncSnapshot<List<Tier>> snapshot,
    Tier? selected,
  ) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Padding(
        padding: EdgeInsets.all(Spacing.xLarge),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final tiers = snapshot.data;
    if (snapshot.hasError || tiers == null || tiers.isEmpty) {
      return JeebEmptyState(
        status: JeebEmptyStateStatus.error,
        headline: l10n.homeVoiceTierUnavailable,
        action: IntrinsicWidth(
          child: JeebCtaButton.primary(
            label: l10n.voiceRecordingRetry,
            identifier: 'compose_tier_sheet_retry',
            expand: false,
            onTap: () => setState(() => _tiers = _fetch()),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final tier in tiers) ...<Widget>[
          _TierRow(
            tier: tier,
            identifier: 'compose_tier_option_${tier.id.name}',
            selected: tier.id == selected?.id,
            onTap: () => Navigator.of(context).pop(tier),
          ),
          if (tier != tiers.last) const SizedBox(height: Spacing.xSmall),
        ],
      ],
    );
  }
}
