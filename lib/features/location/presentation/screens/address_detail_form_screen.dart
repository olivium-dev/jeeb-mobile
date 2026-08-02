import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/network/auth_token_store.dart';
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

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';
import '../../../../devtool/catalog/fixtures/address_detail_form_screen_fixtures.dart';

class AddressDetailFormScreen extends StatelessWidget {
  const AddressDetailFormScreen({
    super.key,
    this.addressId,
    this.existing,
    this.userId,
    this.repository,
    this.mapPickerLauncher,
  });

  final String? addressId;

  final SavedLocation? existing;

  final String? userId;

  final AddressFormRepository? repository;

  final MapPickerLauncher? mapPickerLauncher;

  @override
  Widget build(BuildContext context) {
    final editId = addressId ?? existing?.id;
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
          return const Scaffold(body: Center(child: OmdsLoadingState()));
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

  AuthTokenStore _authTokenStore() => sl.isRegistered<AuthTokenStore>()
      ? sl<AuthTokenStore>()
      : AuthTokenStore();

  AddressFormRepository _resolveRepository() {
    if (sl.isRegistered<AddressFormRepository>()) {
      return sl<AddressFormRepository>();
    }
    if (sl.isRegistered<Dio>()) {
      return DioAddressFormRepository(sl<Dio>());
    }
    return const FakeAddressFormRepository();
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

  bool get _isValid =>
      _label.text.trim().isNotEmpty &&
      _hasPin &&
      _latitude != null &&
      _longitude != null;

  void _onEditPin() => unawaited(_editPin());

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
          child: Scaffold(
            appBar: OMDSAppBar(
              title: l10n.addressFormTitle,
              showBackButton: true,
            ),
            body: SafeArea(
              child: _FormBody(
                label: _label,
                building: _building,
                floorApt: _floorApt,
                notes: _notes,
                codPhone: _codPhone,
                hasPin: _hasPin,
                onEditPin: _onEditPin,
                onChanged: () => setState(() {}),
              ),
            ),
            bottomNavigationBar: _SaveBar(
              isEnabled: _isValid,
              isSaving: state.isSaving,
              onSave: _onSave,
            ),
          ),
        );
      },
    );
  }

  void _onStateChange(BuildContext context, AddressFormState state) {
    final l10n = AppLocalizations.of(context);
    if (state.status == AddressFormStatus.saved) {
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
    required this.hasPin,
    required this.onEditPin,
    required this.onChanged,
  });

  final TextEditingController label;
  final TextEditingController building;
  final TextEditingController floorApt;
  final TextEditingController notes;
  final TextEditingController codPhone;
  final bool hasPin;
  final VoidCallback onEditPin;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final f = AddressFormL10n.of(context);
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.medium,
        Spacing.medium,
        Spacing.medium,
        Spacing.xLarge,
      ),
      children: [
        _PinPreview(hasPin: hasPin, onEditPin: onEditPin),
        const SizedBox(height: Spacing.large),
        Semantics(
          identifier: 'address_form_label',
          textField: true,
          child: OmdsTextField(
            controller: label,
            labelText: l10n.savedAddressLabelLabel,
            hintText: l10n.savedAddressLabelHint,
            textInputAction: TextInputAction.next,
            onChanged: (_) => onChanged(),
          ),
        ),
        const SizedBox(height: Spacing.medium),
        Semantics(
          identifier: 'address_form_building',
          textField: true,
          child: OmdsTextField(
            controller: building,
            labelText: f.buildingLabel,
            hintText: f.buildingHint,
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(height: Spacing.medium),
        Semantics(
          identifier: 'address_form_floor_apt',
          textField: true,
          child: OmdsTextField(
            controller: floorApt,
            labelText: f.floorAptLabel,
            hintText: f.floorAptHint,
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(height: Spacing.medium),
        Semantics(
          identifier: 'address_form_delivery_notes',
          textField: true,
          child: OmdsTextField(
            controller: notes,
            labelText: f.deliveryNotesLabel,
            hintText: f.deliveryNotesHint,
            maxLines: 3,
            textInputAction: TextInputAction.newline,
          ),
        ),
        const SizedBox(height: Spacing.medium),
        Semantics(
          identifier: 'address_form_cod_phone',
          textField: true,
          child: OmdsTextField(
            controller: codPhone,
            labelText: f.codPhoneLabel,
            hintText: f.codPhoneHint,
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

class _PinPreview extends StatelessWidget {
  const _PinPreview({required this.hasPin, required this.onEditPin});

  final bool hasPin;
  final VoidCallback onEditPin;

  @override
  Widget build(BuildContext context) {
    final f = AddressFormL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'address_form_map_pin',
      container: true,
      explicitChildNodes: true,
      label: hasPin ? f.pinPlaceholder : f.pinMissing,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            f.pinSectionTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: Spacing.small),
          ClipRRect(
            borderRadius: OmdsBorderRadius.large,
            child: SizedBox(
              height: Sizes.eightXLarge * 2,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const CaptureMapViewport(),
                  if (hasPin) const Center(child: CaptureLocationPin()),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: OmdsBorderRadius.large,
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.small),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Semantics(
              identifier: 'address_form_edit_pin_cta',
              button: true,
              child: OMDSOutlinedButton(
                text: f.editPinCta,
                onTap: onEditPin,
              ),
            ),
          ),
        ],
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
      minimum: const EdgeInsets.fromLTRB(
        Spacing.medium,
        Spacing.small,
        Spacing.medium,
        Spacing.medium,
      ),
      child: Semantics(
        identifier: 'address_form_save_cta',
        button: true,
        container: true,
        child: OmdsLoadingButton(
          text: l10n.addressFormSaveCta,
          isLoading: isSaving,
          isEnabled: isEnabled,
          onTap: onSave,
        ),
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/location/address_detail_form_screen_preview_test.dart
// ===========================================================================
//
// This is a SCREEN, so two things are different from a widget preview.
//
// **The fixtures are not here.** The designed states live in
// `lib/devtool/catalog/fixtures/address_detail_form_screen_fixtures.dart`, so
// the on-device Screen Catalog and this canvas can never disagree about what
// "a saved address" looks like. There is no catalog entry for this screen yet
// — it is one of the 26 without one — and the fixtures were written there
// rather than here precisely so that the entry, when someone writes it, has
// nothing to reinvent. Only the FRAMING below is local.
//
// **The screen brings its own [Scaffold].** `jeebPreviewHost` already wraps
// every preview in one, so returning the screen bare nests two Scaffolds and,
// worse, hands the inner one the canvas box instead of a device box — an
// app bar and a save bar 800 pt wide, with the form's real proportions nowhere
// on screen. Every state below therefore pins its own window with a
// [MediaQuery] + [SizedBox] (the `branded_splash.dart` / request-detail-loader
// pattern): the annotation `size` is honoured by the canvas but NOT by the
// render tests, which pump onto a fixed 800 × 600 surface, so states that
// merely ASKED for a phone box would all be measured at 800 × 600 and collapse
// into one. The caption above each frame is what tells them apart, in the
// canvas and in the test.
//
// Network-free by construction, not by the guard: the cubit is built over
// [AddressDetailFormScreenOfflineRepository], the map picker over a scripted
// launcher, and the keychain over a fake [AuthTokenStore]. No Dio is ever
// resolved, because `_resolveRepository` is only reached when `repository` is
// null and no preview leaves it null.
//
// ## The three states that are NOT here
//
// `AddressFormStatus.saving`, `.saved` and `.failed` cannot be reached by any
// host. [AddressDetailFormScreen] constructs its [AddressFormCubit] inside
// `build`, so a caller can inject the repository the cubit talks to but never
// the STATE the cubit starts in, and the only transition out of `editing` is
// `_onSave` — a tap. The missing seam is exactly one optional constructor
// parameter on [AddressDetailFormScreen]: an `AddressFormCubit? cubit` (or an
// `AddressFormState? initialState`) taken as a `value` provider when non-null,
// the same shape the `repository` seam already has. It is not added here —
// nothing above this banner changes for a preview.
//
// What that costs is not hypothetical. The in-flight save (the CTA's spinner)
// and the failure copy are the two states with real risk in them, and today
// neither the catalog, this canvas, nor a golden test can render either. The
// failure state is worse than unpreviewable: `_onStateChange` shows a snackbar
// and immediately calls `acknowledgeError()`, so a failed save leaves NOTHING
// on the screen — no inline error, no retry, nothing to look at once the four
// seconds are up. In the live canvas you can still see it by hand: tap "Save
// address" on any state whose CTA is enabled and the offline fixture drives
// the real `savedLocationsSaveError` snackbar.
//
// ## What the canvas shows that the widget tests do not
//
// * **Add and edit are the same picture.** The title is `addressFormTitle`
//   ("Address details") on both paths and nothing else names the intent, so
//   [addressDetailFormScreenAddPath] and [addressDetailFormScreenEditPath]
//   differ only by whether the fields happen to have text in them.
// * **Nothing on screen says why Save is off.** On the add path the CTA is
//   disabled until a pin is dropped (JEBV4-176, the fix for a form that used
//   to persist a fabricated Beirut coordinate) — but the reason lives only in
//   the `Semantics` label of the map band (`pinMissing`), which is never
//   drawn. A sighted user gets a dimmed button and a map that looks the same
//   either way.
// * **Two fields are persisted that the form cannot edit.**
//   `SavedLocationCategory` is fixed to the existing address's category (or
//   `home` on the add path) and `isDefault` is copied through, yet `_FormBody`
//   renders no control for either. Every address created here is a `home`.
// * **The `_PinPreview` band is 160 pt whatever the text scale**, so the
//   200 % rendering is the one that shows how little of the form is left above
//   the fold — see [addressDetailFormScreenTextCeiling].

/// The phone the form is designed against: 390 × 844, 47 dp status bar,
/// 34 dp home indicator. The bottom inset is what `_SaveBar`'s [SafeArea]
/// reads, so it is not decoration — it moves the CTA.
const Size _addressDetailFormScreenPhoneFrame = Size(390, 844);
const EdgeInsets _addressDetailFormScreenPhoneInsets = EdgeInsets.only(
  top: 47,
  bottom: 34,
);

/// The small-phone floor the app still has to survive — 320 × 568, no insets.
const Size _addressDetailFormScreenCompactFrame = Size(320, 568);

/// Canvas boxes: the simulated frame, its 1 pt outline, and the caption strip.
const Size _addressDetailFormScreenPhoneBox = Size(400, 900);
const Size _addressDetailFormScreenCompactBox = Size(330, 630);

/// Registers (or clears) the [AuthTokenStore] the screen resolves when no
/// `userId` is injected.
///
/// Always called, never conditionally, so each preview's DI state is fully
/// described by its own arguments rather than by whichever preview the canvas
/// built last. `pending: false` leaves NO store registered at all, which is
/// what `sl.isRegistered` — the screen's own first check — sees on a cold
/// process; those states pass a `userId` and never reach the store anyway.
void _addressDetailFormScreenSeedSession({required bool pending}) {
  if (sl.isRegistered<AuthTokenStore>()) {
    sl.unregister<AuthTokenStore>();
  }
  if (pending) {
    sl.registerSingleton<AuthTokenStore>(
      AddressDetailFormScreenPendingAuthTokenStore(),
    );
  }
}

/// Simulates one device window around [AddressDetailFormScreen] and captions it.
///
/// The caption, the outline and the frame are fixtures — nothing here is
/// production. [TickerMode] is disabled because `OmdsLoadingState` is an
/// indeterminate `CircularProgressIndicator`: a live one never stops scheduling
/// frames and hangs the render tests' `pumpAndSettle`. A still preview wants a
/// still spinner.
class _AddressDetailFormScreenFrame extends StatelessWidget {
  const _AddressDetailFormScreenFrame({
    required this.caption,
    required this.frame,
    required this.child,
    this.insets = EdgeInsets.zero,
    this.textScale,
  });

  final String caption;
  final Size frame;
  final Widget child;
  final EdgeInsets insets;
  final double? textScale;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Preview chrome, pinned to no scaling: a caption that grew with the
        // text scaler would take the credit for any overflow the screen caused
        // on its own in the 200% rendering.
        MediaQuery.withNoTextScaling(
          child: SizedBox(
            width: frame.width,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
              child: Text(
                caption,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: frame,
              padding: insets,
              viewPadding: insets,
              viewInsets: EdgeInsets.zero,
              textScaler:
                  textScale == null ? null : TextScaler.linear(textScale!),
            ),
            child: SizedBox.fromSize(
              size: frame,
              child: TickerMode(enabled: false, child: child),
            ),
          ),
        ),
      ],
    );
  }
}

/// Builds one state of the form inside a device frame.
///
/// Unbounds both axes so a frame taller or wider than the host renders at its
/// real size instead of being clamped to it — the render tests pump onto
/// 800 × 600, which every frame below is taller than.
Widget _addressDetailFormScreenHosted({
  required String caption,
  SavedLocation? existing,
  Size frame = _addressDetailFormScreenPhoneFrame,
  EdgeInsets insets = _addressDetailFormScreenPhoneInsets,
  double? textScale,
  bool sessionPending = false,
}) {
  _addressDetailFormScreenSeedSession(pending: sessionPending);
  return SingleChildScrollView(
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: _AddressDetailFormScreenFrame(
        caption: caption,
        frame: frame,
        insets: insets,
        textScale: textScale,
        child: AddressDetailFormScreen(
          existing: existing,
          userId: sessionPending
              ? null
              : AddressDetailFormScreenFixtures.userId,
          repository: const AddressDetailFormScreenOfflineRepository(),
          mapPickerLauncher: const AddressDetailFormScreenScriptedPinPicker(),
        ),
      ),
    ),
  );
}

/// The add path, first frame: an empty form with no pin.
///
/// This is the JEBV4-176 state and the reason the screen was changed. The form
/// used to open with a hardcoded Beirut centre (33.8886 / 35.4955) already in
/// `_latitude`/`_longitude`, so a customer could save "Home" pinned to a point
/// they never picked. Now `_hasPin` starts false and `_isValid` gates the CTA
/// on a REAL dropped point, which is what this preview is here to keep honest:
/// if "Save address" ever comes up enabled on this frame, that defect is back.
///
/// It is also the state that shows what the gate does NOT come with. The map
/// band renders the same neutral `CaptureMapViewport` placeholder as the edit
/// path, minus the centre pin; the "pick a location" copy exists only as a
/// `Semantics` label; and the disabled CTA carries no hint. What a sighted user
/// sees is a form that refuses to save and does not say why.
@JeebPreview(
  group: 'location',
  name: 'Add path · no pin · Save disabled',
  size: _addressDetailFormScreenPhoneBox,
)
Widget addressDetailFormScreenAddPath() => _addressDetailFormScreenHosted(
      caption: 'Add path · nothing picked yet · Save gated on a real pin',
    );

/// The edit path: an address opened again from the JM-049 manager.
///
/// `initState` copies the [SavedLocation] into the five controllers and sets
/// `_hasPin` from `e != null`, so the pin renders and the CTA is live. Read it
/// next to the add path: the two frames are the same picture with different
/// text in the fields — same title, same map band, same CTA copy — so nothing
/// on the screen distinguishes creating an address from editing one.
///
/// The matrix is on this state because a populated form is where mirroring is
/// visible: the field labels and values swap edges, the "Edit pin" CTA rides
/// `AlignmentDirectional.centerEnd` across to the other side, and the Latin
/// phone number and building name stay LTR inside an RTL field.
@JeebPreview(
  group: 'location',
  name: 'Edit path · saved pin · Save enabled',
  size: _addressDetailFormScreenPhoneBox,
  matrix: true,
)
Widget addressDetailFormScreenEditPath() => _addressDetailFormScreenHosted(
      caption: 'Edit path · saved pin adopted · Save enabled',
      existing: AddressDetailFormScreenFixtures.savedHome,
    );

/// The layout ceiling: every field at the longest a customer plausibly types.
///
/// No field on this screen has a `maxLength`, a counter or a hard cap, so this
/// is not a synthetic worst case — it is what the form allows. Three different
/// behaviours are on one frame: the single-line label and COD phone scroll
/// their own content horizontally and show the END of the string once focused,
/// `building` and `floorApt` do the same, and `deliveryNotes` is capped at
/// `maxLines: 3` and scrolls internally, so four sentences of instructions are
/// readable three lines at a time with no affordance saying there is more.
///
/// The matrix is on this state because copy length is exactly what swings
/// between locales: the Arabic field LABELS are longer than the English ones
/// while the (user-typed) values stay Latin, and 200 % text is where the label
/// and the value stop fitting on the same row.
@JeebPreview(
  group: 'location',
  name: 'Longest content · every field at its ceiling',
  size: _addressDetailFormScreenPhoneBox,
  matrix: true,
)
Widget addressDetailFormScreenLongestContent() =>
    _addressDetailFormScreenHosted(
      caption: 'Longest content · uncapped label, 4-sentence notes',
      existing: AddressDetailFormScreenFixtures.longestContent,
    );

/// Cold mount: the session id has not come back from the keychain yet.
///
/// The live router mounts this screen with no `userId`, so `build` returns a
/// `FutureBuilder` over `AuthTokenStore.userId` and shows a bare centred
/// spinner until it resolves. Held still here by an [AuthTokenStore] whose read
/// never completes.
///
/// Two things are worth looking at. There is no app bar — this branch returns
/// its own `Scaffold(body: Center(...))` rather than the form's chrome — so the
/// screen has no title and no way back while it waits; a slow or wedged
/// keychain read leaves a user on a blank screen they cannot leave except with
/// the system gesture. And the failure is invisible: `snapshot.data ?? ''`
/// swallows an ERROR into an empty user id, so a keychain that throws lands on
/// the same form as a keychain that answers, with `userId: ''` behind it.
@JeebPreview(
  group: 'location',
  name: 'Session resolving · keychain pending',
  size: _addressDetailFormScreenPhoneBox,
)
Widget addressDetailFormScreenSessionResolving() =>
    _addressDetailFormScreenHosted(
      caption: 'Session resolving · keychain read still pending',
      sessionPending: true,
    );

/// The small-phone floor: 320 × 568 with no insets.
///
/// The body is a `ListView`, so the fields simply scroll — the interesting part
/// is the fixed furniture. A 56 dp app bar and the save bar (48 dp CTA plus
/// 8/16 dp of `SafeArea.minimum`) come off a 568 dp screen, and the 160 pt map
/// band takes a third of what is left, so exactly one text field is on screen
/// under the map when the form opens.
@JeebPreview(
  group: 'location',
  name: 'Compact phone · 320 × 568',
  size: _addressDetailFormScreenCompactBox,
)
Widget addressDetailFormScreenCompactPhone() => _addressDetailFormScreenHosted(
      caption: 'Compact phone · 320 x 568 · saved address',
      existing: AddressDetailFormScreenFixtures.savedHome,
      frame: _addressDetailFormScreenCompactFrame,
      insets: EdgeInsets.zero,
    );

/// The accessibility ceiling, pinned into the tree rather than left to the
/// canvas matrix so the render test measures the same layout the canvas draws.
///
/// At a 2.0 scaler every label, hint and value doubles, but three things do
/// not: the app bar (Material clamps toolbar text to 1.34), the CTA's 48 dp
/// box, and the 160 pt map band — `_PinPreview` hardcodes
/// `Sizes.eightXLarge * 2` and never reads the scaler. So the one element that
/// is pure decoration keeps its full share of the screen while the elements
/// carrying meaning grow into a scroll, and the CTA's label has to fit a box
/// that did not grow with it.
@JeebPreview(
  group: 'location',
  name: 'Text ceiling · EN 200%',
  size: _addressDetailFormScreenPhoneBox,
)
Widget addressDetailFormScreenTextCeiling() => _addressDetailFormScreenHosted(
      caption: 'Text ceiling · EN 200% · saved address',
      existing: AddressDetailFormScreenFixtures.savedHome,
      textScale: 2.0,
    );
