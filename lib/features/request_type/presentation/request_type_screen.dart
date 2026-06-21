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

/// `request-type-selection` (blueprint) — the first step of the customer
/// delivery-create flow (JM-024). The client picks one of the **5 delivery
/// tiers** (Flash / Express / Standard / On-the-Way / Eco — T1) and taps
/// Continue to advance to `location-select`.
///
/// Per JM-024 AC1 the Continue CTA routes to `location-select` (NOT the legacy
/// `/request-summary` card) — the blueprint create flow is
/// tier → location-select → map-pin → order-chat. The screen owns its own
/// forward navigation via GoRouter (40_GUARDRAILS_ARCH §5.4/§10.8 — the source
/// screen wires its inbound edges); the optional [onContinue]/[onChangeLocation]
/// callbacks are test/dev seams that, when provided, REPLACE the default nav.
///
/// Reuses the existing [TierSelectionCubit] + [TierRepository] (the tier-catalog
/// source of truth, fed by `GET /v1/tiers` → T1's 5-tier mock catalog).
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

  /// Test/dev seam. When provided it REPLACES the default `location-select`
  /// navigation the "Change location" row triggers. (The W1 integrator's
  /// router already supplies the correct `→ /client-location` closure here.)
  final VoidCallback? onChangeLocation;

  /// LEGACY (divergent) seam — see 50_ROUTE_REQUESTS JM-024. The W0-era router
  /// passed a `→ /request-summary` closure here; JM-024 supersedes that edge
  /// (the create flow now goes tier → location-select → order-chat, NOT the
  /// summary card). The screen therefore NO LONGER invokes this for navigation
  /// — the tier-card tap only selects. Kept (unused) so the integrator's router
  /// builder compiles until it drops the arg.
  final ValueChanged<Tier>? onTierSelected;

  /// LEGACY (divergent) seam — see 50_ROUTE_REQUESTS JM-024. As above: the
  /// Continue CTA now self-navigates to `location-select` (JM-024 AC1) and does
  /// NOT invoke this `→ /request-summary` closure. Kept (unused) so the router
  /// builder compiles until the integrator drops the arg.
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

/// Sticky "Continue" footer. Pinned outside the scroll body as a
/// [Scaffold.bottomNavigationBar] so it never scrolls away; enabled only once a
/// tier is selected, then advances to `location-select` (JM-024 AC1).
class _ContinueFooter extends StatelessWidget {
  const _ContinueFooter({required this.state});

  final TierSelectionState state;

  @override
  Widget build(BuildContext context) {
    // Only meaningful once tiers have loaded; hidden during load/error so it
    // does not float over the spinner / error state.
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
    // iter6 B11: record the chosen tier (carries the live gateway UUID on
    // `Tier.wireId`) in the shared compose controller so the location-confirm
    // step can build the request payload and call POST /requests with it. The
    // tier cubit is scoped to THIS screen and is gone once we navigate, so the
    // selection must be lifted into the singleton controller here.
    final tier = state.selectedTier;
    if (tier != null && sl.isRegistered<ComposeRequestController>()) {
      sl<ComposeRequestController>().setTier(tier);
    }
    // EDGE: request-type-selection → location-select (21_NAV_PLAN.md §C,
    // JM-024 AC1 — replaces the divergent W0-era `→ /request-summary`). The
    // screen owns this edge (40_GUARDRAILS_ARCH §10.8); the selected tier lives
    // in the compose controller and is carried forward to order-chat through
    // the location leg (JM-025).
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
    // EDGE: request-type-selection → location-select (the same destination the
    // Continue CTA uses, JM-024 AC1). The optional callback REPLACES the
    // default nav for tests / the dev seam.
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
      // JM-024 / 63_W1_TEST_PLAN §2.2: each tier radio carries the EXACT
      // `request_type_<tier>_radio` id (e.g. on-the-way → on_the_way), the
      // i18n-safe target the create-flow Maestro flow asserts.
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
    // Selection only — the tier-card tap NO LONGER navigates (JM-024 supersedes
    // the W0-era `→ /request-summary` edge). Advancing to location-select is the
    // Continue CTA's job (AC1).
    context.read<TierSelectionCubit>().selectTier(tier.id);
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

/// Resolves the title + two description lines for a [TierId] from the localized
/// Request-type strings (Figma 56535:2392 copy).
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
