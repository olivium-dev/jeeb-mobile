import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../l10n/app_localizations.dart';
import '../../tier_selection/cubit/tier_selection_cubit.dart';
import '../../tier_selection/cubit/tier_selection_state.dart';
import '../../tier_selection/data/tier_repository.dart';
import '../../tier_selection/domain/tier.dart';
import '../../location/presentation/widgets/delivery_create_layout.dart';
import '../../request_summary/domain/request_draft.dart';
import 'request_tier_card.dart';
import 'request_location_row.dart';

/// "Request type [Client]" screen (Figma 56535:2392) — the first step of the
/// delivery-create flow where the client picks a delivery tier and confirms
/// the pickup location.
///
/// Reuses the existing [TierSelectionCubit] + [TierRepository] (the tier
/// catalog source of truth); this screen is the Figma-accurate presentation
/// (5 emoji tiers + radio + a Location section), distinct from the legacy
/// richer [TierSelectionScreen] at `/tier-selection` (flagged to the CTO loop
/// for reconciliation — see comparison.md).
class RequestTypeScreen extends StatelessWidget {
  const RequestTypeScreen({
    super.key,
    this.cubit,
    this.repository,
    this.onChangeLocation,
    this.onTierSelected,
    this.onContinue,
  });

  final TierSelectionCubit? cubit;
  final TierRepository? repository;

  /// Invoked when the user taps "Change Location". Defaults to pushing the
  /// location picker route via the host.
  final VoidCallback? onChangeLocation;

  /// Invoked whenever the user taps a tier card.
  final ValueChanged<Tier>? onTierSelected;

  /// Invoked when the sticky "Continue" CTA is tapped with a complete tier
  /// selection. Carries a [RequestDraft] seeded with the chosen tier + pickup
  /// so the host can advance to `/request-summary` (Figma 56535:2392 →
  /// 56546:2303; router comment app_router.dart:352).
  final ValueChanged<RequestDraft>? onContinue;

  @override
  Widget build(BuildContext context) {
    final provided = cubit;
    if (provided != null) {
      return BlocProvider<TierSelectionCubit>.value(
        value: provided,
        child: _Scaffold(
          onChangeLocation: onChangeLocation,
          onTierSelected: onTierSelected,
          onContinue: onContinue,
        ),
      );
    }
    return BlocProvider<TierSelectionCubit>(
      create: (_) =>
          TierSelectionCubit(repository: repository ?? _resolveRepository())
            ..load(),
      child: _Scaffold(
        onChangeLocation: onChangeLocation,
        onTierSelected: onTierSelected,
        onContinue: onContinue,
      ),
    );
  }

  TierRepository _resolveRepository() {
    if (sl.isRegistered<TierRepository>()) return sl<TierRepository>();
    return const FakeTierRepository();
  }
}

class _Scaffold extends StatelessWidget {
  const _Scaffold({
    this.onChangeLocation,
    this.onTierSelected,
    this.onContinue,
  });

  final VoidCallback? onChangeLocation;
  final ValueChanged<Tier>? onTierSelected;
  final ValueChanged<RequestDraft>? onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: OMDSAppBar(
        title: l10n.requestTypeTitle,
        showBackButton: true,
        onBackPressed: () => Navigator.of(context).maybePop(),
      ),
      body: SafeArea(
        child: BlocBuilder<TierSelectionCubit, TierSelectionState>(
          builder: (context, state) => _Body(
            state: state,
            onChangeLocation: onChangeLocation,
            onTierSelected: onTierSelected,
          ),
        ),
      ),
      bottomNavigationBar: BlocBuilder<TierSelectionCubit, TierSelectionState>(
        builder: (context, state) => _ContinueFooter(
          state: state,
          onContinue: onContinue,
        ),
      ),
    );
  }
}

/// Sticky "Continue" footer (Figma 56535:2392 → 56546:2303). Pinned outside
/// the scroll body as a [Scaffold.bottomNavigationBar] so it never scrolls
/// away; enabled only once a tier is selected, then seeds a [RequestDraft]
/// for the host to forward to `/request-summary`.
class _ContinueFooter extends StatelessWidget {
  const _ContinueFooter({required this.state, this.onContinue});

  final TierSelectionState state;
  final ValueChanged<RequestDraft>? onContinue;

  @override
  Widget build(BuildContext context) {
    // Only meaningful once tiers have loaded; hidden during load/error so it
    // does not float over the spinner / error state.
    if (state.status != TierSelectionStatus.loaded) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final selectedId = state.selectedTierId;
    return SafeArea(
      top: false,
      child: Padding(
        padding: DeliveryCreateLayout.pagePadding,
        child: Semantics(
          identifier: 'request_type_continue',
          button: true,
          child: OmdsPrimaryButton(
            key: const Key('request-type-continue'),
            text: l10n.requestTypeContinue,
            isEnabled: selectedId != null,
            onTap: () => _onContinue(context, l10n),
          ),
        ),
      ),
    );
  }

  void _onContinue(BuildContext context, AppLocalizations l10n) {
    final selectedId = state.selectedTierId;
    if (selectedId == null) return;
    final copy = _RequestTierCopy.of(l10n, selectedId);
    final draft = RequestDraft(
      description: '',
      tierId: selectedId.name,
      tierName: copy.title,
      pickupAddress: l10n.requestTypeCurrentLocation,
    );
    onContinue?.call(draft);
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    this.onChangeLocation,
    this.onTierSelected,
  });

  final TierSelectionState state;
  final VoidCallback? onChangeLocation;
  final ValueChanged<Tier>? onTierSelected;

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
        return _LoadedView(
          state: state,
          onChangeLocation: onChangeLocation,
          onTierSelected: onTierSelected,
        );
    }
  }
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({
    required this.state,
    this.onChangeLocation,
    this.onTierSelected,
  });

  final TierSelectionState state;
  final VoidCallback? onChangeLocation;
  final ValueChanged<Tier>? onTierSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: DeliveryCreateLayout.pagePadding,
      children: [
        _SectionHeading(text: l10n.requestTypeChooseHeading),
        const SizedBox(height: Spacing.medium),
        _TierList(state: state, onTierSelected: onTierSelected),
        const SizedBox(height: Spacing.twoXLarge),
        _SectionHeading(text: l10n.requestTypeLocationHeading),
        const SizedBox(height: Spacing.medium),
        _LocationSection(onChangeLocation: onChangeLocation),
      ],
    );
  }
}

class _LocationSection extends StatelessWidget {
  const _LocationSection({this.onChangeLocation});

  final VoidCallback? onChangeLocation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return RequestLocationRow(
      currentLabel: l10n.requestTypeCurrentLocation,
      changeLabel: l10n.requestTypeChangeLocation,
      onChange: () => _onChange(context),
    );
  }

  void _onChange(BuildContext context) {
    final handler = onChangeLocation;
    if (handler != null) {
      handler();
    } else {
      Navigator.of(context).maybePop();
    }
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.headlineSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _TierList extends StatelessWidget {
  const _TierList({required this.state, this.onTierSelected});

  final TierSelectionState state;
  final ValueChanged<Tier>? onTierSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final tier in state.tiers) ...[
          _TierEntry(
            tier: tier,
            selected: state.selectedTierId == tier.id,
            onTierSelected: onTierSelected,
          ),
          if (tier != state.tiers.last)
            const SizedBox(height: Spacing.small),
        ],
      ],
    );
  }
}

class _TierEntry extends StatelessWidget {
  const _TierEntry({
    required this.tier,
    required this.selected,
    this.onTierSelected,
  });

  final Tier tier;
  final bool selected;
  final ValueChanged<Tier>? onTierSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final copy = _RequestTierCopy.of(l10n, tier.id);
    return RequestTierCard(
      icon: _tierIcon(tier.id),
      title: copy.title,
      speed: copy.speed,
      value: copy.value,
      selected: selected,
      semanticIdentifier: 'request_type_tier_${tier.id.name}',
      semanticLabel: l10n.requestTypeTierSemanticLabel(
        title: copy.title,
        speed: copy.speed,
        value: copy.value,
      ),
      selectedHint: l10n.requestTypeTierSelectedHint,
      onTap: () => _onTap(context),
    );
  }

  void _onTap(BuildContext context) {
    context.read<TierSelectionCubit>().selectTier(tier.id);
    onTierSelected?.call(tier);
  }

  /// OMDS-style vector glyph per tier — replaces the legacy emoji prefix that
  /// used to live in the localized title (⚡🚀⚖️🤝🌿). Material `IconData` is
  /// the design-system iconography idiom used across the app (see
  /// `client_offers/.../offer_card.dart`); OMDS exports no standalone icon
  /// component.
  static IconData _tierIcon(TierId id) => switch (id) {
        TierId.flash => Icons.bolt_outlined,
        TierId.express => Icons.rocket_launch_outlined,
        TierId.standard => Icons.balance_outlined,
        TierId.onTheWay => Icons.handshake_outlined,
        TierId.eco => Icons.eco_outlined,
      };
}

/// Resolves the emoji title + two description lines for a [TierId] from the
/// localized Request-type strings (Figma 56535:2392 copy).
class _RequestTierCopy {
  const _RequestTierCopy(this.title, this.speed, this.value);

  final String title;
  final String speed;
  final String value;

  /// Exhaustive sealed-class switch returning a small record per tier — the
  /// documented `flutter-function-20-line-limit` exemption #1 (bounded by the
  /// 5 tier cases, not arbitrary growth).
  static _RequestTierCopy of(AppLocalizations l10n, TierId id) => switch (id) {
        TierId.flash => _RequestTierCopy(
            l10n.tierFlashTitle, l10n.tierFlashSpeed, l10n.tierFlashValue),
        TierId.express => _RequestTierCopy(
            l10n.tierExpressTitle, l10n.tierExpressSpeed, l10n.tierExpressValue),
        TierId.standard => _RequestTierCopy(l10n.tierStandardTitle,
            l10n.tierStandardSpeed, l10n.tierStandardValue),
        TierId.onTheWay => _RequestTierCopy(l10n.tierOnTheWayTitle,
            l10n.tierOnTheWaySpeed, l10n.tierOnTheWayValue),
        TierId.eco => _RequestTierCopy(
            l10n.tierEcoTitle, l10n.tierEcoSpeed, l10n.tierEcoValue),
      };
}
