import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/session/profile_refresh_signals.dart';
import '../../../l10n/app_localizations.dart';
import '../application/display_name_cubit.dart';
import '../data/dio_display_name_repository.dart';
import '../domain/display_name_repository.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../devtool/catalog/fixtures/display_name_setup_screen_fixtures.dart';
import '../../../core/previews/jeeb_preview.dart';

/// Post-OTP display-name onboarding: optional-but-encouraged, skip always available.
class DisplayNameSetupScreen extends StatefulWidget {
  const DisplayNameSetupScreen({
    super.key,
    required this.onDone,
    this.repository,
    this.refreshSignals,
    this.cubit,
  });

  /// Called exactly once when step resolves (save or skip).
  final VoidCallback onDone;

  /// Test seam: scripted repository; null uses DI or fixture mode.
  final DisplayNameRepository? repository;

  /// Test seam: profile-changed broadcast; production uses DI singleton.
  final ProfileRefreshSignals? refreshSignals;

  /// Catalog/test seam: pre-constructed cubit; null builds one from seams.
  final DisplayNameCubit? cubit;

  @override
  State<DisplayNameSetupScreen> createState() => _DisplayNameSetupScreenState();
}

class _DisplayNameSetupScreenState extends State<DisplayNameSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _done = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  DisplayNameRepository? _resolveRepository() {
    if (widget.repository != null) return widget.repository;
    if (sl.isRegistered<Dio>()) return DioDisplayNameRepository(sl<Dio>());
    return null;
  }

  ProfileRefreshSignals? _resolveSignals() {
    if (widget.refreshSignals != null) return widget.refreshSignals;
    if (sl.isRegistered<ProfileRefreshSignals>()) {
      return sl<ProfileRefreshSignals>();
    }
    return null;
  }

  /// Resolves exactly once to prevent double-tap or race conditions.
  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone();
  }

  void _onStateChange(BuildContext context, DisplayNameState state) {
    switch (state.status) {
      case DisplayNameStatus.saved:
        _finish();
      case DisplayNameStatus.failure:
        _showSaveError(context);
      case DisplayNameStatus.idle:
      case DisplayNameStatus.saving:
        break;
    }
  }

  void _showSaveError(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.profileNameStepError)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = BlocConsumer<DisplayNameCubit, DisplayNameState>(
      listener: _onStateChange,
      builder: (context, state) => _buildScaffold(context, state),
    );
    final injected = widget.cubit;
    if (injected != null) {
      return BlocProvider<DisplayNameCubit>.value(value: injected, child: child);
    }
    return BlocProvider<DisplayNameCubit>(
      create: (_) => DisplayNameCubit(
        repository: _resolveRepository(),
        refreshSignals: _resolveSignals(),
      ),
      child: child,
    );
  }

  Widget _buildScaffold(BuildContext context, DisplayNameState state) {
    return Semantics(
      identifier: 'profile_name_root',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.all(Spacing.medium),
            child: _NameStepBody(
              controller: _nameController,
              state: state,
              onSkip: _finish,
            ),
          ),
        ),
      ),
    );
  }
}

/// Heading + subtitle + name field + buttons, start-aligned for RTL.
class _NameStepBody extends StatelessWidget {
  const _NameStepBody({
    required this.controller,
    required this.state,
    required this.onSkip,
  });

  final TextEditingController controller;
  final DisplayNameState state;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Spacing.xLarge),
        Text(
          l10n.profileNameStepTitle,
          key: const Key('profile-name.title'),
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: Spacing.xSmall),
        Text(
          l10n.profileNameStepSubtitle,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: Spacing.xLarge),
        _NameField(controller: controller, enabled: !state.isSaving),
        const SizedBox(height: Spacing.xLarge),
        _SubmitButton(controller: controller, state: state),
        const SizedBox(height: Spacing.small),
        _SkipButton(enabled: !state.isSaving, onSkip: onSkip),
      ],
    );
  }
}

class _NameField extends StatelessWidget {
  const _NameField({required this.controller, required this.enabled});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'profile_name_input',
      container: true,
      child: OmdsTextField(
        key: const Key('profile-name.field'),
        controller: controller,
        enabled: enabled,
        labelText: l10n.profileNameLabel,
        hintText: l10n.profileNameHint,
        textCapitalization: TextCapitalization.words,
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.controller, required this.state});

  final TextEditingController controller;
  final DisplayNameState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Rebuild enablement as user types; controller is source of truth.
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final hasText = value.text.trim().isNotEmpty;
        return Semantics(
          identifier: 'profile_name_submit_cta',
          button: true,
          container: true,
          child: OmdsLoadingButton(
            key: const Key('profile-name.submit'),
            text: l10n.profileNameStepCta,
            isLoading: state.isSaving,
            isEnabled: hasText && !state.isSaving,
            onTap: () =>
                context.read<DisplayNameCubit>().submit(controller.text),
          ),
        );
      },
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.enabled, required this.onSkip});

  final bool enabled;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'profile_name_skip_cta',
      button: true,
      container: true,
      child: OmdsPrimaryButton(
        key: const Key('profile-name.skip'),
        text: l10n.profileNameStepSkip,
        variant: OmdsButtonVariant.text,
        isEnabled: enabled,
        onTap: onSkip,
      ),
    );
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The phone this step is designed against.
const Size _displayNameSetupScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports (iPhone SE 1st gen and the small
/// Android estate) — and roughly what an Android multi-window split leaves a
const Size _displayNameSetupScreenCompactBox = Size(320, 568);

/// The caption each preview is pinned by.
/// Public because the render test's `expectedText` map is the reason they
final class DisplayNameSetupScreenCaptions {
  DisplayNameSetupScreenCaptions._();

  /// The step as every user first meets it.
  static const String idle = 'preview · idle · nothing typed';

  /// `PUT /api/User/profile` in flight and never landing.
  static const String saving = 'preview · saving · PUT in flight, no exit';

  /// The PUT rejected; the step stays put.
  static const String failure = 'preview · failure · PUT rejected (fail-soft)';

  /// `saved` reached with no repository — the silent-drop branch.
  static const String savedWithoutRepository =
      'preview · saved · with NO repository (nothing was sent)';

  /// The layout ceiling: 320x568.
  static const String compactCeiling = 'preview · 320 x 568 ceiling';
}

/// Puts a dev caption above the device frame, so a card that is pixel-identical
/// to its neighbour still says which state it is.
class _DisplayNameSetupScreenCaptioned extends StatelessWidget {
  const _DisplayNameSetupScreenCaptioned({
    required this.caption,
    required this.child,
  });

  final String caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.small,
            vertical: Spacing.xSmall,
          ),
          child: Text(
            caption,
            // Dev chrome: LTR and unscaled, so the AR card still reads it as
            textDirection: TextDirection.ltr,
            textScaler: TextScaler.noScaling,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Flexible(child: child),
      ],
    );
  }
}

/// Seats [DisplayNameSetupScreen] on one fixture at a pinned device box.
/// Exactly one of [repository] / [cubit] is ever passed: `repository` is the
Widget _displayNameSetupScreenHosted({
  required String caption,
  DisplayNameRepository? repository,
  DisplayNameCubit? cubit,
  bool submitAfterMount = false,
  Size box = _displayNameSetupScreenPhoneBox,
  bool muteTicker = false,
}) {
  Widget screen = DisplayNameSetupScreen(
    onDone: () {},
    repository: repository,
    cubit: cubit,
  );
  if (submitAfterMount && cubit != null) {
    screen = DisplayNameSetupScreenPreviewDriver(cubit: cubit, child: screen);
  }
  return _DisplayNameSetupScreenCaptioned(
    caption: caption,
    child: Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: box.width,
        height: box.height,
        child: muteTicker ? TickerMode(enabled: false, child: screen) : screen,
      ),
    ),
  );
}

/// The reference reading: the step as it is mounted after OTP, with an empty
/// field and nothing in flight.
@JeebPreview(
  group: 'profile_name',
  name: 'Idle · nothing typed',
  size: _displayNameSetupScreenPhoneBox,
  matrix: true,
)
Widget displayNameSetupScreenIdle() => _displayNameSetupScreenHosted(
      caption: DisplayNameSetupScreenCaptions.idle,
      repository: DisplayNameSetupScreenPreviewFixtures.accepting,
    );

/// `PUT /api/User/profile` is in flight: the CTA swaps its label for a spinner
/// and the field, the CTA and Skip are all disabled.
@JeebPreview(
  group: 'profile_name',
  name: 'Saving · PUT in flight',
  size: _displayNameSetupScreenPhoneBox,
)
Widget displayNameSetupScreenSaving() => _displayNameSetupScreenHosted(
      caption: DisplayNameSetupScreenCaptions.saving,
      cubit: DisplayNameSetupScreenPreviewFixtures.saving(),
      muteTicker: true,
    );

/// The PUT was rejected: `profileNameStepError` in a snackbar, and the form
/// comes straight back — fail-soft, the step is never a hard block.
@JeebPreview(
  group: 'profile_name',
  name: 'Error · PUT rejected',
  size: _displayNameSetupScreenPhoneBox,
)
Widget displayNameSetupScreenSaveFailed() => _displayNameSetupScreenHosted(
      caption: DisplayNameSetupScreenCaptions.failure,
      cubit: DisplayNameSetupScreenPreviewFixtures.rejecting(),
      submitAfterMount: true,
    );

/// `DisplayNameStatus.saved` — reached with **no repository at all**.
/// Two things at once, and they are the same pixel.
@JeebPreview(
  group: 'profile_name',
  name: 'Saved · no repository, nothing sent',
  size: _displayNameSetupScreenPhoneBox,
)
Widget displayNameSetupScreenSavedWithoutRepository() =>
    _displayNameSetupScreenHosted(
      caption: DisplayNameSetupScreenCaptions.savedWithoutRepository,
      cubit: DisplayNameSetupScreenPreviewFixtures.savedWithoutRepository(),
    );

/// Layout ceiling: the narrowest supported phone, 320x568.
/// The user data on this screen is a name that no seam can seed, so the ceiling
@JeebPreview(
  group: 'profile_name',
  name: 'Compact 320x568 · layout ceiling',
  size: _displayNameSetupScreenCompactBox,
  matrix: true,
)
Widget displayNameSetupScreenCompactCeiling() => _displayNameSetupScreenHosted(
      caption: DisplayNameSetupScreenCaptions.compactCeiling,
      repository: DisplayNameSetupScreenPreviewFixtures.accepting,
      box: _displayNameSetupScreenCompactBox,
    );
