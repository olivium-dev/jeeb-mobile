import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../l10n/app_localizations.dart';
import '../../tier_selection/cubit/tier_selection_cubit.dart';
import '../../tier_selection/cubit/tier_selection_state.dart';
import '../../tier_selection/data/tier_repository.dart';
import '../../tier_selection/domain/tier.dart';
import '../../location/presentation/widgets/delivery_create_layout.dart';
import '../../request_summary/application/compose_request_controller.dart';
import '../../request_summary/domain/request_draft.dart';
import 'request_type_radio_id.dart';
import 'request_tier_card.dart';
import 'request_location_row.dart';

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

  final VoidCallback? onChangeLocation;

  final ValueChanged<Tier>? onTierSelected;

  final ValueChanged<RequestDraft>? onContinue;

  @override
  Widget build(BuildContext context) {
    final provided = cubit;
    if (provided != null) {
      return BlocProvider<TierSelectionCubit>.value(
        value: provided,
        child: _Scaffold(onChangeLocation: onChangeLocation),
      );
    }
    return BlocProvider<TierSelectionCubit>(
      create: (_) =>
          TierSelectionCubit(repository: repository ?? _resolveRepository())
            ..load(),
      child: _Scaffold(onChangeLocation: onChangeLocation),
    );
  }

  TierRepository _resolveRepository() {
    if (sl.isRegistered<TierRepository>()) return sl<TierRepository>();
    return const FakeTierRepository();
  }
}

class _Scaffold extends StatelessWidget {
  const _Scaffold({this.onChangeLocation});

  final VoidCallback? onChangeLocation;

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
          ),
        ),
      ),
      bottomNavigationBar: BlocBuilder<TierSelectionCubit, TierSelectionState>(
        builder: (context, state) => _ContinueFooter(state: state),
      ),
    );
  }
}

class _ContinueFooter extends StatelessWidget {
  const _ContinueFooter({required this.state});

  final TierSelectionState state;

  @override
  Widget build(BuildContext context) {
    if (state.status != TierSelectionStatus.loaded) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final hasSelection = state.selectedTierId != null;
    return SafeArea(
      top: false,
      child: Padding(
        padding: DeliveryCreateLayout.pagePadding,
        child: Semantics(
          identifier: 'request_type_continue_cta',
          button: true,
          child: OmdsPrimaryButton(
            key: const Key('request-type-continue'),
            text: l10n.requestTypeContinue,
            isEnabled: hasSelection,
            onTap: () => _onContinue(context, hasSelection),
          ),
        ),
      ),
    );
  }

  void _onContinue(BuildContext context, bool hasSelection) {
    if (!hasSelection) return;
    final tier = state.selectedTier;
    if (tier != null && sl.isRegistered<ComposeRequestController>()) {
      sl<ComposeRequestController>().setTier(tier);
    }
    context.pushNamed('client-location');
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    this.onChangeLocation,
  });

  final TierSelectionState state;
  final VoidCallback? onChangeLocation;

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
        );
    }
  }
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({
    required this.state,
    this.onChangeLocation,
  });

  final TierSelectionState state;
  final VoidCallback? onChangeLocation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: DeliveryCreateLayout.pagePadding,
      children: [
        _SectionHeading(text: l10n.requestTypeChooseHeading),
        const SizedBox(height: Spacing.medium),
        _TierList(state: state),
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
    final tier = context.read<TierSelectionCubit>().state.selectedTier;
    if (tier != null && sl.isRegistered<ComposeRequestController>()) {
      sl<ComposeRequestController>().setTier(tier);
    }
    final handler = onChangeLocation;
    if (handler != null) {
      handler();
      return;
    }
    context.pushNamed('client-location');
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
  const _TierList({required this.state});

  final TierSelectionState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final tier in state.tiers) ...[
          _TierEntry(
            tier: tier,
            selected: state.selectedTierId == tier.id,
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
  });

  final Tier tier;
  final bool selected;

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
      semanticIdentifier: requestTypeRadioId(tier.id),
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
  }

  static IconData _tierIcon(TierId id) => switch (id) {
        TierId.flash => Icons.bolt_outlined,
        TierId.express => Icons.rocket_launch_outlined,
        TierId.standard => Icons.balance_outlined,
        TierId.onTheWay => Icons.handshake_outlined,
        TierId.eco => Icons.eco_outlined,
      };
}

class _RequestTierCopy {
  const _RequestTierCopy(this.title, this.speed, this.value);

  final String title;
  final String speed;
  final String value;

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
