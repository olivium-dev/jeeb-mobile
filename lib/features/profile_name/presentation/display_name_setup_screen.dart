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
    return BlocProvider<DisplayNameCubit>(
      create: (_) => DisplayNameCubit(
        repository: _resolveRepository(),
        refreshSignals: _resolveSignals(),
      ),
      child: BlocConsumer<DisplayNameCubit, DisplayNameState>(
        listener: _onStateChange,
        builder: (context, state) => _buildScaffold(context, state),
      ),
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

/// Heading → subtitle → name field → Continue → Skip, start-aligned so the
/// column mirrors under RTL.
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
