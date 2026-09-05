import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/session/profile_refresh_signals.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/app_failure_copy.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_snack.dart';
import '../../../l10n/app_localizations.dart';
import '../application/display_name_cubit.dart';
import '../data/dio_display_name_repository.dart';
import '../domain/display_name_repository.dart';

/// Post-OTP display-name onboarding step.
///
/// Asks the freshly-verified user for a display name (single friendly field,
/// OPTIONAL-but-encouraged — the skip exit is always available and a failed
/// save never blocks registration). Submitting PUTs the name to the gateway
/// (`PUT /api/User/profile` `{username}`, see [DioDisplayNameRepository]);
/// the gateway mirrors it into the users projection so the shell's first
/// `GET /v1/users/me` (greeting/profile) already carries the real name.
///
/// Hosted by [RegistrationScreen]'s production verify path (pushed between
/// OTP-verified and `_navigateHome`). Localized en+ar; layout uses
/// directional paddings + start alignment so RTL mirrors correctly.
///
/// MIDNIGHT M3-33: nearest tile is R6 registration (already shipped at M2-22),
/// the screen this step is pushed from and the only other single-field capture
/// in the funnel. Carried over verbatim: the `content` field with the ORANGE
/// glow at `topEnd` and NO periwinkle wash (wave-D measured R6's bloom as
/// orange top-end), the transparent scaffold, the light status-bar overlay for
/// a field that bleeds under it, the 24px gutter, and R6's forward-CTA
/// treatment — `JeebCtaButton.accent` at [JeebCtaButton.primaryHeightTall].
/// R6 is board-still, so nothing here animates.
///
/// NOT carried: R6's 2px accent rim on its input box. That is documented at
/// `registration_screen.dart` as a per-tile measurement of the R6 phone field
/// ("R6 tile, y 319–385"), not a system rule; the ratified generic field is
/// `app_theme`'s `inputDecorationTheme` (glassFill + glassBorder, focused
/// `inkMuted` 1.5), and theme ruling 3 governs an untraced element ("when in
/// doubt: not orange"). The step's one orange moment is its Continue pill.
///
/// Semantics ids: `profile_name_root` · `profile_name_input` ·
/// `profile_name_submit_cta` · `profile_name_skip_cta`.
class DisplayNameSetupScreen extends StatefulWidget {
  const DisplayNameSetupScreen({
    super.key,
    required this.onDone,
    this.repository,
    this.refreshSignals,
    this.cubit,
  });

  /// Called exactly once when the step resolves — after a successful save OR
  /// when the user skips. The host continues to `_navigateHome`.
  final VoidCallback onDone;

  /// Test seam: a scripted repository. When null the screen self-provides the
  /// Dio-backed repo off GetIt (no DI edit, mirroring [CustomerProfileScreen]);
  /// a bare widget test (no Dio registered) runs in fixture mode (submit
  /// resolves without a network call).
  final DisplayNameRepository? repository;

  /// Test seam for the profile-changed broadcast; production resolves the DI
  /// singleton so greeting surfaces re-pull getMe after the save.
  final ProfileRefreshSignals? refreshSignals;

  /// Catalog/test seam: an already-constructed (optionally pre-driven) cubit.
  /// When null (always in production) the screen builds its own via
  /// [_resolveRepository] / [_resolveSignals], exactly as before this field
  /// was added. Lets the DT-04 screen catalog preview the saving/failure
  /// states without a network call.
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

  /// Resolves the step exactly once (saved OR skipped) so a double-tap or a
  /// save racing a skip can never fire the host continuation twice.
  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone();
  }

  void _onStateChange(BuildContext context, DisplayNameState state) {
    switch (state.status) {
      case DisplayNameStatus.saved:
        _finish();
      case DisplayNameStatus.unavailable:
      // UX-39: nothing was sent, so the step must not report a save. It stays
      // optional — the user can still skip on.
      case DisplayNameStatus.failure:
        _showSaveError(context, state);
      case DisplayNameStatus.idle:
      case DisplayNameStatus.saving:
        break;
    }
  }

  void _showSaveError(BuildContext context, DisplayNameState state) {
    showJeebErrorSnack(
      context,
      message: _copyFor(context, state),
      identifier: 'profile_name_save_error_snack',
    );
  }

  String _copyFor(BuildContext context, DisplayNameState state) {
    final l10n = AppLocalizations.of(context);
    if (state.failure == DisplayNameFailure.unauthorized) {
      return l10n.displayNameErrorUnauthorized;
    }
    final appFailure = state.appFailure;
    if (appFailure != null) return failureCopy(l10n, appFailure).body;
    return switch (state.failure) {
      DisplayNameFailure.network => l10n.errorNetworkBody,
      DisplayNameFailure.serverError => l10n.errorServerBody,
      _ => l10n.profileNameStepError,
    };
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
      // R6: the field bleeds under BOTH bands; raw `.light` paints the
      // Android nav bar black instead of page navy.
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.systemOverlayStyle,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          // R6's field, carried across unchanged: one orange radial top-end,
          // no periwinkle wash, board-still.
          body: JeebMidnightField(
            variant: JeebFieldVariant.content,
            glowPlacement: JeebFieldGlowPlacement.topEnd,
            animateDecor: false,
            child: SafeArea(
              // R6's construction: the field's Stack is `passthrough`, so a
              // bare scroll view would shrink-wrap and leave the band unpainted.
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    // Top-aligned; the residual band below the skip exit is the
                    // field's own glow — no Center, nothing stretched to fill.
                    child: _NameStepBody(
                      controller: _nameController,
                      state: state,
                      onSkip: _finish,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Heading → subtitle → name field → Continue → Skip, start-aligned so the
/// column mirrors under RTL. Everything below the Skip exit is R6's real empty
/// band — the glowing field, never filled.
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
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      // 24px gutters (§5); the top inset stands in for the top bar this one-way
      // step deliberately does not have — there is no back affordance.
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        Spacing.twoXLarge,
        Spacing.xLarge,
        Spacing.xLarge,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.profileNameStepTitle,
            key: const Key('profile-name.title'),
            // Heading ink is `onSurface` app-wide (wave-B standing ruling); the
            // pass-1 `primary` here rendered ORANGE under Midnight.
            style: context.jeebText.h1.copyWith(color: colorScheme.onSurface),
          ),
          const SizedBox(height: Spacing.xSmall),
          Text(
            l10n.profileNameStepSubtitle,
            // `onSurfaceVariant` IS the Midnight muted-ink role (#8A93D8).
            style: context.jeebText.body
                .copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: Spacing.xLarge),
          _NameField(controller: controller, enabled: !state.isSaving),
          // R6's rhythm: field → 16 → CTA. The pair stays INLINE rather than
          // docked, so the skip exit never sits under the save-error snackbar.
          const SizedBox(height: Spacing.medium),
          _SubmitButton(controller: controller, state: state),
          const SizedBox(height: Spacing.xSmall),
          _SkipButton(enabled: !state.isSaving, onSkip: onSkip),
        ],
      ),
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
    // Rebuild enablement as the user types (the controller is the source of
    // truth for the live text — same pattern as the registration send CTA).
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final hasText = value.text.trim().isNotEmpty;
        return Semantics(
          identifier: 'profile_name_submit_cta',
          button: true,
          container: true,
          // The id stays on this wrapper (frozen for Maestro), so the kit pill
          // is left without one — a nested duplicate would shadow it.
          // R6's forward CTA: the funnel's one orange act, h58 with the
          // `ctaOrange` lift. This step is the only orange on the screen.
          child: JeebCtaButton.accent(
            key: const Key('profile-name.submit'),
            label: l10n.profileNameStepCta,
            isLoading: state.isSaving,
            isEnabled: hasText && !state.isSaving,
            height: JeebCtaButton.primaryHeightTall,
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
      // The optional-step exit keeps the bare `text` variant — it must read as
      // the quieter of the two affordances, never as a second pill.
      child: JeebCtaButton.text(
        key: const Key('profile-name.skip'),
        label: l10n.profileNameStepSkip,
        isEnabled: enabled,
        onTap: onSkip,
      ),
    );
  }
}
