import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show ValueListenable, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/network/auth_token_store.dart';
import '../../../l10n/app_localizations.dart';
import '../../registration/domain/lebanon_phone.dart';
import '../../request_summary/application/compose_request_controller.dart';
import '../../request_summary/domain/request_submission_service.dart';
import '../../settings/data/shared_prefs_profile_repository.dart';
import '../../transcription/domain/voice_clip.dart';
import '../application/location_select_cubit.dart';
import '../application/location_select_state.dart';
import '../data/dio_location_select_repository.dart';
import '../data/location_repository.dart' show LocationPoint;
import '../data/fake_location_select_repository.dart';
import '../domain/location_select_repository.dart';
import '../domain/saved_location.dart';
import 'widgets/client_location_add_row.dart';
import 'widgets/client_location_option_card.dart';
import 'widgets/delivery_create_layout.dart';

/// B-02b: the create-success navigation fires only when the footer is BOTH
/// still [mounted] AND its route is still the current/top route
/// ([isRouteCurrent]). Extracted as a pure predicate so the route-currentness
/// RULE is directly unit-testable and mutation-catchable: dropping the
/// `isRouteCurrent` term flips the mounted-but-not-current case (an overlay /
/// dialog / bottom-sheet sitting on top of the still-mounted location step),
/// which would otherwise let a completed create `goNamed` the waiting surface
/// out from under it. (In go_router a *page* push disposes the covered footer,
/// so `mounted` alone already catches those; `isRouteCurrent` covers the
/// mounted-but-covered overlay case `mounted` cannot.)
@visibleForTesting
bool shouldRouteAfterCreate({
  required bool mounted,
  required bool isRouteCurrent,
}) =>
    mounted && isRouteCurrent;

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
    this.userId,
    this.onAddLocation,
    this.onConfirm,
    this.onOpenSavedAddresses,
    this.onDictate,
    // Legacy seam (delivery-create dev host / existing tests): retained so the
    // current-location selection can still be driven externally. Null in the
    // live flow (the cubit owns selection).
    this.currentSelected,
    this.onSelectCurrent,
  });

  final LocationSelectRepository? repository;

  /// Owning user id. When null (the live router mount), it is resolved from
  /// the authenticated session ([AuthTokenStore]) at build time — no mock
  /// fallback. Injectable for tests / dev seams.
  final String? userId;

  /// REPLACES the default `location-map-pin` navigation when provided.
  final VoidCallback? onAddLocation;

  /// REPLACES the default `order-chat` navigation when provided.
  final VoidCallback? onConfirm;

  /// REPLACES the default `saved-addresses` navigation when provided.
  final VoidCallback? onOpenSavedAddresses;

  /// G1 dictation seam. REPLACES the default `compose-dictation` navigation
  /// (mic button on the "What do you need?" field) when provided — tests hand
  /// back a canned [VoiceClip] without a router.
  final Future<VoiceClip?> Function()? onDictate;

  /// Legacy external selection seam (optional). Ignored when null.
  final bool? currentSelected;
  final VoidCallback? onSelectCurrent;

  @override
  Widget build(BuildContext context) {
    final scaffold = _Scaffold(
      onAddLocation: onAddLocation,
      onConfirm: onConfirm,
      onOpenSavedAddresses: onOpenSavedAddresses,
      onDictate: onDictate,
      legacyCurrentSelected: currentSelected,
      onSelectCurrent: onSelectCurrent,
    );
    // DEFECT A: never default to the mock `user-client-001`. When the caller
    // did not inject an explicit [userId] (the live router mount), resolve the
    // authenticated id from [AuthTokenStore] before building the cubit. The
    // saved-locations read is `me`-scoped (identity from the bearer token), so
    // this id is for logging/selection coherence — but it must be the REAL
    // user, never a hardcoded mock.
    final injected = userId;
    if (injected != null) {
      return BlocProvider<LocationSelectCubit>(
        create: (_) => LocationSelectCubit(
          repository: repository ?? _resolveRepository(),
          userId: injected,
        )..load(),
        child: scaffold,
      );
    }
    return FutureBuilder<String?>(
      future: _authTokenStore().userId,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: OmdsLoadingState()));
        }
        // Empty string when the session has no stored id; the `me` route still
        // resolves identity from the bearer token, so the list loads correctly.
        final resolvedId = snapshot.data ?? '';
        return BlocProvider<LocationSelectCubit>(
          create: (_) => LocationSelectCubit(
            repository: repository ?? _resolveRepository(),
            userId: resolvedId,
          )..load(),
          child: scaffold,
        );
      },
    );
  }

  /// Resolves [AuthTokenStore] from DI when registered (so tests can mock it),
  /// else news one — the same pattern the logout sheet uses. NEVER a mock id.
  AuthTokenStore _authTokenStore() => sl.isRegistered<AuthTokenStore>()
      ? sl<AuthTokenStore>()
      : AuthTokenStore();

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

class _Scaffold extends StatefulWidget {
  const _Scaffold({
    this.onAddLocation,
    this.onConfirm,
    this.onOpenSavedAddresses,
    this.onDictate,
    this.legacyCurrentSelected,
    this.onSelectCurrent,
  });

  final VoidCallback? onAddLocation;
  final VoidCallback? onConfirm;
  final VoidCallback? onOpenSavedAddresses;
  final Future<VoiceClip?> Function()? onDictate;
  final bool? legacyCurrentSelected;
  final VoidCallback? onSelectCurrent;

  @override
  State<_Scaffold> createState() => _ScaffoldState();
}

class _ScaffoldState extends State<_Scaffold> {
  /// Shared "What do you need?" text (G1). Owned here — above BOTH the body
  /// (the field writes it) and the footer (the Confirm gate listens to it) —
  /// because [TextEditingController] is a [ValueListenable] the footer can
  /// rebuild on without a dedicated cubit.
  final TextEditingController _description = TextEditingController();

  /// B-02b: create-in-flight flag, OWNED here (above BOTH the body and the
  /// footer) so it can disable the body's navigation rows while the footer's
  /// `POST /requests` is outstanding. Previously the flag lived inside the
  /// footer, so only the Confirm CTA was disabled — the add-location and
  /// saved-addresses rows stayed tappable and a mid-flight push let the success
  /// nav fire from underneath the newly-pushed route.
  final ValueNotifier<bool> _submitting = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    // Re-seed from the shared compose controller so backing out to the tier
    // step and returning does not lose the typed text (the controller resets
    // it only when a NEW compose session starts via setTier).
    if (sl.isRegistered<ComposeRequestController>()) {
      final existing = sl<ComposeRequestController>().description;
      if (existing != null) _description.text = existing;
    }
  }

  @override
  void dispose() {
    _submitting.dispose();
    _description.dispose();
    super.dispose();
  }

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
            descriptionController: _description,
            submitting: _submitting,
            onAddLocation: widget.onAddLocation,
            onOpenSavedAddresses: widget.onOpenSavedAddresses,
            onDictate: widget.onDictate,
            legacyCurrentSelected: widget.legacyCurrentSelected,
            onSelectCurrent: widget.onSelectCurrent,
          ),
        ),
      ),
      bottomNavigationBar: BlocBuilder<LocationSelectCubit, LocationSelectState>(
        builder: (context, state) => _ConfirmFooter(
          state: state,
          description: _description,
          submitting: _submitting,
          onConfirm: widget.onConfirm,
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    required this.descriptionController,
    required this.submitting,
    this.onAddLocation,
    this.onOpenSavedAddresses,
    this.onDictate,
    this.legacyCurrentSelected,
    this.onSelectCurrent,
  });

  final LocationSelectState state;
  final TextEditingController descriptionController;

  /// B-02b: true while the footer's `POST /requests` is in flight. The
  /// navigation rows below (saved-addresses, add-location) are locked out for
  /// its duration so the user cannot push a new route mid-create.
  final ValueListenable<bool> submitting;
  final VoidCallback? onAddLocation;
  final VoidCallback? onOpenSavedAddresses;
  final Future<VoiceClip?> Function()? onDictate;
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
        // G1 (sprint-009 P0) — "What do you need?" leads the confirm step: the
        // request CONTENT is the thing the jeeber prices, so it sits above the
        // location options on the same screen that submits POST /requests (all
        // compose paths converge here, so the required-gate cannot be
        // bypassed via the request-type "Change location" shortcut).
        _DescriptionSection(
          controller: descriptionController,
          onDictate: onDictate,
        ),
        const SizedBox(height: Spacing.xLarge),
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
        // B-02b: lock the saved-addresses row while a create is in flight so a
        // mid-POST push cannot leave the (still-mounted) footer to navigate the
        // waiting surface from underneath the newly-pushed route.
        _SubmitLock(
          submitting: submitting,
          child: _SavedAddressesRow(onTap: () => _onOpenSaved(context)),
        ),
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
        // B-02b: same in-flight lock as the saved-addresses row above.
        _SubmitLock(
          submitting: submitting,
          child: ClientLocationAddRow(
            identifier: 'location_select_new_location_cta',
            label: l10n.clientLocationNewOption,
            addSemanticLabel: l10n.clientLocationAddSemantic,
            onTap: () => _onAdd(context),
          ),
        ),
        const SizedBox(height: Spacing.xLarge),
        // iter6 OTP-phone v2: recipient-phone capture. The gateway needs a
        // non-null `recipientPhone` on the request so the at-door handover OTP
        // (`POST /deliveries/{id}/otp/verify {code:"1234"}`) can be issued/
        // verified — without it the verify returns 400 recipient-phone-missing.
        // The field is pre-filled from the locally-stored profile phone when
        // present and writes its E.164 value into the shared
        // ComposeRequestController, which threads it into the POST /requests
        // body. It is the correct delivery UX (who receives + their phone).
        const _RecipientPhoneField(),
      ],
    );
  }

  void _onSelectCurrent(BuildContext context) {
    context.read<LocationSelectCubit>().selectCurrent();
    onSelectCurrent?.call();
  }

  Future<void> _onAdd(BuildContext context) async {
    // B-02b: never push while a create is in flight (belt-and-braces behind the
    // `_SubmitLock` IgnorePointer above).
    if (submitting.value) return;
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
    // S0-REQ-03: the capture route pops the pinned `LocationPoint` via `extra`
    // ("Pin Location" → `context.pop(controller.center)`). Capture that
    // coordinate and thread it into `markPinned` so the REAL pin reaches the
    // create draft — it used to be discarded here, collapsing every pinned
    // pickup to the Beirut fallback.
    final result = await context.pushNamed<Object?>('capture-location');
    final point = result is LocationPoint ? result : null;
    cubit.markPinned(
      latitude: point?.latitude,
      longitude: point?.longitude,
    );
  }

  void _onOpenSaved(BuildContext context) {
    // B-02b: never push while a create is in flight (see [_onAdd]).
    if (submitting.value) return;
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

/// B-02b: locks its [child] out of interaction while a create is in flight.
///
/// Wraps the location-select navigation rows so that, once the Confirm CTA's
/// `POST /requests` is outstanding, the user cannot push `capture-location` or
/// `saved-addresses` on top of this (still-mounted) screen — which is exactly
/// the state that let the success `goNamed` fire from underneath a newly-pushed
/// route. The row dims to [UIConstants.opacityDisabled] to signal the lock.
class _SubmitLock extends StatelessWidget {
  const _SubmitLock({required this.submitting, required this.child});

  final ValueListenable<bool> submitting;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: submitting,
      builder: (context, busy, child) => IgnorePointer(
        ignoring: busy,
        child: busy
            ? Opacity(opacity: UIConstants.opacityDisabled, child: child)
            : child!,
      ),
      child: child,
    );
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
                                      // UX-AUDIT §T3: the unselected row sits on
                                      // the white `surface`, so the subtitle must
                                      // use `onSurfaceVariant` (AA 9.35:1), NOT
                                      // periwinkle `onSecondaryContainer` (the
                                      // ~2.2:1 light-purple-on-white the owner
                                      // reported). Selected row is navy, keeps
                                      // `onPrimary`.
                                      color: selected
                                          ? scheme.onPrimary
                                          : scheme.onSurfaceVariant,
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
///
/// G1: additionally gated on a non-empty trimmed "What do you need?" entry —
/// the request content is required, so the create CTA stays disabled until the
/// customer says what they actually want (typed or dictated).
class _ConfirmFooter extends StatefulWidget {
  const _ConfirmFooter({
    required this.state,
    required this.description,
    required this.submitting,
    this.onConfirm,
  });

  final LocationSelectState state;
  final TextEditingController description;

  /// B-02b: shared create-in-flight flag (owned by [_ScaffoldState]). Drives
  /// the CTA spinner + disabled state here AND locks the body's nav rows.
  final ValueNotifier<bool> submitting;
  final VoidCallback? onConfirm;

  @override
  State<_ConfirmFooter> createState() => _ConfirmFooterState();
}

class _ConfirmFooterState extends State<_ConfirmFooter> {
  // B-02 double-submit guard: this is the only `POST /requests` submit surface
  // in the codebase; without an in-flight guard a double-tap (or a tap while
  // the create call is in flight) fired the create twice. Mirrors the
  // goods_cost_cubit `inFlight` re-entrancy guard. `widget.submitting` disables
  // the CTA + drives the OmdsLoadingButton spinner while the POST is
  // outstanding — B-02b lifted it to [_ScaffoldState] so the body's nav rows
  // are locked out for the same window.

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
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
          child: ValueListenableBuilder<bool>(
            valueListenable: widget.submitting,
            builder: (context, submitting, _) =>
                ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.description,
              builder: (context, value, _) => OmdsLoadingButton(
                // l10n: reuses `locationConfirm` ("Confirm location"); a
                // dedicated `locationSelectConfirmCta` key is requested in
                // 50_ROUTE_REQUESTS.
                text: l10n.locationConfirm,
                isLoading: submitting,
                isEnabled: state.canConfirm && value.text.trim().isNotEmpty,
                borderRadius: OmdsBorderRadius.pill,
                onTap: () => _onConfirm(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onConfirm(BuildContext context) async {
    // B-02: ignore the tap if a create is already in flight (double-submit).
    if (widget.submitting.value) return;
    // EDGE: location-select → order-chat compose (21_NAV_PLAN.md §C, JM-024
    // AC4 → JM-025). The optional callback REPLACES the default nav for tests /
    // the dev seam.
    final override = widget.onConfirm;
    if (override != null) {
      override();
      return;
    }

    // iter6 B11 — THE create gating fix. The old flow handed off the literal
    // placeholder id `'new'` to order-chat, which then broadcast
    // `requestId='new'` WITHOUT ever calling POST /requests → no request was
    // created on-device (matching 422 / chat 404). Now we CREATE the request
    // here first (POST /requests → 201 {id}) and route order-chat with the REAL
    // server-minted id so broadcast/chat operate on a request that exists.
    //
    // If the compose controller is not registered (isolated host / a test
    // without DI), fall back to the prior `'new'` hand-off so non-app-rooted
    // hosts degrade exactly as before rather than throw.
    if (!sl.isRegistered<ComposeRequestController>()) {
      context.pushNamed('chat-detail', pathParameters: {'id': 'new'});
      return;
    }

    final controller = sl<ComposeRequestController>();
    // G1 belt-and-braces: commit the CURRENT field text at the submit moment so
    // the POST body always carries exactly what the customer sees in the field
    // (the field also commits on every change; this guards any missed edit).
    controller.setDescription(widget.description.text);
    await _createAndRoute(context, controller);
  }

  Future<void> _createAndRoute(
    BuildContext context,
    ComposeRequestController controller,
  ) async {
    // Capture the navigation + messenger handles BEFORE the async gap: this
    // footer may be rebuilt (and unmounted) by the time the create returns, so
    // drive navigation off the GoRouter / messenger instances, not a stale
    // BuildContext.
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = AppLocalizations.of(context);
    // B-02b: snapshot THIS route before the async gap. `mounted` alone is not
    // enough — a push (capture-location / saved-addresses / dictation) leaves
    // this footer mounted but no longer the top route, so a `mounted`-only gate
    // would still `goNamed` the waiting surface out from under the pushed route.
    final route = ModalRoute.of(context);
    widget.submitting.value = true;
    try {
      final requestId = await controller.submitFromLocation(widget.state);
      // B-02b: only navigate when this footer is still mounted AND its route is
      // still the current/top route (see [shouldRouteAfterCreate]). If the user
      // left the create step mid-POST (backed out → unmounted, or an overlay is
      // covering it → not current), yanking them to the waiting surface would be
      // a rogue navigation, so we land the created request silently and stay put.
      if (!shouldRouteAfterCreate(
        mounted: mounted,
        isRouteCurrent: route?.isCurrent ?? false,
      )) {
        return;
      }
      // logcat proof anchor: confirms the create call succeeded with a REAL id
      // (NOT 'new') before we route to the waiting surface.
      debugPrint('[compose-b11] POST /requests OK → requestId=$requestId');
      // POST-CREATE UX FIX: land the customer on the "Finding a Jeeber" WAITING
      // surface for the freshly-created request — NOT the order-chat compose
      // screen (the request already exists, so there is nothing to compose).
      // Reuse the existing `waiting-no-coverage` route (the SAME target the
      // chat-first broadcast used) threading the REAL server-minted requestId.
      // `goNamed` (not push) so the now-created request cannot be re-submitted
      // by backing into this screen.
      router.goNamed('waiting-no-coverage', pathParameters: {'id': requestId});
    } on RequestSubmissionException catch (e) {
      debugPrint('[compose-b11] POST /requests FAILED: $e');
      // Stay on the location step and surface a retryable error — never hand
      // off `'new'` (that is exactly the broken path B11 removes).
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.requestSummaryErrorNetwork)),
      );
    } finally {
      // Re-enable so the customer can retry after a failure. On a successful nav
      // this footer is unmounted → the mounted guard makes this a no-op, leaving
      // the CTA disabled through the transition. (When the nav was suppressed
      // because the route was no longer current, re-enabling is correct — the
      // footer is still on screen underneath the pushed route.)
      if (mounted) widget.submitting.value = false;
    }
  }
}

/// G1 (sprint-009 P0) — the "What do you need?" compose block.
///
/// WHY: the live compose flow used to send a HARDCODED
/// '"{Tier} delivery request"' as the request description — the jeeber feed
/// card and detail then showed no actual content and jeebers priced blind
/// ("the user is not sending in the initial request what he wants"). This
/// block captures the customer's own words as the request description; the
/// Confirm CTA is gated on a non-empty trimmed entry.
///
/// Voice: the mic suffix reuses the EXISTING voice-transcription flow
/// (`compose-dictation` → VoiceRecordingScreen → TranscriptionScreen). The
/// confirmed transcript flows back INTO this field (editable), and the
/// transcript + audio reference ride along on the POST body as
/// `transcription`/`audioUrl`.
class _DescriptionSection extends StatefulWidget {
  const _DescriptionSection({required this.controller, this.onDictate});

  final TextEditingController controller;

  /// Test seam — REPLACES the default `compose-dictation` navigation.
  final Future<VoiceClip?> Function()? onDictate;

  @override
  State<_DescriptionSection> createState() => _DescriptionSectionState();
}

class _DescriptionSectionState extends State<_DescriptionSection> {
  /// The gateway create contract has no hard length cap; 280 keeps the feed
  /// card/detail readable and matches the G1 fix spec's suggested ceiling.
  static const int _maxLength = 280;

  bool _touched = false;

  void _commit(String raw) {
    _touched = true;
    if (sl.isRegistered<ComposeRequestController>()) {
      final compose = sl<ComposeRequestController>();
      compose.setDescription(raw);
      // Manual edits invalidate a previously-attached dictation transcript
      // only when the text no longer matches it; keep it simple and re-sync:
      // the transcript stays attached only while the field still contains it.
      if (compose.description == null) {
        compose.setVoiceNote(transcription: null, audioUrl: null);
      }
    }
    setState(() {});
  }

  Future<void> _dictate(BuildContext context) async {
    // EDGE: location-select → compose-dictation (G1). Reuses the voice
    // recording + transcription-review screens; the confirmed text pops back
    // as a [VoiceClip] result. The seam REPLACES the navigation in tests.
    final handler = widget.onDictate ??
        () => GoRouter.of(context).pushNamed<VoiceClip>('compose-dictation');
    final clip = await handler();
    if (!mounted || clip == null) return;
    final text = clip.transcript?.trim() ?? '';
    if (text.isEmpty) return;
    final existing = widget.controller.text.trim();
    // Append dictation to existing text (the customer may mix type + voice);
    // replace when the field is empty.
    widget.controller.text = existing.isEmpty ? text : '$existing\n$text';
    if (sl.isRegistered<ComposeRequestController>()) {
      sl<ComposeRequestController>()
        ..setDescription(widget.controller.text)
        ..setVoiceNote(
          transcription: text,
          audioUrl: clip.audioPath.isEmpty ? null : clip.audioPath,
        );
    }
    setState(() => _touched = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final showError = _touched && widget.controller.text.trim().isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Heading(text: l10n.composeDescriptionHeading),
        const SizedBox(height: Spacing.small),
        Semantics(
          identifier: 'compose_description_input',
          textField: true,
          label: l10n.composeDescriptionHeading,
          child: OmdsTextField(
            key: const Key('clientLocation.descriptionField'),
            controller: widget.controller,
            hintText: l10n.composeDescriptionHint,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            minLines: 3,
            maxLines: 6,
            maxLength: _maxLength,
            errorText: showError ? l10n.composeDescriptionRequired : null,
            onChanged: _commit,
            suffixIcon: Semantics(
              identifier: 'compose_description_mic',
              button: true,
              label: l10n.composeDescriptionMicSemantic,
              child: IconButton(
                key: const Key('clientLocation.descriptionMic'),
                icon: Icon(Icons.mic_none_outlined,
                    color: theme.colorScheme.primary),
                tooltip: l10n.composeDescriptionMicSemantic,
                onPressed: () => _dictate(context),
              ),
            ),
          ),
        ),
        const SizedBox(height: Spacing.xSmall),
        Text(
          l10n.composeDescriptionHelper,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// iter6 OTP-phone v2 — recipient-phone capture on the location-confirm step.
///
/// WHY: the at-door handover OTP issue/verify reads `recipientPhone` from the
/// gateway request-store row. The compose flow had no way to attach one (the
/// only #67 default — `GET /v1/users/me.phone` — does not exist in the live
/// gateway contract), so the on-device create produced a phone-less request and
/// the in-app code-`1234` verify returned 400 `recipient-phone-missing`. This
/// field is the reliable source: the customer enters (or confirms the
/// pre-filled) recipient phone, validated as a Lebanese E.164 number, and the
/// value is written into the shared [ComposeRequestController] so it lands in
/// the `POST /requests` body.
///
/// Pre-fill: when a local registration/profile phone exists
/// ([SharedPrefsProfileRepository] `phoneE164`) it is loaded as the default, so
/// a real phone-OTP user does not have to re-type their number (the requester
/// is the default recipient). The +961 prefix is pinned; the field carries the
/// 8 national digits, mirroring the registration phone entry.
class _RecipientPhoneField extends StatefulWidget {
  const _RecipientPhoneField();

  @override
  State<_RecipientPhoneField> createState() => _RecipientPhoneFieldState();
}

class _RecipientPhoneFieldState extends State<_RecipientPhoneField> {
  final TextEditingController _controller = TextEditingController();
  String? _errorText;
  bool _touched = false;

  @override
  void initState() {
    super.initState();
    _prefillFromProfile();
  }

  /// Best-effort: load the locally-persisted profile phone and seed the field +
  /// the controller with it, so the create already carries a valid phone even
  /// if the user just taps Confirm without editing. Never throws.
  Future<void> _prefillFromProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profile =
          await SharedPrefsProfileRepository(prefs: prefs).load();
      final phone = LebanonPhone.tryParse(profile?.phoneE164 ?? '');
      if (phone == null || !mounted) return;
      // Only seed if the user has not started typing.
      if (_controller.text.trim().isEmpty) {
        _controller.text = phone.digits;
        _commit(phone.digits);
      }
    } catch (_) {
      // No local phone is fine — the field stays empty and the resolver default
      // (or a manual entry) supplies the phone.
    }
  }

  /// Normalises [raw] to the national digits, validates, writes the E.164 value
  /// (or null) into the shared compose controller, and surfaces an inline error
  /// once the field has been touched.
  void _commit(String raw) {
    final phone = LebanonPhone.tryParse(raw);
    if (sl.isRegistered<ComposeRequestController>()) {
      sl<ComposeRequestController>().setRecipientPhone(phone?.e164);
    }
    final l10n = AppLocalizations.of(context);
    setState(() {
      _errorText = (_touched && raw.trim().isNotEmpty && phone == null)
          ? l10n.recipientPhoneInvalid
          : null;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.recipientPhoneLabel,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: Spacing.small),
        Semantics(
          identifier: 'recipient_phone_input',
          textField: true,
          label: l10n.recipientPhoneLabel,
          child: TextField(
            key: const Key('clientLocation.recipientPhoneField'),
            controller: _controller,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d+\s\-()]')),
            ],
            style: theme.textTheme.bodyLarge,
            onChanged: (v) {
              _touched = true;
              _commit(v);
            },
            decoration: InputDecoration(
              hintText: l10n.recipientPhoneHint,
              errorText: _errorText,
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest,
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.medium,
                  vertical: Spacing.small,
                ),
                child: Text(
                  LebanonPhone.dialCode,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0),
              border: const OutlineInputBorder(
                borderRadius: OmdsBorderRadius.medium,
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: Spacing.xSmall),
        Text(
          l10n.recipientPhoneHelper,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
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
