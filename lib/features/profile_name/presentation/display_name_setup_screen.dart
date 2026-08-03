import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/session/profile_refresh_signals.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
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
          // R1: the block is top-aligned and the residual space below it stays
          // plain white — no Center, nothing stretched to fill it.
          child: SingleChildScrollView(
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

/// Heading → subtitle → name field → Continue → Skip, start-aligned so the
/// column mirrors under RTL. Everything below the Skip exit is deliberately
/// empty white (plan R1).
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
      // The board's 24px side gutters (plan §4.3); the top inset stands in for
      // the top bar this step deliberately does not have — it is a one-way
      // step, so there is no back affordance to render.
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
            style: context.jeebText.h1.copyWith(color: colorScheme.primary),
          ),
          const SizedBox(height: Spacing.xSmall),
          Text(
            l10n.profileNameStepSubtitle,
            // AA-safe brown, NOT the board's periwinkle: plan §4.1 forbids
            // periwinkle as body ink on a light surface.
            style: context.jeebText.body
                .copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: Spacing.xLarge),
          _NameField(controller: controller, enabled: !state.isSaving),
          // Screen 02's rhythm exactly: field → 16 → CTA. The pair stays
          // INLINE rather than docked in a `JeebCtaFooter` — 02 is the one
          // funnel screen whose primary CTA sits under its field, and a docked
          // footer would put the fail-soft skip exit underneath the save-error
          // snackbar.
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
          child: JeebCtaButton.primary(
            key: const Key('profile-name.submit'),
            label: l10n.profileNameStepCta,
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
