import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/theme/jeeb_radii.dart';
import '../../../core/theme/jeeb_semantic_colors.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../core/widgets/jeeb/jeeb_tier_row.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../location/data/location_repository.dart';
import '../../tier_selection/cubit/tier_selection_cubit.dart';
import '../../tier_selection/cubit/tier_selection_state.dart';
import '../../tier_selection/data/tier_repository.dart';
import '../../request_summary/application/compose_request_controller.dart';
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
/// screen wires its inbound edges); the optional [onChangeLocation] callback is
/// a test/dev seam that, when provided, REPLACES the default nav.
///
/// This is the ONE place the delivery tier is chosen: every create door lands
/// here first, and the location step only discloses what was picked.
///
/// "Change" is a PICKER, not a second create door: it opens `capture-location`
/// and renders the popped point in place — it used to push the compose screen.
///
/// Reuses the existing [TierSelectionCubit] + [TierRepository] (the tier-catalog
/// source of truth, fed by `GET /v1/tiers` → T1's 5-tier mock catalog).
///
/// MIDNIGHT · R9 folds the "Tier catalog" board into this screen: the picker is
/// [TierCatalogSection]'s five compact radio rows rather than a resurrected
/// `/tier-selection` route.
class RequestTypeScreen extends StatelessWidget {
  const RequestTypeScreen({
    super.key,
    this.cubit,
    this.repository,
    this.onChangeLocation,
    this.resumeSession = false,
  });

  final TierSelectionCubit? cubit;
  final TierRepository? repository;

  /// Test/dev seam. When provided it REPLACES the default `capture-location`
  /// picker nav. The router no longer supplies it; the screen owns that edge.
  final VoidCallback? onChangeLocation;

  /// True when the compose session was already seeded (the voice door). Continue
  /// then RE-PICKS the tier instead of starting a session, keeping the clip.
  final bool resumeSession;

  @override
  Widget build(BuildContext context) {
    final provided = cubit;
    if (provided != null) {
      return BlocProvider<TierSelectionCubit>.value(
        value: provided,
        child: _Scaffold(
          onChangeLocation: onChangeLocation,
          resumeSession: resumeSession,
        ),
      );
    }
    return BlocProvider<TierSelectionCubit>(
      create: (_) =>
          TierSelectionCubit(repository: repository ?? _resolveRepository())
            ..load(),
      child: _Scaffold(
        onChangeLocation: onChangeLocation,
        resumeSession: resumeSession,
      ),
    );
  }

  TierRepository _resolveRepository() {
    if (sl.isRegistered<TierRepository>()) return sl<TierRepository>();
    return const FakeTierRepository();
  }
}

// Design gutter is 24 (HTML `padding … 24px`); DeliveryCreateLayout.pagePadding
// (20/16/20/32) is owned by location/ and shared with the 09 lane — not edited.
//
// The bottom inset is NOT on the board (which draws a 956dp viewport where the
// content never reaches the footer): on a 360x780 phone the catalog scrolls,
// and without it the "Deliver to" card ends flush against the docked Continue
// pill at the end of the scroll. It costs nothing on tall viewports — the
// `Spacer` below absorbs it.
const _bodyPadding = EdgeInsetsDirectional.fromSTEB(
  Spacing.xLarge,
  Spacing.small,
  Spacing.xLarge,
  Spacing.large,
);
const _footerPadding = EdgeInsetsDirectional.fromSTEB(
  Spacing.xLarge,
  0,
  Spacing.xLarge,
  Spacing.twoXLarge,
);

class _Scaffold extends StatefulWidget {
  const _Scaffold({this.onChangeLocation, this.resumeSession = false});

  final VoidCallback? onChangeLocation;
  final bool resumeSession;

  @override
  State<_Scaffold> createState() => _ScaffoldState();
}

class _ScaffoldState extends State<_Scaffold> {
  /// The point the picker handed back. Owned above BOTH the body (which draws
  /// it) and the footer (which carries it forward), so Continue cannot drop it.
  LocationPoint? _picked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // R9's field: ONE orange radial, measured at the top-start corner (board
    // `at 10% -8%`). Content variant — no rings, no twinkles, tile is STATIC.
    return JeebMidnightField(
      variant: JeebFieldVariant.content,
      glowPlacement: JeebFieldGlowPlacement.topStart,
      child: Scaffold(
        backgroundColor: Colors.transparent,
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
                    picked: _picked,
                    onPicked: (point) => setState(() => _picked = point),
                    onChangeLocation: widget.onChangeLocation,
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar:
            BlocBuilder<TierSelectionCubit, TierSelectionState>(
              builder: (context, state) => _ContinueFooter(
                state: state,
                picked: _picked,
                resumeSession: widget.resumeSession,
              ),
            ),
      ),
    );
  }
}

/// Sticky "Continue" footer. Pinned outside the scroll body as a
/// [Scaffold.bottomNavigationBar] so it never scrolls away; enabled only once a
/// tier is selected, then advances to `location-select` (JM-024 AC1).
class _ContinueFooter extends StatelessWidget {
  const _ContinueFooter({
    required this.state,
    this.picked,
    this.resumeSession = false,
  });

  final TierSelectionState state;

  /// The pickup the "Change" picker returned, carried into the compose session.
  final LocationPoint? picked;
  final bool resumeSession;

  @override
  Widget build(BuildContext context) {
    // Only meaningful once there are tiers to pick; hidden over the loading,
    // empty and error bodies so it never docks under an unusable screen.
    if (state.status != TierSelectionStatus.loaded || state.tiers.isEmpty) {
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
          // R9 draws the CTA orange with an outer glow — a tile-drawn CTA,
          // inside the budget. The kit variant owns the fill, ink and glow.
          child: JeebCtaButton.accent(
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
      final compose = sl<ComposeRequestController>();
      // A resumed session (the voice door) keeps its clip; a cold entry starts
      // fresh. Either way the point picked on THIS screen is written after.
      resumeSession ? compose.chooseTier(tier) : compose.setTier(tier);
      compose.setPickupPoint(picked);
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
    required this.onPicked,
    this.picked,
    this.onChangeLocation,
  });

  final TierSelectionState state;
  final LocationPoint? picked;
  final ValueChanged<LocationPoint> onPicked;
  final VoidCallback? onChangeLocation;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case TierSelectionStatus.initial:
      case TierSelectionStatus.loading:
        return const _LoadingView();
      case TierSelectionStatus.error:
        return const _UnavailableView(status: JeebEmptyStateStatus.error);
      case TierSelectionStatus.loaded:
        if (state.tiers.isEmpty) {
          // A 200 with no tier configured for this city: nothing to pick, and
          // the same recovery as the error path.
          return const _UnavailableView(status: JeebEmptyStateStatus.empty);
        }
        return _LoadedView(
          state: state,
          picked: picked,
          onPicked: onPicked,
          onChangeLocation: onChangeLocation,
        );
    }
  }
}

/// The catalog read, held. Five glass row placeholders at the compact row's own
/// geometry rather than a spinner, so the page does not collapse then reflow.
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    final JeebSemanticColors semantics =
        Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    return Padding(
      padding: _bodyPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < 5; i++) ...<Widget>[
            _SkeletonRow(fill: semantics.glassFillEmphasis),
            if (i < 4) const SizedBox(height: Spacing.xSmall),
          ],
        ],
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({required this.fill});

  final Color fill;

  @override
  Widget build(BuildContext context) {
    return JeebOutlinedCard(
      padding: JeebTierRow.compactPadding,
      child: Row(
        children: <Widget>[
          _Bar(fill: fill, width: JeebTierRow.compactMarkSize, height: 20),
          const SizedBox(width: JeebTierRow.compactSpacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _Bar(fill: fill, width: 96, height: 12),
                const SizedBox(height: Spacing.xSmall),
                _Bar(fill: fill, width: 168, height: 10),
              ],
            ),
          ),
          const SizedBox(width: JeebTierRow.compactSpacing),
          _Bar(
            fill: fill,
            width: JeebTierRow.indicatorSize,
            height: JeebTierRow.indicatorSize,
            radius: JeebRadii.pill,
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.fill,
    required this.width,
    required this.height,
    this.radius = JeebRadii.sm,
  });

  final Color fill;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Error and empty share one recovery — retry — but not one read: an empty
/// catalog is a coverage gap, not a failed call.
class _UnavailableView extends StatelessWidget {
  const _UnavailableView({required this.status});

  final JeebEmptyStateStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEmpty = status == JeebEmptyStateStatus.empty;
    return Center(
      child: JeebEmptyState(
        status: status,
        headline: isEmpty
            ? l10n.requestTypeTiersEmptyHeadline
            : l10n.requestSummaryErrorNetwork,
        body: isEmpty ? l10n.requestTypeTiersEmptyBody : null,
        action: JeebCtaButton.outline(
          label: l10n.requestSummaryRetry,
          identifier: 'request_type_tiers_retry',
          onTap: () => context.read<TierSelectionCubit>().load(),
        ),
      ),
    );
  }
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({
    required this.state,
    required this.onPicked,
    this.picked,
    this.onChangeLocation,
  });

  final TierSelectionState state;
  final LocationPoint? picked;
  final ValueChanged<LocationPoint> onPicked;
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
                // R9 draws the uppercase periwinkle eyebrow here (11px), not
                // the pass-1 14/w700 navy heading.
                JeebSectionLabel(l10n.requestTypeLocationHeading, small: true),
                const SizedBox(height: Spacing.small),
                _LocationSection(
                  picked: picked,
                  onPicked: onPicked,
                  onChangeLocation: onChangeLocation,
                ),
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
  const _LocationSection({
    required this.onPicked,
    this.picked,
    this.onChangeLocation,
  });

  /// The point the picker handed back. Owned by the scaffold so the row updates
  /// IN PLACE and the Continue footer can carry the same point forward.
  final LocationPoint? picked;
  final ValueChanged<LocationPoint> onPicked;
  final VoidCallback? onChangeLocation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final point = picked;
    return RequestLocationRow(
      currentLabel: l10n.requestTypeCurrentLocation,
      addressLabel: point == null ? null : _pickedLabel(point),
      qualifierLabel: point == null ? null : l10n.captureLocationSelectedPoint,
      changeLabel: l10n.requestTypeChangeLocation,
      changeCtaLabel: l10n.requestTypeChangeCta,
      onChange: () => _onChange(context),
    );
  }

  /// The picker pops coordinates, not a resolved street line — show exactly
  /// what the capture sheet showed rather than invent an address.
  String _pickedLabel(LocationPoint point) =>
      point.address ??
      '${point.latitude.toStringAsFixed(4)}, '
          '${point.longitude.toStringAsFixed(4)}';

  Future<void> _onChange(BuildContext context) async {
    // Test/dev seam: when supplied it REPLACES the picker navigation.
    final handler = onChangeLocation;
    if (handler != null) {
      handler();
      return;
    }
    // EDGE: request-type-selection → location-map-pin (PICKER ONLY, was the
    // compose screen). It pops a LocationPoint (or null) and cannot submit.
    final result = await context.pushNamed<Object?>(
      'capture-location',
      queryParameters: const {'purpose': 'pickup'},
    );
    if (!context.mounted) return;
    // Anything that is neither a point nor null is a contract violation, not a
    // cancel — same handling as the location screen's pin edge.
    if (result != null && result is! LocationPoint) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).captureLocationPinFailed),
        ),
      );
      return;
    }
    final point = result as LocationPoint?;
    // A cancel leaves the row on its previous value, silently.
    if (point == null) return;
    onPicked(point);
  }
}

// The tier rows themselves live in `widgets/tier_catalog_section.dart`: copy
// resolution and the display lexicon sit with the section, not in this shell.
