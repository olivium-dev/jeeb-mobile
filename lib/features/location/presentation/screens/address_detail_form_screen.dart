import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/network/auth_token_store.dart';
import '../../../../core/theme/jeeb_radii.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../../core/widgets/jeeb/jeeb_glass_card.dart';
import '../../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/address_form_cubit.dart';
import '../../application/address_form_state.dart';
import '../../data/dio_address_form_repository.dart';
import '../../data/fake_address_form_repository.dart';
import '../../data/google_map_picker_launcher.dart';
import '../../data/location_repository.dart';
import '../../data/map_picker_launcher.dart';
import '../../domain/address_form_repository.dart';
import '../../domain/saved_location.dart';
import '../widgets/capture_location_pin.dart';
import '../widgets/capture_map_viewport.dart';
import 'address_form_l10n.dart';

/// `address-detail-form` (JM-050). Full-screen saved-address editor — the
/// promotion of the inline `add_edit_location_sheet.dart` to a routed screen at
/// `/settings/addresses/edit` (21_NAV_PLAN §B batch W1; backlog JM-050, P2).
///
/// Fields (JM-050 AC + 63_W1_TEST_PLAN §2.17): map pin/preview
/// (`address_form_map_pin`) + label (`address_form_label`) + Building
/// (`address_form_building`) + Floor/apt (`address_form_floor_apt`) + Delivery
/// notes (`address_form_delivery_notes`) + COD phone (`address_form_cod_phone`).
/// `address_form_save_cta` persists via `POST/PUT /users/:userId/saved-locations`
/// (the rewriteable `/users` path that reaches the mock) and routes back to
/// `saved-addresses`.
///
/// Self-provides its [AddressFormCubit] over `sl<Dio>()` (40_GUARDRAILS_ARCH
/// §5.4 — screen self-provides), with a `repository` constructor override for
/// tests and a fixture fallback so the `address-detail` route mounts even with
/// no Dio registered (`w1_routes_resolve_test`).
class AddressDetailFormScreen extends StatelessWidget {
  const AddressDetailFormScreen({
    super.key,
    this.addressId,
    this.existing,
    this.userId,
    this.repository,
    this.mapPickerLauncher,
  });

  /// Optional saved-address id passed as `?id=` for the edit path; absent for
  /// the add path. When present the cubit issues a PUT.
  final String? addressId;

  /// Optional pre-fill for the edit path. The JM-049 manager can hand the chosen
  /// [SavedLocation] across via `extra` so the form opens populated; absent for
  /// the add path (and for a cold deep-link with only `?id=`). See the
  /// 50_ROUTE_REQUESTS edge note for the router-side `extra` forwarding.
  final SavedLocation? existing;

  /// Owning user id. When null (the live router mount), it is resolved from
  /// the authenticated session ([AuthTokenStore]) at build time — no mock
  /// fallback. Injectable for tests / dev seams. The save is `me`-scoped
  /// (identity from the bearer token), so this id never appears in the path.
  final String? userId;

  /// Constructor test seam (40_GUARDRAILS_ARCH §5/§6). Never the DI default.
  final AddressFormRepository? repository;

  /// Injectable map-picker seam. Tests pass a fake; production defaults to a
  /// [GoogleMapPickerLauncher] built from the current context when the user
  /// taps "Edit pin" (JEBV4-110 — previously a dead no-op).
  final MapPickerLauncher? mapPickerLauncher;

  @override
  Widget build(BuildContext context) {
    final editId = addressId ?? existing?.id;
    // DEFECT A: never default to the mock `user-client-001`. Use the injected
    // id when a test/dev seam provides one, else resolve the authenticated id
    // from [AuthTokenStore]. The save is `me`-scoped (identity from the bearer
    // token), so the id is not used in the path — but it must be the REAL user.
    final injected = userId;
    if (injected != null) {
      return BlocProvider<AddressFormCubit>(
        create: (_) => AddressFormCubit(
          repository: repository ?? _resolveRepository(),
          userId: injected,
          editId: editId,
        ),
        child: _AddressFormView(existing: existing, mapPickerLauncher: mapPickerLauncher),
      );
    }
    return FutureBuilder<String?>(
      future: _authTokenStore().userId,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _SessionResolveGate();
        }
        final resolvedId = snapshot.data ?? '';
        return BlocProvider<AddressFormCubit>(
          create: (_) => AddressFormCubit(
            repository: repository ?? _resolveRepository(),
            userId: resolvedId,
            editId: editId,
          ),
          child: _AddressFormView(existing: existing, mapPickerLauncher: mapPickerLauncher),
        );
      },
    );
  }

  /// Resolves [AuthTokenStore] from DI when registered (so tests can mock it),
  /// else news one — the same pattern the logout sheet uses. NEVER a mock id.
  AuthTokenStore _authTokenStore() => sl.isRegistered<AuthTokenStore>()
      ? sl<AuthTokenStore>()
      : AuthTokenStore();

  AddressFormRepository _resolveRepository() {
    // Prefer the real Dio impl over the registered Dio (real :4010 gateway);
    // degrade to the in-memory seam only when GetIt has no Dio (isolated host /
    // route-resolve test) so the screen still renders (40_GUARDRAILS_ARCH §4).
    if (sl.isRegistered<AddressFormRepository>()) {
      return sl<AddressFormRepository>();
    }
    if (sl.isRegistered<Dio>()) {
      return DioAddressFormRepository(sl<Dio>());
    }
    return const FakeAddressFormRepository();
  }
}

/// The session-resolve gate — §2.7 loading on the form's own field, so there
/// is no flash when it resolves.
class _SessionResolveGate extends StatelessWidget {
  const _SessionResolveGate();

  @override
  Widget build(BuildContext context) {
    final f = AddressFormL10n.of(context);
    return JeebMidnightField(
      variant: JeebFieldVariant.content,
      glowPlacement: JeebFieldGlowPlacement.topEnd,
      animateDecor: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          key: const Key('address-form-loading'),
          child: JeebEmptyState(
            variant: JeebEmptyStateVariant.radar,
            status: JeebEmptyStateStatus.loading,
            headline: f.loadingHeadline,
          ),
        ),
      ),
    );
  }
}

class _AddressFormView extends StatefulWidget {
  const _AddressFormView({this.existing, this.mapPickerLauncher});

  final SavedLocation? existing;
  final MapPickerLauncher? mapPickerLauncher;

  @override
  State<_AddressFormView> createState() => _AddressFormViewState();
}

class _AddressFormViewState extends State<_AddressFormView> {
  late final TextEditingController _label;
  late final TextEditingController _building;
  late final TextEditingController _floorApt;
  late final TextEditingController _notes;
  late final TextEditingController _codPhone;

  // JEBV4-176: coordinates are nullable and NEVER seeded with a fabricated
  // fallback. The add path starts with no pin (null) — there used to be a
  // hardcoded Beirut centre (`33.8886, 35.4955`) here, so a customer could
  // save a "home" address pinned to downtown Beirut WITHOUT ever picking a
  // point, silently persisting a fabricated coordinate. Now the user must drop
  // a REAL pin via "Edit pin" before Save enables; an existing address opens
  // on its own saved (real) point.
  double? _latitude;
  double? _longitude;
  late SavedLocationCategory _category;
  bool _hasPin = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _label = TextEditingController(text: e?.label ?? '');
    _building = TextEditingController(text: e?.building ?? '');
    _floorApt = TextEditingController(text: e?.floorApt ?? '');
    _notes = TextEditingController(text: e?.deliveryNotes ?? '');
    _codPhone = TextEditingController(text: e?.codPhone ?? '');
    _latitude = e?.latitude;
    _longitude = e?.longitude;
    _category = e?.category ?? SavedLocationCategory.home;
    // Editing an existing address opens on its saved point (pin present); the
    // add path has no pin until the user picks one via "Edit pin" — no
    // fabricated coordinate is ever assumed (JEBV4-176).
    _hasPin = e != null;
  }

  @override
  void dispose() {
    _label.dispose();
    _building.dispose();
    _floorApt.dispose();
    _notes.dispose();
    _codPhone.dispose();
    super.dispose();
  }

  // JEBV4-176: Save is gated on a non-empty label AND a REAL dropped pin. The
  // add path no longer seeds a fabricated Beirut coordinate, so the customer
  // must pick a point via "Edit pin" before the address can be saved — no
  // saved address is ever persisted with an invented coordinate.
  bool get _isValid =>
      _label.text.trim().isNotEmpty &&
      _hasPin &&
      _latitude != null &&
      _longitude != null;

  void _onEditPin() => unawaited(_editPin());

  /// Opens the interactive map picker and adopts the point the user parks under
  /// the centre pin (JEBV4-110). Production builds a [GoogleMapPickerLauncher]
  /// from the current context; tests inject a fake via [widget.mapPickerLauncher].
  /// A null result (cancel) leaves the current pin untouched.
  ///
  /// JEBV4-176: on the add path there is no seeded coordinate, so `initial` is
  /// null and the live picker centres on its own neutral camera start; only the
  /// point the user actually drops is adopted.
  Future<void> _editPin() async {
    final launcher =
        widget.mapPickerLauncher ?? GoogleMapPickerLauncher(context);
    final lat = _latitude;
    final lng = _longitude;
    final result = await launcher.pickOnMap(
      initial: (lat != null && lng != null)
          ? LocationPoint(latitude: lat, longitude: lng)
          : null,
    );
    if (!mounted || result == null) return;
    setState(() {
      _latitude = result.latitude;
      _longitude = result.longitude;
      _hasPin = true;
    });
  }

  void _onSave() {
    if (!_isValid) return;
    final draft = AddressFormDraft(
      label: _label.text.trim(),
      latitude: _latitude!,
      longitude: _longitude!,
      category: _category,
      building: _building.text.trim(),
      floorApt: _floorApt.text.trim(),
      deliveryNotes: _notes.text.trim(),
      codPhone: _codPhone.text.trim(),
      isDefault: widget.existing?.isDefault ?? false,
    );
    context.read<AddressFormCubit>().save(draft);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocConsumer<AddressFormCubit, AddressFormState>(
      listenWhen: (p, n) => p.status != n.status,
      listener: _onStateChange,
      builder: (context, state) {
        return Semantics(
          identifier: 'address_detail_form_root',
          container: true,
          // MIDNIGHT M3-29: R22's field — `content`, orange glow top-end,
          // board-still. This form is a child of the R22 addresses chain.
          child: JeebMidnightField(
            variant: JeebFieldVariant.content,
            glowPlacement: JeebFieldGlowPlacement.topEnd,
            animateDecor: false,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              // Redesign: the header is an in-body row, not a Material app bar
              // — no elevation, no surface tint, no centred title (kit §5 #1).
              body: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    JeebTopBar.back(
                      title: l10n.addressFormTitle,
                      identifier: 'address_form_back',
                    ),
                    Expanded(
                      child: _FormBody(
                        label: _label,
                        building: _building,
                        floorApt: _floorApt,
                        notes: _notes,
                        codPhone: _codPhone,
                        latitude: _latitude,
                        longitude: _longitude,
                        hasPin: _hasPin,
                        onEditPin: _onEditPin,
                        onChanged: () => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: _SaveBar(
                isEnabled: _isValid,
                isSaving: state.isSaving,
                onSave: _onSave,
              ),
            ),
          ),
        );
      },
    );
  }

  void _onStateChange(BuildContext context, AddressFormState state) {
    final l10n = AppLocalizations.of(context);
    if (state.status == AddressFormStatus.saved) {
      // EDGE — JM-050 → JM-049: save returns to the saved-addresses manager.
      context.goNamed('settings-addresses');
    } else if (state.status == AddressFormStatus.failed) {
      showOmdsSnackbar(context, message: l10n.savedLocationsSaveError);
      context.read<AddressFormCubit>().acknowledgeError();
    }
  }
}

class _FormBody extends StatelessWidget {
  const _FormBody({
    required this.label,
    required this.building,
    required this.floorApt,
    required this.notes,
    required this.codPhone,
    required this.latitude,
    required this.longitude,
    required this.hasPin,
    required this.onEditPin,
    required this.onChanged,
  });

  final TextEditingController label;
  final TextEditingController building;
  final TextEditingController floorApt;
  final TextEditingController notes;
  final TextEditingController codPhone;
  final double? latitude;
  final double? longitude;
  final bool hasPin;
  final VoidCallback onEditPin;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final f = AddressFormL10n.of(context);
    return ListView(
      // The board's 24px side gutter (§4.3 `--screen-gutter`); the bottom inset
      // lets the last field clear the docked save pill.
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        Spacing.medium,
        Spacing.xLarge,
        Spacing.xLarge,
      ),
      children: [
        _PinPreview(
          hasPin: hasPin,
          latitude: latitude,
          longitude: longitude,
          onEditPin: onEditPin,
        ),
        const SizedBox(height: Spacing.large),
        _LabelledField(
          identifier: 'address_form_label',
          label: l10n.savedAddressLabelLabel,
          child: OmdsTextField(
            controller: label,
            hintText: l10n.savedAddressLabelHint,
            borderRadius: JeebRadii.lg,
            textInputAction: TextInputAction.next,
            onChanged: (_) => onChanged(),
          ),
        ),
        const SizedBox(height: Spacing.large),
        _LabelledField(
          identifier: 'address_form_building',
          label: f.buildingLabel,
          child: OmdsTextField(
            controller: building,
            hintText: f.buildingHint,
            borderRadius: JeebRadii.lg,
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(height: Spacing.large),
        _LabelledField(
          identifier: 'address_form_floor_apt',
          label: f.floorAptLabel,
          child: OmdsTextField(
            controller: floorApt,
            hintText: f.floorAptHint,
            borderRadius: JeebRadii.lg,
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(height: Spacing.large),
        _LabelledField(
          identifier: 'address_form_delivery_notes',
          label: f.deliveryNotesLabel,
          child: OmdsTextField(
            controller: notes,
            hintText: f.deliveryNotesHint,
            borderRadius: JeebRadii.lg,
            maxLines: 3,
            textInputAction: TextInputAction.newline,
          ),
        ),
        const SizedBox(height: Spacing.large),
        _LabelledField(
          identifier: 'address_form_cod_phone',
          label: f.codPhoneLabel,
          child: OmdsTextField(
            controller: codPhone,
            hintText: f.codPhoneHint,
            borderRadius: JeebRadii.lg,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
            ],
            textInputAction: TextInputAction.done,
          ),
        ),
      ],
    );
  }
}

/// R22's band shape. `OmdsTextField` hard-codes `floatingLabelStyle:
/// colorScheme.primary` — ORANGE under Midnight — so the label moves out here.
class _LabelledField extends StatelessWidget {
  const _LabelledField({
    required this.identifier,
    required this.label,
    required this.child,
  });

  final String identifier;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: identifier,
      textField: true,
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          JeebSectionLabel(label),
          const SizedBox(height: Spacing.xSmall),
          child,
        ],
      ),
    );
  }
}

class _PinPreview extends StatelessWidget {
  const _PinPreview({
    required this.hasPin,
    required this.latitude,
    required this.longitude,
    required this.onEditPin,
  });

  /// Token sheet §4: every glass surface is a 1px hairline. The 1.5px here was
  /// a pass-1 carry-over described as "warm brown"; `outline` is now white 14%.
  static const double _outlineWidth = 1;

  /// R11's `_PinnedPointCard` precision and glyph size, carried verbatim.
  static const int _fractionDigits = 4;
  static const double _pinGlyphSize = 19;

  final bool hasPin;
  final double? latitude;
  final double? longitude;
  final VoidCallback onEditPin;

  @override
  Widget build(BuildContext context) {
    final f = AddressFormL10n.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final glass = theme.extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    return Semantics(
      identifier: 'address_form_map_pin',
      container: true,
      explicitChildNodes: true,
      label: hasPin ? f.pinPlaceholder : f.pinMissing,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          JeebSectionLabel(f.pinSectionTitle),
          const SizedBox(height: Spacing.xSmall),
          ClipRRect(
            borderRadius: BorderRadius.circular(JeebRadii.lg),
            child: SizedBox(
              // ~160pt preview band (8x token doubled — OMDS has no 160 token).
              height: Sizes.eightXLarge * 2,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const CaptureMapViewport(),
                  if (hasPin) const Center(child: CaptureLocationPin()),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(JeebRadii.lg),
                        border: Border.all(
                          color: glass.glassBorder,
                          width: _outlineWidth,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.xSmall),
          _PinnedPointRow(
            hasPin: hasPin,
            latitude: latitude,
            longitude: longitude,
            fractionDigits: _fractionDigits,
            glyphSize: _pinGlyphSize,
            missingLabel: f.pinMissing,
            missingInk: scheme.onSurfaceVariant,
            pinnedInk: scheme.error,
          ),
          const SizedBox(height: Spacing.small),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Semantics(
              identifier: 'address_form_edit_pin_cta',
              button: true,
              child: JeebCtaButton.outline(
                label: f.editPinCta,
                // Intrinsic width: this is a secondary action parked at the end
                // of the band, not a docked full-width pill.
                expand: false,
                onTap: onEditPin,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// R11 `_PinnedPointCard` on the form band. With no pin it says so rather than
/// draw a coordinate — the only reading a Q-021 discarded Confirm gets.
class _PinnedPointRow extends StatelessWidget {
  const _PinnedPointRow({
    required this.hasPin,
    required this.latitude,
    required this.longitude,
    required this.fractionDigits,
    required this.glyphSize,
    required this.missingLabel,
    required this.missingInk,
    required this.pinnedInk,
  });

  final bool hasPin;
  final double? latitude;
  final double? longitude;
  final int fractionDigits;
  final double glyphSize;
  final String missingLabel;
  final Color missingInk;
  final Color pinnedInk;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lat = latitude;
    final lng = longitude;
    final pinned = hasPin && lat != null && lng != null;
    return Semantics(
      identifier: 'address_form_pin_coordinate',
      child: JeebGlassCard(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.small,
          vertical: Spacing.xSmall,
        ),
        child: Row(
          children: [
            Icon(
              pinned ? Icons.location_on : Icons.add_location_alt,
              size: glyphSize,
              color: pinned ? pinnedInk : missingInk,
            ),
            const SizedBox(width: Spacing.small),
            Expanded(
              child: pinned
                  // A lat/long pair reorders inside an RTL paragraph (the comma
                  // flips the numbers), so the whole run is pinned to LTR.
                  ? Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        '${lat.toStringAsFixed(fractionDigits)}, '
                        '${lng.toStringAsFixed(fractionDigits)}',
                        style: context.jeebText.cardTitle
                            .copyWith(color: scheme.onSurface),
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  : Text(
                      missingLabel,
                      style: context.jeebText.bodySmall
                          .copyWith(color: missingInk),
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.isEnabled,
    required this.isSaving,
    required this.onSave,
  });

  final bool isEnabled;
  final bool isSaving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      // JeebCtaFooter applies no SafeArea of its own — the docked pad is
      // 24/0/24/32, which is the board's own footer inset.
      child: JeebCtaFooter.single(
        child: Semantics(
          identifier: 'address_form_save_cta',
          button: true,
          container: true,
          child: JeebCtaButton.primary(
            label: l10n.addressFormSaveCta,
            isLoading: isSaving,
            isEnabled: isEnabled,
            onTap: onSave,
          ),
        ),
      ),
    );
  }
}
