import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../tier_selection/cubit/tier_selection_cubit.dart';
import '../../tier_selection/cubit/tier_selection_state.dart';
import '../../tier_selection/data/tier_repository.dart';
import '../../tier_selection/domain/tier.dart';
import '../../request_summary/application/compose_request_controller.dart';
import '../../request_summary/domain/request_draft.dart';
import 'request_location_row.dart';
import 'widgets/tier_catalog_section.dart';

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
///
/// redesign-2026-08 · screen 08 ("Tier catalog") lands here too: the board
/// draws it standalone, but `/tier-selection` was deliberately deleted and the
/// create flow standardized on `/request-type`, so the enhanced catalog is a
/// SECTION of this screen ([TierCatalogSection]) rather than a resurrected
/// route.
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

// Design gutter is 24 (HTML `padding … 24px`); DeliveryCreateLayout.pagePadding
// (20/16/20/32) is owned by location/ and shared with the 09 lane — not edited.
// Top inset is the board's 14 between the top bar and the catalog subtitle
// (08 `tpl 417`), rounded to the 12 token.
const _bodyPadding = EdgeInsetsDirectional.fromSTEB(
  Spacing.xLarge,
  Spacing.small,
  Spacing.xLarge,
  0,
);
const _footerPadding = EdgeInsetsDirectional.fromSTEB(
  Spacing.xLarge,
  0,
  Spacing.xLarge,
  Spacing.twoXLarge,
);

class _Scaffold extends StatelessWidget {
  const _Scaffold({this.onChangeLocation});

  final VoidCallback? onChangeLocation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      // The redesign header is an in-body row, not a Material app bar — no
      // elevation, no surface tint, title start-aligned next to a Ø40 circle.
      body: SafeArea(
        child: Column(
          children: [
            JeebTopBar.back(
              title: l10n.requestTypeChooseHeading,
              identifier: 'request_type_back',
              onLeadingPressed: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: BlocBuilder<TierSelectionCubit, TierSelectionState>(
                builder: (context, state) => _Body(
                  state: state,
                  onChangeLocation: onChangeLocation,
                ),
              ),
            ),
          ],
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
        padding: _footerPadding,
        child: Semantics(
          identifier: 'request_type_continue_cta',
          button: true,
          child: JeebCtaButton.primary(
            key: const Key('request-type-continue'),
            label: l10n.requestTypeContinue,
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
    // `SliverFillRemaining(hasScrollBody: false)` reproduces the board's
    // `flex:1` spacer — the tail of a tall viewport stays real emptiness
    // (~15% at 440x956 now that the catalog rows are two lines) — while still
    // scrolling at 200% text scale instead of overflowing.
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: _bodyPadding,
          sliver: SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TierCatalogSection(
                  tiers: state.tiers,
                  selectedTierId: state.selectedTierId,
                  onTierSelected: (id) =>
                      context.read<TierSelectionCubit>().selectTier(id),
                ),
                const SizedBox(height: Spacing.large),
                // NOT `JeebSectionLabel`: the board draws this 14/w700 navy
                // (HTML tpl-391), not the uppercase periwinkle eyebrow.
                Text(
                  l10n.requestTypeLocationHeading,
                  style: context.jeebText.cardTitle
                      .copyWith(color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: Spacing.small),
                _LocationSection(onChangeLocation: onChangeLocation),
                const Spacer(),
              ],
            ),
          ),
        ),
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
    // TODO(redesign-24): needs a resolved destination label at this step; the
    // flow picks the destination on the NEXT screen. Omitted, not faked
    // (JEBV4-176).
    return RequestLocationRow(
      currentLabel: l10n.requestTypeCurrentLocation,
      changeLabel: l10n.requestTypeChangeLocation,
      changeCtaLabel: l10n.requestTypeChangeCta,
      onChange: () => _onChange(context),
    );
  }

  void _onChange(BuildContext context) {
    // iter6 LIVE fix (tier-required): the "Change location" row jumps straight
    // to `client-location`, the SAME destination the Continue CTA reaches — but
    // unlike Continue it never recorded the chosen tier in the shared compose
    // controller. So a customer who picks a tier then taps "Change location"
    // (instead of Continue) lost `tierId`, and the location-confirm
    // `POST /requests` came back 400 `tier-required` (surfaced as a misleading
    // "Couldn't reach Jeeb"). Carry the selected tier through this path too, so
    // both routes feed the create with a non-null tier.
    final tier = context.read<TierSelectionCubit>().state.selectedTier;
    if (tier != null && sl.isRegistered<ComposeRequestController>()) {
      sl<ComposeRequestController>().setTier(tier);
    }
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

// The tier rows themselves live in `widgets/tier_catalog_section.dart`
// (redesign-2026-08 · 08): the picker is now the enhanced catalog — SLA chip,
// vehicle line and relative price meter per tier — so its copy resolution and
// its display lexicon sit with the section, not in this shell.
