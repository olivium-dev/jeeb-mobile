import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../application/password_security_cubit.dart';
import '../application/password_security_state.dart';

/// Password-security screen (JM-061): change password (current / new / confirm fields with validation)
/// for password accounts, or "Set a password" entry for social-only (D90).
/// Current password verify + change endpoint not in mock (42_GUARDRAILS_MOCK);
/// only set-password via /v1/auth/set-password. Reaches from customer_profile_password_row (JM-035).
/// GATING: [hasPassword] gates change form. JM-061 AC4 / 67_W34_TEST_PLAN drive social-only variant via
/// `jeeb.seam.account_type=social_only` (not yet landed; defaults to password account).
class PasswordSecurityScreen extends StatelessWidget {
  const PasswordSecurityScreen({
    super.key,
    this.hasPassword = true,
    this.cubitFactory,
  });

  /// Whether account has password set. true → render change-password form; false (social-only, D90) → form suppressed.
  /// When true, both change form and social-only entry render (re-link affordance for password users who also want social).
  final bool hasPassword;

  /// Test seam: overrides cubit construction (40_GUARDRAILS_ARCH §5.4).
  final PasswordSecurityCubit Function()? cubitFactory;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PasswordSecurityCubit>(
      create: (_) => cubitFactory?.call() ?? PasswordSecurityCubit(),
      child: _PasswordSecurityView(hasPassword: hasPassword),
    );
  }
}

class _PasswordSecurityView extends StatefulWidget {
  const _PasswordSecurityView({required this.hasPassword});

  final bool hasPassword;

  @override
  State<_PasswordSecurityView> createState() => _PasswordSecurityViewState();
}

class _PasswordSecurityViewState extends State<_PasswordSecurityView> {
  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _onSubmit() {
    context.read<PasswordSecurityCubit>().submit(
          current: _currentController.text,
          newPassword: _newController.text,
          confirm: _confirmController.text,
        );
  }

  /// B-33: no change-password endpoint yet; surface "not available yet" and STAY on screen.
  void _onUnavailable(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showOmdsSnackbar(context, message: l10n.passwordChangeUnavailable);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'password_security_root',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        appBar: OMDSAppBar(
          title: l10n.passwordSecurityTitle,
          showBackButton: true,
          leading: Semantics(
            identifier: 'password_back',
            button: true,
            container: true,
            child: BackButton(
              // EDGE: password_back → customer-profile (JM-061 AC).
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.goNamed('customer-profile'),
            ),
          ),
        ),
        body: BlocConsumer<PasswordSecurityCubit, PasswordSecurityState>(
          listenWhen: (p, n) =>
              p.status != n.status &&
              n.status == PasswordSecurityStatus.unavailable,
          listener: (context, state) => _onUnavailable(context),
          builder: (context, state) {
            final cubit = context.read<PasswordSecurityCubit>();
            final submitting =
                state.status == PasswordSecurityStatus.submitting;
            return SafeArea(
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  Spacing.medium,
                  Spacing.large,
                  Spacing.medium,
                  Spacing.xLarge,
                ),
                children: [
                  Text(
                    l10n.passwordSecurityBody,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: Spacing.large),

                  if (widget.hasPassword) ...[
                    Semantics(
                      identifier: 'password_current_field',
                      textField: true,
                      child: OmdsTextField(
                        controller: _currentController,
                        labelText: l10n.loginPasswordLabel,
                        hintText: l10n.loginPasswordHint,
                        obscureText: state.currentObscured,
                        autoValidate: false,
                        enabled: !submitting,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => cubit.acknowledgeError(),
                      ),
                    ),
                    const SizedBox(height: Spacing.medium),
                    Semantics(
                      identifier: 'password_new_field',
                      textField: true,
                      child: OmdsTextField(
                        controller: _newController,
                        labelText: l10n.setpwNewLabel,
                        hintText: l10n.setpwNewHint,
                        obscureText: state.newObscured,
                        autoValidate: false,
                        enabled: !submitting,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => cubit.acknowledgeError(),
                        suffixIcon: Semantics(
                          identifier: 'password_new_visibility_toggle',
                          button: true,
                          child: IconButton(
                            icon: Icon(
                              state.newObscured
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: cubit.toggleNewObscured,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.medium),
                    Semantics(
                      identifier: 'password_confirm_field',
                      textField: true,
                      child: OmdsTextField(
                        controller: _confirmController,
                        labelText: l10n.setpwConfirmLabel,
                        hintText: l10n.setpwConfirmHint,
                        obscureText: state.confirmObscured,
                        autoValidate: false,
                        enabled: !submitting,
                        textInputAction: TextInputAction.done,
                        onChanged: (_) => cubit.acknowledgeError(),
                        onSubmitted: (_) => _onSubmit(),
                        suffixIcon: Semantics(
                          identifier: 'password_confirm_visibility_toggle',
                          button: true,
                          child: IconButton(
                            icon: Icon(
                              state.confirmObscured
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: cubit.toggleConfirmObscured,
                          ),
                        ),
                      ),
                    ),
                    if (state.hasStrengthError) ...[
                      const SizedBox(height: Spacing.medium),
                      Semantics(
                        identifier: 'password_strength_error',
                        liveRegion: true,
                        child: Text(
                          l10n.setpwValidationError,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                    if (state.hasMismatchError) ...[
                      const SizedBox(height: Spacing.medium),
                      Semantics(
                        identifier: 'password_mismatch_error',
                        liveRegion: true,
                        child: Text(
                          l10n.setpwValidationError,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: Spacing.xLarge),
                    Semantics(
                      identifier: 'password_submit_cta',
                      button: true,
                      child: OmdsPrimaryButton(
                        text: l10n.setpwSubmitCta,
                        isEnabled: !submitting,
                        onTap: _onSubmit,
                      ),
                    ),
                    const SizedBox(height: Spacing.large),
                  ],

                  // Always reachable: social user without password sees only this; password user sees as re-link.
                  Semantics(
                    identifier: 'password_set_entry',
                    button: true,
                    container: true,
                    child: OmdsPrimaryButton(
                      text: l10n.passwordSetEntryCta,
                      variant: widget.hasPassword
                          ? OmdsButtonVariant.outlined
                          : OmdsButtonVariant.primary,
                      // EDGE: password_set_entry → set-password (?mode=in-app-social, D90).
                      // Pushed (keeps back stack to here); JM-022 screen owns POST + D90 exit.
                      onTap: () =>
                          context.pushNamed('set-password', queryParameters: {
                        'mode': 'in-app-social',
                      }),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
