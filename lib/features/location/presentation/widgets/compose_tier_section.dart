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
import '../../../tier_selection/application/default_tier.dart';
import '../../../tier_selection/data/tier_repository.dart';
import '../../../tier_selection/domain/tier.dart';

/// The delivery tier the request will be POSTed at. Since the UX merge this is
/// the ONE picker: Standard by default, "Change" opens the tier sheet.
class ComposeTierSection extends StatefulWidget {
  const ComposeTierSection({super.key, this.onTierChanged});

  /// Fires when a tier lands in the compose session (default or re-pick), so
  /// the host can gate its CTA on a priceable tier.
  final ValueChanged<Tier>? onTierChanged;

  @override
  State<ComposeTierSection> createState() => _ComposeTierSectionState();
}

class _ComposeTierSectionState extends State<ComposeTierSection> {
  /// True while the cold-entry default tier is being resolved from the catalog.
  bool _resolving = false;

  /// True when the default could not be resolved — the retry re-fetches.
  bool _failed = false;

  ComposeRequestController? get _compose =>
      sl.isRegistered<ComposeRequestController>()
      ? sl<ComposeRequestController>()
      : null;

  @override
  void initState() {
    super.initState();
    final compose = _compose;
    if (compose != null &&
        compose.tier == null &&
        sl.isRegistered<TierRepository>()) {
      _resolving = true;
      _resolveDefault();
    }
  }

  /// Seeds the recommended (Standard) tier into the fresh compose session so
  /// the customer only has to change it when they want something else.
  Future<void> _resolveDefault() async {
    Tier? tier;
    try {
      final tiers = await sl<TierRepository>().fetchTiers();
      // Wire-safe default first; else seed like the old picker did (fake
      // catalogs carry no serverId) — recommended, else the first row.
      tier = defaultTierOf(tiers) ??
          (tiers.isEmpty
              ? null
              : tiers.firstWhere((t) => t.recommended,
                  orElse: () => tiers.first));
    } catch (_) {
      tier = null;
    }
    if (!mounted) return;
    final compose = _compose;
    if (tier == null || compose == null) {
      setState(() {
        _resolving = false;
        _failed = true;
      });
      return;
    }
    // A tier that landed while the sheet resolved (resume race) is respected.
    if (compose.tier == null) compose.chooseTier(tier);
    widget.onTierChanged?.call(compose.tier ?? tier);
    setState(() {
      _resolving = false;
      _failed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final compose = _compose;
    // No compose session at all (an isolated host): nothing to disclose.
    if (compose == null) return const SizedBox.shrink();
    final tier = compose.tier;
    if (tier == null && !_resolving && !_failed) return const SizedBox.shrink();
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
            if (tier != null && canChange)
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
        if (tier != null)
          _TierRow(
            tier: tier,
            identifier: 'compose_tier_row',
            onTap: canChange ? _openPicker : null,
          )
        else if (_resolving)
          const _TierResolving()
        else
          _TierUnavailable(onRetry: () {
            setState(() {
              _resolving = true;
              _failed = false;
            });
            _resolveDefault();
          }),
        const SizedBox(height: Spacing.medium),
      ],
    );
  }

  Future<void> _openPicker() async {
    // The sheet's modal route restores the description field's focus on pop,
    // re-raising the keyboard over the CTA. Leave nothing to restore.
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await _ComposeTierSheet.show(context);
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusManager.instance.primaryFocus?.unfocus();
    });
    final compose = _compose;
    if (picked == null || compose == null) return;
    // chooseTier, not setTier: a re-pick must keep the typed/dictated session.
    setState(() => compose.chooseTier(picked));
    widget.onTierChanged?.call(picked);
  }
}

/// Catalog-fetch placeholder at the compact row's own height — no reflow jump.
class _TierResolving extends StatelessWidget {
  const _TierResolving();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsetsDirectional.symmetric(vertical: Spacing.medium),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}

/// The default tier could not be priced: an honest inline error with a retry —
/// the create CTA stays gated until a priceable tier lands.
class _TierUnavailable extends StatelessWidget {
  const _TierUnavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.homeVoiceTierUnavailable,
          style: context.jeebText.bodySmall.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Spacing.small),
        JeebCtaButton.outline(
          label: l10n.voiceRecordingRetry,
          identifier: 'compose_tier_retry',
          expand: false,
          onTap: onRetry,
        ),
      ],
    );
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
      onTap: onTap,
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
/// singleton a separate tier screen would re-seed and blank.
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
