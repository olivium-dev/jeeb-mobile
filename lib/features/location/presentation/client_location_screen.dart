import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../l10n/app_localizations.dart';
import '../application/location_select_cubit.dart';
import '../application/location_select_state.dart';
import '../data/dio_location_select_repository.dart';
import '../data/fake_location_select_repository.dart';
import '../domain/location_select_repository.dart';
import '../domain/saved_location.dart';
import 'widgets/client_location_add_row.dart';
import 'widgets/client_location_option_card.dart';
import 'widgets/delivery_create_layout.dart';

/// `location-select` (blueprint) — the customer picks the delivery location on
/// the create-flow's location leg (JM-024). The second step after
/// `request-type-selection`.
///
/// Renders (per 63_W1_TEST_PLAN §2.3): a "Current Location" option, the user's
/// **saved addresses** (loaded from `GET /users/:userId/saved-locations`, the
/// `location_select_saved_addresses_row` entry → `saved-addresses`/JM-049), a
/// `location_select_new_location_cta` → `location-map-pin`, and a sticky
/// `location_select_confirm_cta` → `order-chat` (JM-025).
///
/// The screen owns its forward navigation via GoRouter (40_GUARDRAILS_ARCH
/// §5.4/§10.8). The optional callbacks are test/dev seams that REPLACE the
/// default nav when provided. Self-provides [LocationSelectCubit] over
/// `sl<LocationSelectRepository>()` with a `repository` constructor override
/// for tests (40_GUARDRAILS_ARCH §5.4 — screen self-provides).
class ClientLocationScreen extends StatelessWidget {
  const ClientLocationScreen({
    super.key,
    this.repository,
    this.userId = _defaultUserId,
    this.onAddLocation,
    this.onConfirm,
    this.onOpenSavedAddresses,
    // Legacy seam (delivery-create dev host / existing tests): retained so the
    // current-location selection can still be driven externally. Null in the
    // live flow (the cubit owns selection).
    this.currentSelected,
    this.onSelectCurrent,
  });

  /// Mock convention: the `authStub` middleware resolves any bearer token to
  /// `user-client-001` and the W1 journey seeds target that id
  /// (42_GUARDRAILS_MOCK §4). Mirrors `chat_detail_screen.dart`.
  static const String _defaultUserId = 'user-client-001';

  final LocationSelectRepository? repository;
  final String userId;

  /// REPLACES the default `location-map-pin` navigation when provided.
  final VoidCallback? onAddLocation;

  /// REPLACES the default `order-chat` navigation when provided.
  final VoidCallback? onConfirm;

  /// REPLACES the default `saved-addresses` navigation when provided.
  final VoidCallback? onOpenSavedAddresses;

  /// Legacy external selection seam (optional). Ignored when null.
  final bool? currentSelected;
  final VoidCallback? onSelectCurrent;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LocationSelectCubit>(
      create: (_) => LocationSelectCubit(
        repository: repository ?? _resolveRepository(),
        userId: userId,
      )..load(),
      child: _Scaffold(
        onAddLocation: onAddLocation,
        onConfirm: onConfirm,
        onOpenSavedAddresses: onOpenSavedAddresses,
        legacyCurrentSelected: currentSelected,
        onSelectCurrent: onSelectCurrent,
      ),
    );
  }

  LocationSelectRepository _resolveRepository() {
    // Prefer a DI-registered interface when present (integrator may register it
    // in injection_container.dart; see 50_ROUTE_REQUESTS — JM-024 DI note),
    // else self-provide the Dio impl over the registered Dio, else degrade to
    // the in-memory seam (isolated host / no network).
    if (sl.isRegistered<LocationSelectRepository>()) {
      return sl<LocationSelectRepository>();
    }
    if (sl.isRegistered<Dio>()) {
      return DioLocationSelectRepository(sl<Dio>());
    }
    return const FakeLocationSelectRepository();
  }
}

class _Scaffold extends StatelessWidget {
  const _Scaffold({
    this.onAddLocation,
    this.onConfirm,
    this.onOpenSavedAddresses,
    this.legacyCurrentSelected,
    this.onSelectCurrent,
  });

  final VoidCallback? onAddLocation;
  final VoidCallback? onConfirm;
  final VoidCallback? onOpenSavedAddresses;
  final bool? legacyCurrentSelected;
  final VoidCallback? onSelectCurrent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: OMDSAppBar(
        title: l10n.clientLocationTitle,
        showBackButton: true,
        onBackPressed: () => Navigator.of(context).maybePop(),
      ),
      body: SafeArea(
        child: BlocBuilder<LocationSelectCubit, LocationSelectState>(
          builder: (context, state) => _Body(
            state: state,
            onAddLocation: onAddLocation,
            onOpenSavedAddresses: onOpenSavedAddresses,
            legacyCurrentSelected: legacyCurrentSelected,
            onSelectCurrent: onSelectCurrent,
          ),
        ),
      ),
      bottomNavigationBar: BlocBuilder<LocationSelectCubit, LocationSelectState>(
        builder: (context, state) =>
            _ConfirmFooter(state: state, onConfirm: onConfirm),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    this.onAddLocation,
    this.onOpenSavedAddresses,
    this.legacyCurrentSelected,
    this.onSelectCurrent,
  });

  final LocationSelectState state;
  final VoidCallback? onAddLocation;
  final VoidCallback? onOpenSavedAddresses;
  final bool? legacyCurrentSelected;
  final VoidCallback? onSelectCurrent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Cold-load only blocks on the saved-address fetch; the failed state still
    // shows a retry but never hides the create flow (the customer can still pin
    // a new point), so we render the affordances even on failure.
    if (state.status == LocationSelectStatus.initial ||
        state.status == LocationSelectStatus.loading) {
      return const Center(child: OmdsLoadingState());
    }
    final currentSelected = legacyCurrentSelected ??
        (state.choiceKind == LocationChoiceKind.current ||
            state.choiceKind == LocationChoiceKind.pinned);
    return ListView(
      padding: DeliveryCreateLayout.pagePadding,
      children: [
        _Heading(text: l10n.clientLocationHeading),
        const SizedBox(height: Spacing.large),
        ClientLocationOptionCard(
          label: l10n.clientLocationCurrentOption,
          selected: currentSelected,
          onTap: () => _onSelectCurrent(context),
        ),
        // The saved-addresses ENTRY row is an unconditional affordance
        // (63_W1_TEST_PLAN §2.3 — `location_select_saved_addresses_row` →
        // saved-addresses, JM-049). It must NOT be gated on `hasSavedAddresses`:
        // jm-024 taps the row with no `has_saved_addresses` seed, and the
        // manager owns its own empty state. Only the selectable saved-address
        // CARDS below remain conditional on a non-empty list.
        const SizedBox(height: Spacing.large),
        _SavedAddressesRow(onTap: () => _onOpenSaved(context)),
        if (state.hasSavedAddresses) ...[
          const SizedBox(height: Spacing.medium),
          for (final address in state.savedAddresses) ...[
            _SavedAddressCard(
              address: address,
              selected: state.isSavedSelected(address.id),
              onTap: () =>
                  context.read<LocationSelectCubit>().selectSaved(address.id),
            ),
            const SizedBox(height: Spacing.small),
          ],
        ],
        const SizedBox(height: Spacing.large),
        if (state.status == LocationSelectStatus.failed)
          _SavedAddressesError(
            onRetry: () => context.read<LocationSelectCubit>().refresh(),
          ),
        ClientLocationAddRow(
          identifier: 'location_select_new_location_cta',
          label: l10n.clientLocationNewOption,
          addSemanticLabel: l10n.clientLocationAddSemantic,
          onTap: () => _onAdd(context),
        ),
      ],
    );
  }

  void _onSelectCurrent(BuildContext context) {
    context.read<LocationSelectCubit>().selectCurrent();
    onSelectCurrent?.call();
  }

  Future<void> _onAdd(BuildContext context) async {
    // EDGE: location-select → location-map-pin (21_NAV_PLAN.md §C, JM-024 AC3).
    // The optional callback REPLACES the default nav for tests / the dev seam.
    final handler = onAddLocation;
    if (handler != null) {
      handler();
      return;
    }
    final cubit = context.read<LocationSelectCubit>();
    // capture-location pops back here; treat the return as a freshly-pinned
    // point so the Confirm CTA forwards it (JM-024 AC3 "pin confirms back").
    await context.pushNamed('capture-location');
    cubit.markPinned();
  }

  void _onOpenSaved(BuildContext context) {
    // EDGE: location-select → saved-addresses (Q3, JM-049; 21_NAV_PLAN.md §C).
    final handler = onOpenSavedAddresses;
    if (handler != null) {
      handler();
      return;
    }
    // `settings-addresses` is registered (the existing SavedLocationsScreen /
    // JM-049 manager). The customer can pick / manage saved addresses there.
    context.pushNamed('settings-addresses');
  }
}

/// The "Saved addresses" entry row (JM-024 AC2). Its tap routes to the
/// saved-addresses manager; the seeded saved-address cards render below it.
class _SavedAddressesRow extends StatelessWidget {
  const _SavedAddressesRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'location_select_saved_addresses_row',
      button: true,
      label: l10n.savedAddressesTitle,
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: OmdsBorderRadius.uiMedium,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: Spacing.xSmall,
            ),
            child: Row(
              children: [
                Icon(Icons.bookmark_outline,
                    size: Sizes.large, color: scheme.primary),
                const SizedBox(width: Spacing.small),
                Expanded(
                  child: Text(
                    l10n.savedAddressesTitle,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.chevron_right,
                    size: Sizes.large, color: scheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A selectable saved-address card. Mirrors [ClientLocationOptionCard] styling
/// (navy fill when selected) so the saved addresses sit in the same mutually-
/// exclusive group as "Current Location".
class _SavedAddressCard extends StatelessWidget {
  const _SavedAddressCard({
    required this.address,
    required this.selected,
    required this.onTap,
  });

  final SavedLocation address;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected ? scheme.onPrimary : scheme.primary;
    final subtitle = address.address;
    return Semantics(
      identifier: 'location_select_saved_address_${address.id}',
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: subtitle == null ? address.label : '${address.label}, $subtitle',
      child: ExcludeSemantics(
        child: Material(
          color: selected ? scheme.primary : scheme.surface,
          borderRadius: OmdsBorderRadius.uiLarge,
          child: InkWell(
            borderRadius: OmdsBorderRadius.uiLarge,
            onTap: onTap,
            child: Container(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: Spacing.medium,
                vertical: Spacing.medium,
              ),
              decoration: BoxDecoration(
                borderRadius: OmdsBorderRadius.uiLarge,
                border: Border.all(
                  color: selected ? scheme.primary : scheme.outlineVariant,
                ),
              ),
              child: Row(
                children: [
                  Icon(_iconFor(address.category),
                      size: Sizes.large, color: foreground),
                  const SizedBox(width: Spacing.small),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          address.label,
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: foreground,
                                    fontWeight: FontWeight.w700,
                                  ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: selected
                                          ? scheme.onPrimary
                                          : scheme.onSecondaryContainer,
                                    ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(SavedLocationCategory cat) => switch (cat) {
        SavedLocationCategory.home => Icons.home_outlined,
        SavedLocationCategory.work => Icons.work_outline,
        SavedLocationCategory.other => Icons.place_outlined,
      };
}

class _SavedAddressesError extends StatelessWidget {
  const _SavedAddressesError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: Spacing.medium),
      child: Semantics(
        identifier: 'location_select_saved_addresses_error',
        child: OmdsErrorState(
          message: l10n.savedLocationsError,
          onRetry: onRetry,
          retryLabel: l10n.earningsLoadRetry,
        ),
      ),
    );
  }
}

/// Sticky "Confirm location" footer → order-chat (JM-024 AC4).
class _ConfirmFooter extends StatelessWidget {
  const _ConfirmFooter({required this.state, this.onConfirm});

  final LocationSelectState state;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    if (state.status == LocationSelectStatus.initial ||
        state.status == LocationSelectStatus.loading) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: DeliveryCreateLayout.pagePadding,
        child: Semantics(
          identifier: 'location_select_confirm_cta',
          button: true,
          child: OmdsPrimaryButton(
            // l10n: reuses `locationConfirm` ("Confirm location"); a dedicated
            // `locationSelectConfirmCta` key is requested in 50_ROUTE_REQUESTS.
            text: l10n.locationConfirm,
            isEnabled: state.canConfirm,
            onTap: () => _onConfirm(context),
          ),
        ),
      ),
    );
  }

  void _onConfirm(BuildContext context) {
    // EDGE: location-select → order-chat compose (21_NAV_PLAN.md §C, JM-024
    // AC4 → JM-025). The optional callback REPLACES the default nav for tests /
    // the dev seam.
    final override = onConfirm;
    if (override != null) {
      override();
      return;
    }
    // Hand off to order-chat in COMPOSE state. JM-025 owns the compose=broadcast
    // behavior keyed on the `new` sentinel id (see 50_ROUTE_REQUESTS — JM-024
    // → JM-025 hand-off). The chat route resolves `new` to an empty thread that
    // renders the composer (`order_chat_composer_send`).
    context.pushNamed('chat-detail', pathParameters: {'id': 'new'});
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.text});

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
