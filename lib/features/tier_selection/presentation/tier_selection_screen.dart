import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/formatting/money_format.dart';
import '../../../core/theme/jeeb_color_roles.dart';
import '../../../l10n/app_localizations.dart';
import '../cubit/tier_selection_cubit.dart';
import '../cubit/tier_selection_state.dart';
import '../data/tier_repository.dart';
import '../domain/tier.dart';
import 'tier_card.dart';

/// Hosts the tier selection screen at `/tier-selection`.
///
/// One [TierSelectionCubit] per visit, kicked off with [TierSelectionCubit.load]
/// so the catalog hydrates on first frame. The screen is rendered as a list of
/// [TierCard]s with a sticky confirm CTA — once confirmed, the host (router /
/// caller-provided [onConfirmed]) is notified via [TierSelectionState.
/// confirmedTierId].
// ORPHAN (JEBV4-227, verified 2026-07-12): legacy route removed; cubit/repo remain live via RequestTypeScreen — see docs/project-understanding/reconciliation/orphans.md
class TierSelectionScreen extends StatelessWidget {
  const TierSelectionScreen({
    super.key,
    this.cubit,
    this.repository,
    this.onConfirmed,
  }) : assert(
          cubit == null || repository == null,
          'Provide either a cubit or a repository, not both.',
        );

  /// Optional cubit override — production builds a fresh one, widget tests
  /// inject one with a scripted repository.
  final TierSelectionCubit? cubit;

  /// Optional repository override. Defaults to the GetIt-registered
  /// [TierRepository], falling back to [FakeTierRepository] so the screen
  /// still renders during cold boot before DI runs.
  final TierRepository? repository;

  /// Optional confirm callback. The screen always emits
  /// [TierSelectionState.confirmedTierId] when the user taps confirm; this
  /// callback is the simplest way for the host to react without subscribing
  /// to the cubit directly.
  final ValueChanged<Tier>? onConfirmed;

  static const Key rootKey = Key('tier-selection-root');
  static const Key listKey = Key('tier-selection-list');
  static const Key confirmButtonKey = Key('tier-selection-confirm');
  static const Key retryButtonKey = Key('tier-selection-retry');
  static Key cardKey(TierId id) => ValueKey('tier-selection-card-${id.name}');

  @override
  Widget build(BuildContext context) {
    final provided = cubit;
    if (provided != null) {
      return BlocProvider<TierSelectionCubit>.value(
        value: provided,
        child: _Scaffold(onConfirmed: onConfirmed),
      );
    }
    return BlocProvider<TierSelectionCubit>(
      create: (_) =>
          TierSelectionCubit(repository: repository ?? _resolveRepository())
            ..load(),
      child: _Scaffold(onConfirmed: onConfirmed),
    );
  }

  /// Resolves from DI if registered (production path: DioTierRepository).
  /// Falls back to FakeTierRepository only in test environments where DI
  /// hasn't been initialised — never reachable in release builds.
  TierRepository _resolveRepository() {
    if (sl.isRegistered<TierRepository>()) {
      return sl<TierRepository>();
    }
    return const FakeTierRepository();
  }
}

class _Scaffold extends StatelessWidget {
  const _Scaffold({this.onConfirmed});

  final ValueChanged<Tier>? onConfirmed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'tier_selection_root',
      container: true,
      child: Scaffold(
        key: TierSelectionScreen.rootKey,
        appBar: OMDSAppBar(
          title: l10n.tierSelectionTitle,
          centerTitle: false,
        ),
        body: SafeArea(
          child: BlocConsumer<TierSelectionCubit, TierSelectionState>(
            listenWhen: (prev, curr) =>
                prev.confirmedTierId != curr.confirmedTierId &&
                curr.confirmedTierId != null,
            listener: (context, state) {
              final tier = state.selectedTier;
              if (tier != null) {
                onConfirmed?.call(tier);
              }
            },
            builder: (context, state) => _Body(state: state),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final TierSelectionState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (state.status) {
      case TierSelectionStatus.initial:
      case TierSelectionStatus.loading:
        return const Center(child: OmdsLoadingState());
      case TierSelectionStatus.error:
        return Center(
          child: OmdsErrorState(
            message: l10n.requestSummaryErrorNetwork,
            onRetry: () => context.read<TierSelectionCubit>().load(),
            retryLabel: l10n.requestSummaryRetry,
          ),
        );
      case TierSelectionStatus.loaded:
        return _LoadedView(state: state);
    }
  }
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.state});

  final TierSelectionState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.usingCachedFallback)
          _CachedBanner(message: l10n.tierSelectionCachedBanner),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.large,
            Spacing.medium,
            Spacing.large,
            Spacing.small,
          ),
          child: Text(
            l10n.tierSelectionSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            key: TierSelectionScreen.listKey,
            padding: const EdgeInsets.symmetric(horizontal: Spacing.large),
            itemCount: state.tiers.length,
            separatorBuilder: (_, _) => const SizedBox(height: Spacing.small),
            itemBuilder: (context, index) {
              final tier = state.tiers[index];
              return _TierListEntry(
                tier: tier,
                selected: state.selectedTierId == tier.id,
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(Spacing.large),
          child: Semantics(
            identifier: 'tier_selection_confirm_cta',
            container: true,
            button: true,
            child: OmdsPrimaryButton(
              key: TierSelectionScreen.confirmButtonKey,
              text: l10n.tierSelectionConfirm,
              isEnabled: state.canConfirm,
              onTap: () => context.read<TierSelectionCubit>().confirm(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Soft warning banner shown when the tier catalog fell back to bundled
/// defaults because the network was unreachable (AC3).
class _CachedBanner extends StatelessWidget {
  const _CachedBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      key: const Key('tier-selection-cached-banner'),
      margin: const EdgeInsets.symmetric(
        horizontal: Spacing.large,
        vertical: Spacing.xSmall,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.small,
        vertical: Spacing.xSmall,
      ),
      decoration: BoxDecoration(
        // Cached-catalog notice is informational -> semantic info role.
        color: context.jeebRoles.infoContainer,
        borderRadius: OmdsBorderRadius.small,
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: context.jeebRoles.onInfoContainer,
            size: Sizes.large,
          ),
          const SizedBox(width: Spacing.xSmall),
          Expanded(
            child: Text(
              message,
              style: textTheme.bodySmall
                  ?.copyWith(color: context.jeebRoles.onInfoContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _TierListEntry extends StatelessWidget {
  const _TierListEntry({required this.tier, required this.selected});

  final Tier tier;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = _tierName(l10n, tier.id);
    final description = _tierFooter(l10n, tier.id);
    final eta = _slaCopy(l10n, tier.slaMinutes);
    final price = l10n.tierSelectionPriceRange(
      _formatPrice(tier.priceLow, tier.currency),
      _formatPrice(tier.priceHigh, tier.currency),
    );
    final vehicleLabel = _vehicleLabel(l10n, tier.vehicleClass);
    final vehicleIcon = _vehicleIcon(tier.vehicleClass);
    return Padding(
      key: TierSelectionScreen.cardKey(tier.id),
      padding: EdgeInsets.zero,
      child: TierCard(
        identifier: 'tier_selection_card_${tier.id.name}',
        name: name,
        description: description,
        estimatedTime: eta,
        priceRange: price,
        vehicleLabel: vehicleLabel,
        vehicleIcon: vehicleIcon,
        selected: selected,
        onTap: () => context.read<TierSelectionCubit>().selectTier(tier.id),
        recommendedBadgeText:
            tier.recommended ? l10n.tierSelectionRecommendedBadge : null,
        semanticLabel: l10n.tierSelectionCardSemanticLabel(
          name: name,
          sla: eta,
          radius: vehicleLabel,
          price: price,
        ),
        selectedHint: l10n.tierSelectionCardSelectedHint,
      ),
    );
  }

  String _tierName(AppLocalizations l10n, TierId id) {
    switch (id) {
      case TierId.flash:
        return l10n.tierSelectionTierFlash;
      case TierId.express:
        return l10n.tierSelectionTierExpress;
      case TierId.standard:
        return l10n.tierSelectionTierStandard;
      case TierId.onTheWay:
        return l10n.tierSelectionTierOnTheWay;
      case TierId.eco:
        return l10n.tierSelectionTierEco;
    }
  }

  String _tierFooter(AppLocalizations l10n, TierId id) {
    switch (id) {
      case TierId.flash:
        return l10n.tierSelectionFooterFlash;
      case TierId.express:
        return l10n.tierSelectionFooterExpress;
      case TierId.standard:
        return l10n.tierSelectionFooterStandard;
      case TierId.onTheWay:
        return l10n.tierSelectionFooterOnTheWay;
      case TierId.eco:
        return l10n.tierSelectionFooterEco;
    }
  }

  String _slaCopy(AppLocalizations l10n, int? minutes) {
    if (minutes == null) return l10n.tierSelectionSlaNone;
    // Whole-hour SLAs render as "≤ N hr" so the copy stays readable for the
    // 2–4hr Standard tier; sub-hour SLAs fall back to minutes.
    if (minutes >= 60 && minutes % 60 == 0) {
      return l10n.tierSelectionSlaHours(minutes ~/ 60);
    }
    return l10n.tierSelectionSlaMinutes(minutes);
  }

  String _vehicleLabel(AppLocalizations l10n, TierVehicleClass cls) {
    switch (cls) {
      case TierVehicleClass.bikeOrScooter:
        return l10n.tierSelectionVehicleBikeScooter;
      case TierVehicleClass.scooterOrCar:
        return l10n.tierSelectionVehicleScooterCar;
      case TierVehicleClass.carOrVan:
        return l10n.tierSelectionVehicleCarVan;
      case TierVehicleClass.any:
        return l10n.tierSelectionVehicleAny;
    }
  }

  IconData _vehicleIcon(TierVehicleClass cls) {
    switch (cls) {
      case TierVehicleClass.bikeOrScooter:
        return Icons.two_wheeler_rounded;
      case TierVehicleClass.scooterOrCar:
        return Icons.directions_car_rounded;
      case TierVehicleClass.carOrVan:
        return Icons.local_shipping_rounded;
      case TierVehicleClass.any:
        return Icons.commute_rounded;
    }
  }

  String _formatPrice(int amount, String currency) =>
      // Lane item 3 (currency unification): the single MoneyFormat used by the
      // receipt and offer surfaces — "$12.00" for USD, "LBP 15,000.00"
      // otherwise. Replaces the local "15,000 USD"-style formatter so tiers no
      // longer disagree with the rest of the app.
      MoneyFormat.format(amount.toDouble(), currency: currency);
}
