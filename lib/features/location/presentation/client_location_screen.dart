import 'package:dio/dio.dart';
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
    this.userId,
    this.onAddLocation,
    this.onConfirm,
    this.onOpenSavedAddresses,
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

  /// Legacy external selection seam (optional). Ignored when null.
  final bool? currentSelected;
  final VoidCallback? onSelectCurrent;

  @override
  Widget build(BuildContext context) {
    final scaffold = _Scaffold(
      onAddLocation: onAddLocation,
      onConfirm: onConfirm,
      onOpenSavedAddresses: onOpenSavedAddresses,
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

  Future<void> _onConfirm(BuildContext context) async {
    // EDGE: location-select → order-chat compose (21_NAV_PLAN.md §C, JM-024
    // AC4 → JM-025). The optional callback REPLACES the default nav for tests /
    // the dev seam.
    final override = onConfirm;
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
    // Capture the navigation + messenger handles BEFORE the async gap: this
    // footer lives in a BlocBuilder, so `context` may be rebuilt (and become
    // unmounted) by the time the create call returns. The GoRouter / messenger
    // instances stay valid, so we drive navigation off them instead of a stale
    // BuildContext.
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = AppLocalizations.of(context);
    try {
      final requestId = await controller.submitFromLocation(state);
      // logcat proof anchor: confirms the create call succeeded with a REAL id
      // (NOT 'new') before we route to order-chat.
      debugPrint('[compose-b11] POST /requests OK → requestId=$requestId');
      // Route order-chat with the REAL request id (no more 'new'). The compose
      // thread broadcasts THIS id, and the chat resolves the conversation by it.
      router.pushNamed('chat-detail', pathParameters: {'id': requestId});
    } on RequestSubmissionException catch (e) {
      debugPrint('[compose-b11] POST /requests FAILED: $e');
      // Stay on the location step and surface a retryable error — never hand
      // off `'new'` (that is exactly the broken path B11 removes).
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.requestSummaryErrorNetwork)),
      );
    }
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
