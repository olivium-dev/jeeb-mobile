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
import '../../../core/theme/jeeb_color_roles.dart';
import '../../../core/theme/jeeb_shadows.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/directional_icons.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../registration/domain/lebanon_phone.dart';
import '../../request_summary/application/compose_request_controller.dart';
import '../../request_summary/domain/request_submission_service.dart';
import '../../settings/data/shared_prefs_profile_repository.dart';
import '../../transcription/domain/voice_clip.dart';
import '../application/location_select_cubit.dart';
import '../application/location_select_state.dart';
import '../data/dio_location_select_repository.dart';
import '../data/geolocator_current_location_resolver.dart';
import '../data/location_repository.dart' show LocationPoint;
import '../data/fake_location_select_repository.dart';
import '../domain/current_location_resolver.dart';
import '../domain/location_select_repository.dart';
import 'widgets/client_location_add_row.dart';
import 'widgets/current_location_status_card.dart';
import 'widgets/delivery_create_layout.dart';
import 'widgets/saved_address_pill_row.dart';

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
    this.currentLocationResolver,
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

  /// Device-GPS resolver for the "Current Location" option (JEBV4-176). When
  /// null (the live mount) it is resolved from DI, else a real geolocator-backed
  /// resolver is constructed. Injectable so tests script the GPS outcome (and
  /// the recovery states) without a platform channel.
  final CurrentLocationResolver? currentLocationResolver;

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

  // Delegates to a stateful host so the authenticated-user-id future and the
  // resolved repo/GPS-resolver are computed EXACTLY ONCE. Previously the build
  // method called `_authTokenStore().userId` inline, minting a NEW future on
  // every rebuild — the FutureBuilder then thrashed (waiting→done→waiting…),
  // rebuilding a fresh cubit each time and dropping the async GPS-resolution
  // emit before the UI could render it (JEBV4-176). Memoizing fixes that.
  @override
  Widget build(BuildContext context) => _LocationSelectHost(config: this);

  /// Resolves the current-location GPS resolver: the injected test seam first,
  /// then a DI-registered one, else a real geolocator-backed resolver so the
  /// live app always attempts a REAL device fix (JEBV4-176 — never Beirut).
  CurrentLocationResolver _resolveGpsResolver() {
    final injected = currentLocationResolver;
    if (injected != null) return injected;
    if (sl.isRegistered<CurrentLocationResolver>()) {
      return sl<CurrentLocationResolver>();
    }
    return GeolocatorCurrentLocationResolver();
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

/// Stable host for [ClientLocationScreen]: resolves the user-id future, the
/// saved-locations repository, and the GPS resolver ONCE in [initState] so the
/// [BlocProvider]/[LocationSelectCubit] (and its async GPS resolution) are not
/// churned by rebuilds (JEBV4-176).
class _LocationSelectHost extends StatefulWidget {
  const _LocationSelectHost({required this.config});

  final ClientLocationScreen config;

  @override
  State<_LocationSelectHost> createState() => _LocationSelectHostState();
}

class _LocationSelectHostState extends State<_LocationSelectHost> {
  late final LocationSelectRepository _repository;
  late final CurrentLocationResolver _resolver;
  late final Future<String?> _userIdFuture;

  @override
  void initState() {
    super.initState();
    final config = widget.config;
    _repository = config.repository ?? config._resolveRepository();
    _resolver = config._resolveGpsResolver();
    // DEFECT A: never default to the mock `user-client-001`. An injected id
    // (tests / dev seams) wins; otherwise resolve the authenticated id from
    // [AuthTokenStore] — the REAL user, never a hardcoded mock. Computed once.
    final injected = config.userId;
    _userIdFuture = injected != null
        ? Future<String?>.value(injected)
        : config._authTokenStore().userId;
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final scaffold = _Scaffold(
      onAddLocation: config.onAddLocation,
      onConfirm: config.onConfirm,
      onOpenSavedAddresses: config.onOpenSavedAddresses,
      onDictate: config.onDictate,
      legacyCurrentSelected: config.currentSelected,
      onSelectCurrent: config.onSelectCurrent,
    );
    return FutureBuilder<String?>(
      future: _userIdFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _SessionResolveLoading();
        }
        // Empty string when the session has no stored id; the `me` route still
        // resolves identity from the bearer token, so the list loads correctly.
        final resolvedId = snapshot.data ?? '';
        return BlocProvider<LocationSelectCubit>(
          create: (_) => LocationSelectCubit(
            repository: _repository,
            userId: resolvedId,
            currentLocationResolver: _resolver,
          )..load(),
          child: scaffold,
        );
      },
    );
  }
}

/// The cold-entry gate: the authenticated id has not resolved, so the create
/// flow cannot be built yet. It is the SAME wait as [_CreateFlowLoading] one
/// frame later, so it draws the same state — the only difference is that this
/// one has to bring its own [JeebMidnightField], because there is no scaffold
/// behind it yet.
class _SessionResolveLoading extends StatelessWidget {
  const _SessionResolveLoading();

  @override
  Widget build(BuildContext context) {
    return const JeebMidnightField(
      variant: JeebFieldVariant.content,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: _CreateFlowLoading(
            identifier: 'client_location_session_loading',
          ),
        ),
      ),
    );
  }
}

/// The create flow's §2.7 wait, on `e1` — "bring me anything" is this screen's
/// own subject, and its already-migrated sibling `_SavedAddressesError` draws
/// the same tile, so the cold frame and the failed frame are one family.
class _CreateFlowLoading extends StatelessWidget {
  const _CreateFlowLoading({this.identifier = 'client_location_loading'});

  final String identifier;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: SingleChildScrollView(
        child: JeebEmptyState(
          identifier: identifier,
          status: JeebEmptyStateStatus.loading,
          headline: l10n.savedAddressesLoadingHeadline,
        ),
      ),
    );
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
    // MIDNIGHT: the layered field replaces the flat scaffold fill. The glow
    // stays at the default top-end anchor — a bottom one tinted every
    // translucent card on the list warm.
    return JeebMidnightField(
      variant: JeebFieldVariant.content,
      child: Scaffold(
      backgroundColor: Colors.transparent,
      // Redesign: the header is an in-body row, not a Material app bar — no
      // elevation, no surface tint, no centred title (kit §5 #1).
      body: SafeArea(
        child: Semantics(
          identifier: 'client_location_root',
          container: true,
          explicitChildNodes: true,
          child: Column(
            children: [
              JeebTopBar.back(
                title: l10n.clientLocationTitle,
                identifier: 'client_location_back',
                onLeadingPressed: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
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
            ],
          ),
        ),
      ),
      bottomNavigationBar:
          BlocBuilder<LocationSelectCubit, LocationSelectState>(
        builder: (context, state) => _ConfirmFooter(
          state: state,
          description: _description,
          submitting: _submitting,
          onConfirm: widget.onConfirm,
        ),
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
      return const _CreateFlowLoading();
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
        // R12: sections breathe at 14–20, cards at 9–12. The old 24/20 rhythm
        // is off this board entirely.
        const SizedBox(height: Spacing.medium),
        _Heading(text: l10n.clientLocationHeading),
        const SizedBox(height: Spacing.small),
        // JEBV4-176 (Q-060): the "Current Location" option now reflects the
        // REAL device-GPS acquisition state and offers honest recovery
        // (permission / services-off / retry) instead of silently pinning the
        // pickup to a hardcoded Beirut coordinate. The Confirm CTA stays
        // disabled until a real fix resolves (see LocationSelectState.canConfirm).
        CurrentLocationStatusCard(
          status: state.currentGpsStatus,
          selected: currentSelected,
          accuracyMeters: state.gpsAccuracyMeters,
          onSelect: () => _onSelectCurrent(context),
          onRetry: () =>
              context.read<LocationSelectCubit>().resolveCurrentGps(),
          onOpenLocationSettings: () =>
              context.read<LocationSelectCubit>().openLocationSettings(),
          onOpenAppSettings: () =>
              context.read<LocationSelectCubit>().openAppSettings(),
        ),
        // Board order: the saved places sit directly under the address card as
        // a pill row (tpl 555-558); the "manage" entry row follows them.
        if (state.hasSavedAddresses) ...[
          const SizedBox(height: Spacing.small),
          SavedAddressPillRow(
            addresses: state.savedAddresses,
            isSelected: state.isSavedSelected,
            onSelect: (id) =>
                context.read<LocationSelectCubit>().selectSaved(id),
          ),
        ],
        // The saved-addresses ENTRY row is an unconditional affordance
        // (63_W1_TEST_PLAN §2.3 — `location_select_saved_addresses_row` →
        // saved-addresses, JM-049). It must NOT be gated on `hasSavedAddresses`:
        // jm-024 taps the row with no `has_saved_addresses` seed, and the
        // manager owns its own empty state. Only the selectable saved-address
        // PILLS above remain conditional on a non-empty list.
        const SizedBox(height: Spacing.small),
        // B-02b: lock the saved-addresses row while a create is in flight so a
        // mid-POST push cannot leave the (still-mounted) footer to navigate the
        // waiting surface from underneath the newly-pushed route.
        _SubmitLock(
          submitting: submitting,
          child: _SavedAddressesRow(onTap: () => _onOpenSaved(context)),
        ),
        const SizedBox(height: Spacing.medium),
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
        const SizedBox(height: Spacing.medium),
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
                // R10: filled glyphs only, and this is a secondary row — muted
                // ink so it sits below the address card in the ink ranking.
                Icon(Icons.bookmark,
                    size: Sizes.medium, color: scheme.onSurfaceVariant),
                const SizedBox(width: Spacing.small),
                Expanded(
                  child: Text(
                    l10n.savedAddressesTitle,
                    style: context.jeebText.body.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(DirectionalIcons.disclosure(context),
                    size: Sizes.medium, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SavedAddressesError extends StatelessWidget {
  const _SavedAddressesError({required this.onRetry});

  /// The block is one band inside a scrolling list, not the whole surface, so
  /// the E1 illustration is drawn at less than half its 300px board width.
  static const double _illustrationSize = 140;

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: Spacing.medium),
      child: JeebEmptyState(
        identifier: 'location_select_saved_addresses_error',
        status: JeebEmptyStateStatus.error,
        headline: l10n.savedLocationsError,
        illustrationSize: _illustrationSize,
        padding: EdgeInsetsDirectional.zero,
        action: JeebCtaButton.outline(
          label: l10n.earningsLoadRetry,
          expand: false,
          onTap: onRetry,
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
      // JeebCtaFooter applies no SafeArea of its own — the docked pad is
      // 24/0/24/32, which is the board's own footer inset.
      child: JeebCtaFooter.single(
        child: Semantics(
          identifier: 'location_select_confirm_cta',
          button: true,
          child: ValueListenableBuilder<bool>(
            valueListenable: widget.submitting,
            builder: (context, submitting, _) =>
                ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.description,
              builder: (context, value, _) {
                final enabled =
                    state.canConfirm && value.text.trim().isNotEmpty;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: OmdsBorderRadius.pill,
                    // A disabled CTA drops its lift (kit §1.6).
                    boxShadow: enabled ? JeebShadows.ctaOrange : null,
                  ),
                  child: OmdsLoadingButton(
                    // l10n: reuses `locationConfirm` ("Confirm location"); a
                    // dedicated `locationSelectConfirmCta` key is requested in
                    // 50_ROUTE_REQUESTS.
                    text: l10n.locationConfirm,
                    isLoading: submitting,
                    isEnabled: enabled,
                    borderRadius: OmdsBorderRadius.pill,
                    onTap: () => _onConfirm(context),
                  ),
                );
              },
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
      // JEBV4-108: a 401 at the create seam means the SESSION is invalid
      // (e.g. an expired or seam-minted token the live gateway rejects) —
      // retrying with the same session can never succeed. Tell the user the
      // truth and route to re-auth instead of a dead-end generic failure.
      // Re-auth is the phone-OTP entry (`/register`, with Apple/Google social);
      // the email/password `/login` funnel was removed in JEBV4-199.
      if (e.failure == RequestSubmissionFailure.unauthorized) {
        messenger?.showSnackBar(
          SnackBar(content: Text(l10n.createSessionExpired)),
        );
        router.goNamed('register');
        return;
      }
      // Stay on the location step and surface a retryable error — never hand
      // off `'new'` (that is exactly the broken path B11 removes).
      // P2-5 honesty: only a NETWORK failure blames connectivity; a 4xx/5xx
      // gets the generic couldn't-create copy instead of "check your
      // connection" misdirection.
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            e.failure == RequestSubmissionFailure.network
                ? l10n.requestSummaryErrorNetwork
                : l10n.chatCreateRequestFailed,
          ),
        ),
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
                // R5 sanctions the mic as one of the board's orange marks —
                // it is the voice-first affordance, and 4.65:1 on white.
                icon: Icon(Icons.mic, color: context.jeebRoles.accent),
                tooltip: l10n.composeDescriptionMicSemantic,
                onPressed: () => _dictate(context),
              ),
            ),
          ),
        ),
        const SizedBox(height: Spacing.xSmall),
        Text(
          l10n.composeDescriptionHelper,
          style: context.jeebText.bodySmall.copyWith(
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
          style: context.jeebText.cardTitle.copyWith(
            color: theme.colorScheme.onSurface,
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
            style: context.jeebText.body.copyWith(
              color: theme.colorScheme.onSurface,
            ),
            onChanged: (v) {
              _touched = true;
              _commit(v);
            },
            // Fill, stroke and radius come from the Midnight
            // `inputDecorationTheme` — the old opaque navy fill + borderless
            // pill was a light-theme remnant.
            decoration: InputDecoration(
              hintText: l10n.recipientPhoneHint,
              errorText: _errorText,
              prefixIcon: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: Spacing.medium,
                  vertical: Spacing.small,
                ),
                child: Text(
                  LebanonPhone.dialCode,
                  style: context.jeebText.body.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0),
            ),
          ),
        ),
        const SizedBox(height: Spacing.xSmall),
        Text(
          l10n.recipientPhoneHelper,
          style: context.jeebText.bodySmall.copyWith(
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
    // MIDNIGHT: `primary` is now ORANGE; section headings are white ink.
    return Text(
      text,
      style: context.jeebText.h2.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}
