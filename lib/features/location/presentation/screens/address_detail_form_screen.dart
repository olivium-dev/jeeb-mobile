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
const Size _addressDetailFormScreenPhoneFrame = Size(390, 844);
const EdgeInsets _addressDetailFormScreenPhoneInsets = EdgeInsets.only(
  top: 47,
  bottom: 34,
);

const Size _addressDetailFormScreenCompactFrame = Size(320, 568);

const Size _addressDetailFormScreenPhoneBox = Size(400, 900);
const Size _addressDetailFormScreenCompactBox = Size(330, 630);

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

@JeebPreview(
  group: 'location',
  name: 'Add path · no pin · Save disabled',
  size: _addressDetailFormScreenPhoneBox,
)
Widget addressDetailFormScreenAddPath() => _addressDetailFormScreenHosted(
      caption: 'Add path · nothing picked yet · Save gated on a real pin',
    );

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
