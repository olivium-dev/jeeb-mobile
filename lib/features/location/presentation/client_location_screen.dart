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
import '../../../core/widgets/directional_icons.dart';
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
import '../domain/saved_location.dart';
import 'widgets/client_location_add_row.dart';
import 'widgets/current_location_status_card.dart';
import 'widgets/delivery_create_layout.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/client_location_screen_fixtures.dart';

/// Trap: dropping `isRouteCurrent` leaves overlay-mounted-but-not-top case unguarded.
@visibleForTesting
bool shouldRouteAfterCreate({
  required bool mounted,
  required bool isRouteCurrent,
}) =>
    mounted && isRouteCurrent;

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
    this.currentSelected,
    this.onSelectCurrent,
  });

  final LocationSelectRepository? repository;
  final CurrentLocationResolver? currentLocationResolver;
  final String? userId;
  final VoidCallback? onAddLocation;
  final VoidCallback? onConfirm;
  final VoidCallback? onOpenSavedAddresses;
  final Future<VoiceClip?> Function()? onDictate;
  final bool? currentSelected;
  final VoidCallback? onSelectCurrent;

  @override
  Widget build(BuildContext context) => _LocationSelectHost(config: this);

  CurrentLocationResolver _resolveGpsResolver() {
    final injected = currentLocationResolver;
    if (injected != null) return injected;
    if (sl.isRegistered<CurrentLocationResolver>()) {
      return sl<CurrentLocationResolver>();
    }
    return GeolocatorCurrentLocationResolver();
  }

  AuthTokenStore _authTokenStore() => sl.isRegistered<AuthTokenStore>()
      ? sl<AuthTokenStore>()
      : AuthTokenStore();

  LocationSelectRepository _resolveRepository() {
    if (sl.isRegistered<LocationSelectRepository>()) {
      return sl<LocationSelectRepository>();
    }
    if (sl.isRegistered<Dio>()) {
      return DioLocationSelectRepository(sl<Dio>());
    }
    return const FakeLocationSelectRepository();
  }
}

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
          return const Scaffold(body: Center(child: OmdsLoadingState()));
        }
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
  final TextEditingController _description = TextEditingController();
  final ValueNotifier<bool> _submitting = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
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
  final ValueListenable<bool> submitting;
  final VoidCallback? onAddLocation;
  final VoidCallback? onOpenSavedAddresses;
  final Future<VoiceClip?> Function()? onDictate;
  final bool? legacyCurrentSelected;
  final VoidCallback? onSelectCurrent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
        _DescriptionSection(
          controller: descriptionController,
          onDictate: onDictate,
        ),
        const SizedBox(height: Spacing.xLarge),
        _Heading(text: l10n.clientLocationHeading),
        const SizedBox(height: Spacing.large),
        CurrentLocationStatusCard(
          status: state.currentGpsStatus,
          selected: currentSelected,
          onSelect: () => _onSelectCurrent(context),
          onRetry: () =>
              context.read<LocationSelectCubit>().resolveCurrentGps(),
          onOpenLocationSettings: () =>
              context.read<LocationSelectCubit>().openLocationSettings(),
          onOpenAppSettings: () =>
              context.read<LocationSelectCubit>().openAppSettings(),
        ),
        const SizedBox(height: Spacing.large),
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
        const _RecipientPhoneField(),
      ],
    );
  }

  void _onSelectCurrent(BuildContext context) {
    context.read<LocationSelectCubit>().selectCurrent();
    onSelectCurrent?.call();
  }

  Future<void> _onAdd(BuildContext context) async {
    if (submitting.value) return;
    final handler = onAddLocation;
    if (handler != null) {
      handler();
      return;
    }
    final cubit = context.read<LocationSelectCubit>();
    final result = await context.pushNamed<Object?>('capture-location');
    final point = result is LocationPoint ? result : null;
    cubit.markPinned(
      latitude: point?.latitude,
      longitude: point?.longitude,
    );
  }

  void _onOpenSaved(BuildContext context) {
    if (submitting.value) return;
    final handler = onOpenSavedAddresses;
    if (handler != null) {
      handler();
      return;
    }
    context.pushNamed('settings-addresses');
  }
}

/// Trap: don't remove IgnorePointer; mid-flight nav must be locked.
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
                Icon(DirectionalIcons.disclosure(context),
                    size: Sizes.large, color: scheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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

class _ConfirmFooter extends StatefulWidget {
  const _ConfirmFooter({
    required this.state,
    required this.description,
    required this.submitting,
    this.onConfirm,
  });

  final LocationSelectState state;
  final TextEditingController description;
  final ValueNotifier<bool> submitting;
  final VoidCallback? onConfirm;

  @override
  State<_ConfirmFooter> createState() => _ConfirmFooterState();
}

class _ConfirmFooterState extends State<_ConfirmFooter> {
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
    if (widget.submitting.value) return;
    final override = widget.onConfirm;
    if (override != null) {
      override();
      return;
    }

    if (!sl.isRegistered<ComposeRequestController>()) {
      context.pushNamed('chat-detail', pathParameters: {'id': 'new'});
      return;
    }

    final controller = sl<ComposeRequestController>();
    controller.setDescription(widget.description.text);
    await _createAndRoute(context, controller);
  }

  Future<void> _createAndRoute(
    BuildContext context,
    ComposeRequestController controller,
  ) async {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = AppLocalizations.of(context);
    final route = ModalRoute.of(context);
    widget.submitting.value = true;
    try {
      final requestId = await controller.submitFromLocation(widget.state);
      if (!shouldRouteAfterCreate(
        mounted: mounted,
        isRouteCurrent: route?.isCurrent ?? false,
      )) {
        return;
      }
      debugPrint('[compose-b11] POST /requests OK → requestId=$requestId');
      router.goNamed('waiting-no-coverage', pathParameters: {'id': requestId});
    } on RequestSubmissionException catch (e) {
      debugPrint('[compose-b11] POST /requests FAILED: $e');
      if (e.failure == RequestSubmissionFailure.unauthorized) {
        messenger?.showSnackBar(
          SnackBar(content: Text(l10n.createSessionExpired)),
        );
        router.goNamed('register');
        return;
      }
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
      if (mounted) widget.submitting.value = false;
    }
  }
}

class _DescriptionSection extends StatefulWidget {
  const _DescriptionSection({required this.controller, this.onDictate});

  final TextEditingController controller;
  final Future<VoiceClip?> Function()? onDictate;

  @override
  State<_DescriptionSection> createState() => _DescriptionSectionState();
}

class _DescriptionSectionState extends State<_DescriptionSection> {
  static const int _maxLength = 280;
  bool _touched = false;

  void _commit(String raw) {
    _touched = true;
    if (sl.isRegistered<ComposeRequestController>()) {
      final compose = sl<ComposeRequestController>();
      compose.setDescription(raw);
      if (compose.description == null) {
        compose.setVoiceNote(transcription: null, audioUrl: null);
      }
    }
    setState(() {});
  }

  Future<void> _dictate(BuildContext context) async {
    final handler = widget.onDictate ??
        () => GoRouter.of(context).pushNamed<VoiceClip>('compose-dictation');
    final clip = await handler();
    if (!mounted || clip == null) return;
    final text = clip.transcript?.trim() ?? '';
    if (text.isEmpty) return;
    final existing = widget.controller.text.trim();
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

  Future<void> _prefillFromProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profile =
          await SharedPrefsProfileRepository(prefs: prefs).load();
      final phone = LebanonPhone.tryParse(profile?.phoneE164 ?? '');
      if (phone == null || !mounted) return;
      if (_controller.text.trim().isEmpty) {
        _controller.text = phone.digits;
        _commit(phone.digits);
      }
    } catch (_) {
    }
  }

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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/location/client_location_screen_preview_test.dart
// ===========================================================================
//
// This is the screen that submits `POST /requests` — the last surface before a
// delivery exists — and it renders four independent things at once: the
// required "What do you need?" compose block, the GPS-acquisition lifecycle,
// the saved-address list, and the recipient-phone capture. Any one of them can
// be in a degraded state while the others are fine, which is precisely what a
// single happy-path screenshot hides.
//
// Every state below is driven through the screen's OWN constructor seams —
// `repository:`, `currentLocationResolver:`, `userId:` — so no cubit is reached
// into and no DI graph is required. The seeds come from
// [ClientLocationScreenFixtures], shared verbatim with the Screen Catalog entry
// in `lib/devtool/catalog/entries/batch_06_entries.dart`: the designer's
// on-device state and the engineer's canvas state are now the same object.
//
// Three things about the host are load-bearing:
//
// * **`jeebPreviewHost` already supplies a Scaffold**, and this screen supplies
//   its own (app bar + sticky Confirm footer). The two nest — the screen's
//   Scaffold simply fills the host's body — which is correct here but means the
//   canvas box has to be a whole phone, not a widget-sized strip. Hence
//   [_clientLocationScreenPhoneBox].
// * **The spinners are frozen.** Two of these states render an indeterminate
//   [CircularProgressIndicator] (the cold-load body, and the `resolving` row
//   inside [CurrentLocationStatusCard]); an unmuted one never stops scheduling
//   frames and hangs the render tests' `pumpAndSettle`. [TickerMode] mutes them
//   and makes the canvas deterministic.
// * **Every navigation seam is overridden.** `onAddLocation` / `onConfirm` /
//   `onOpenSavedAddresses` / `onDictate` would otherwise reach for a GoRouter
//   that does not exist above a preview, so a reviewer tapping a row in the
//   canvas would get a crash instead of a no-op. Overriding `onConfirm` also
//   means no preview can reach `ComposeRequestController.submitFromLocation`.
//
// What these previews cannot show, because the screen has no seam for it: the
// "What do you need?" field is seeded from `sl<ComposeRequestController>()` in
// `_ScaffoldState.initState`, so a pre-filled description is only reachable by
// mutating the global GetIt graph. Every preview below therefore shows the
// field empty — which is also why the Confirm CTA reads as disabled in all of
// them.

/// The canvas box for a whole screen: a 390x844 phone.
const Size _clientLocationScreenPhoneBox = Size(390, 844);

/// The dictation seam, answering "the customer recorded nothing".
///
/// Returning null is the same thing `compose-dictation` pops when the recording
/// is cancelled, so the mic button is tappable in the canvas and correctly does
/// nothing, instead of throwing on a missing GoRouter.
Future<VoiceClip?> _clientLocationScreenNoDictation() async => null;

/// Assembles the real screen from one repository + one GPS resolver, with every
/// navigation seam stubbed and every ticker muted.
Widget _clientLocationScreenHosted({
  required LocationSelectRepository repository,
  required CurrentLocationResolver resolver,
}) {
  return TickerMode(
    enabled: false,
    child: ClientLocationScreen(
      userId: ClientLocationScreenFixtures.userId,
      repository: repository,
      currentLocationResolver: resolver,
      onAddLocation: () {},
      onConfirm: () {},
      onOpenSavedAddresses: () {},
      onDictate: _clientLocationScreenNoDictation,
    ),
  );
}

/// The returning customer, everything healthy: a real device fix resolved, two
/// saved addresses listed under the entry row.
///
/// Worth the full matrix. This screen is a stack of Rows carrying icons,
/// labels and trailing chevrons plus two text fields with helper copy, and its
/// Arabic strings are materially longer than the English ones — the EN light
/// rendering stays believable long after the AR RTL and 200% renderings have
/// broken.
@JeebPreview(
  group: 'location',
  name: 'Saved addresses · GPS resolved',
  size: _clientLocationScreenPhoneBox,
  matrix: true,
)
Widget clientLocationScreenSavedAddresses() => _clientLocationScreenHosted(
      repository: ClientLocationScreenFixtures.savedAddresses,
      resolver: ClientLocationScreenFixtures.gpsResolved,
    );

/// A brand-new customer, mid-GPS-acquisition: `200 {items: []}` from the
/// saved-locations read, fix still in flight.
///
/// Two states worth looking at, and they co-occur on a first run. Note what the
/// empty list does NOT produce: the "Saved addresses" row is unconditional (by
/// design — JM-024 AC2, the manager owns its own empty state), so a customer
/// with zero addresses sees a row identical to one with ten and only finds out
/// after a push.
@JeebPreview(
  group: 'location',
  name: 'New customer · finding GPS',
  size: _clientLocationScreenPhoneBox,
)
Widget clientLocationScreenNewCustomer() => _clientLocationScreenHosted(
      repository: ClientLocationScreenFixtures.noSavedAddresses,
      resolver: ClientLocationScreenFixtures.gpsResolving,
    );

/// Cold load: the saved-locations read has not answered yet.
///
/// The whole create step is replaced by a bare spinner — no app-bar-adjacent
/// context, no skeleton, and the sticky Confirm footer collapses to nothing
/// (`_ConfirmFooter` returns `SizedBox.shrink()` for `initial`/`loading`). On a
/// slow connection this is what the customer stares at after tapping Continue
/// on the tier step, and none of it is the compose content they came to type.
@JeebPreview(
  group: 'location',
  name: 'Cold load',
  size: _clientLocationScreenPhoneBox,
)
Widget clientLocationScreenColdLoad() => _clientLocationScreenHosted(
      repository: ClientLocationScreenFixtures.savedAddressesPending,
      resolver: ClientLocationScreenFixtures.gpsResolved,
    );

/// The saved-locations read failed on transport.
///
/// The rule this makes visible is a deliberate one: a failed sub-list must
/// degrade the sub-list ONLY. The retry banner appears, and "Current Location",
/// "New Location" and the Confirm CTA all stay live, because gating the whole
/// step on `loaded` would dead-end order creation on any network blip
/// ([LocationSelectState.canConfirm]).
@JeebPreview(
  group: 'location',
  name: 'Saved addresses unavailable',
  size: _clientLocationScreenPhoneBox,
)
Widget clientLocationScreenSavedAddressesFailed() =>
    _clientLocationScreenHosted(
      repository: ClientLocationScreenFixtures.savedAddressesUnavailable,
      resolver: ClientLocationScreenFixtures.gpsResolved,
    );

/// JEBV4-176 (Q-060) made visible: location permission denied.
///
/// This is the state that used to silently pin the pickup to `33.8886,
/// 35.4955`. Now the card grows a recovery panel — which is the layout event
/// worth reviewing, because the panel pushes the saved-address row, the "New
/// Location" row and the recipient-phone field down by ~200pt on a screen that
/// already needs scrolling.
@JeebPreview(
  group: 'location',
  name: 'GPS permission denied',
  size: _clientLocationScreenPhoneBox,
)
Widget clientLocationScreenGpsDenied() => _clientLocationScreenHosted(
      repository: ClientLocationScreenFixtures.savedAddresses,
      resolver: ClientLocationScreenFixtures.gpsPermissionDenied,
    );

/// Layout ceiling: one saved address whose label AND subtitle are at the length
/// a customer can actually type into the JM-050 address form (that form caps
/// neither).
///
/// The card ellipsizes both lines, so the whole point is what the customer can
/// still tell apart. The matrix is where this pays: at 200% text the two
/// truncated lines lose most of their distinguishing tail, and in Arabic the
/// ellipsis lands on the opposite edge.
@JeebPreview(
  group: 'location',
  name: 'Longest saved address',
  size: _clientLocationScreenPhoneBox,
  matrix: true,
)
Widget clientLocationScreenLongestContent() => _clientLocationScreenHosted(
      repository: ClientLocationScreenFixtures.longestSavedAddresses,
      resolver: ClientLocationScreenFixtures.gpsResolved,
    );
