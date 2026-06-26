import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../application/password_security_cubit.dart';
import '../application/password_security_state.dart';

/// password-security (JM-061). Change-password surface reached from the profile
/// `customer_profile_password_row` (JM-035): current / new / confirm fields with
/// validation (the strength + mismatch guards surface through dedicated error
/// nodes). Social-only accounts (no password set) instead use
/// `password_set_entry` → `/set-password?mode=in-app-social` (D90, the existing
/// JM-022 screen owns that `POST /v1/auth/set-password`). `password_back` →
/// customer-profile.
///
/// Mock: — (JM-061 AC). The change form is LOCAL VALIDATION only (the mock has
/// no current-password verify nor a change-by-bearer endpoint,
/// 42_GUARDRAILS_MOCK); the only server write here is delegated to the
/// set-password screen via the social-only entry.
///
/// ACCOUNT-TYPE GATING ([hasPassword]): the JM-061 AC4 / 67_W34_TEST_PLAN drive
/// the social-only variant with `jeeb.seam.account_type=social_only`. That seam
/// is flagged "NEW W4 (Backend + seam)" but has NOT landed yet (the final-wave
/// SEAM agent added only the four `jeeb.seam.journey` values; no `account_type`
/// field exists on `DevSeamConfig`). Until it lands, this screen defaults to a
/// password account ([hasPassword] = true) and renders BOTH the change form and
/// the social-only entry, so every asserted id is reachable in one render and
/// the `password_set_entry → setpw_new_field` nav assertion holds. The
/// constructor flag is the seam-ready gate the integrator flips once the
/// `account_type` field exists (see 50_ROUTE_REQUESTS.md JM-061).
///
/// Ids exposed (30_BACKLOG JM-061 + 67_W34_TEST_PLAN §JM-061):
///   `password_security_root`            — screen host container
///   `password_current_field`            — current password (change path)
///   `password_new_field`                — new password
///   `password_confirm_field`            — confirm
///   `password_new_visibility_toggle`    — eye icon, new field
///   `password_confirm_visibility_toggle`— eye icon, confirm field
///   `password_submit_cta`               — submit the change
///   `password_mismatch_error`           — inline mismatch error
///   `password_strength_error`           — inline strength error
///   `password_set_entry`                — social-only → set-password (D90)
///   `password_back`                     — → customer-profile
class PasswordSecurityScreen extends StatelessWidget {
  const PasswordSecurityScreen({
    super.key,
    this.hasPassword = true,
    this.cubitFactory,
  });

  /// Whether the account already has a password set. `true` → render the
  /// change-password form; `false` (social-only, D90) → the form is suppressed
  /// and only `password_set_entry` shows. Defaults `true` until the
  /// `account_type` seam lands (see class doc). The change form and the
  /// social-only entry are both rendered when `true` so a social user who DID
  /// set a password can still re-link via the entry — the AC requires the entry
  /// to be reachable for the social variant, not hidden for the password one.
  final bool hasPassword;

  /// Test seam: overrides the cubit construction (40_GUARDRAILS_ARCH §5.4).
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

  /// EDGE: a successful change → customer-profile (JM-061 AC `password_back` →
  /// customer-profile; D90 returns to Profile in-app). Pops if it can (keeps the
  /// profile's scroll position) else routes by name.
  void _onSucceeded(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed('customer-profile');
    }
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
              n.status == PasswordSecurityStatus.succeeded,
          listener: (context, state) => _onSucceeded(context),
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

                  // ---- Change-password form (password accounts) ----
                  if (widget.hasPassword) ...[
                    // Current password.
                    Semantics(
                      identifier: 'password_current_field',
                      textField: true,
                      child: OmdsTextField(
                        controller: _currentController,
                        // Reuses the login password label/hint (closest existing
                        // copy; dedicated `passwordCurrent*` keys requested in
                        // 50_ROUTE_REQUESTS.md — ARB is integrator-owned).
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
                    // New password + eye toggle.
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
                    // Confirm password + eye toggle.
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
                    // Strength / empty / same-as-current guard node.
                    if (state.hasStrengthError) ...[
                      const SizedBox(height: Spacing.medium),
                      Semantics(
                        identifier: 'password_strength_error',
                        liveRegion: true,
                        child: Text(
                          // Reuses the set-password validation copy (dedicated
                          // `passwordStrengthError` requested in
                          // 50_ROUTE_REQUESTS.md).
                          l10n.setpwValidationError,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                    // Mismatch guard node.
                    if (state.hasMismatchError) ...[
                      const SizedBox(height: Spacing.medium),
                      Semantics(
                        identifier: 'password_mismatch_error',
                        liveRegion: true,
                        child: Text(
                          // Reuses the set-password validation copy (dedicated
                          // `passwordMismatchError` requested in
                          // 50_ROUTE_REQUESTS.md).
                          l10n.setpwValidationError,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: Spacing.xLarge),
                    // Submit the change.
                    Semantics(
                      identifier: 'password_submit_cta',
                      button: true,
                      child: OmdsPrimaryButton(
                        // Reuses the set-password CTA copy ("Save password").
                        text: l10n.setpwSubmitCta,
                        isEnabled: !submitting,
                        onTap: _onSubmit,
                      ),
                    ),
                    const SizedBox(height: Spacing.large),
                  ],

                  // ---- Social-only "Set a password" entry (D90) ----
                  // Always reachable (see class doc): a social user without a
                  // password sees ONLY this when `hasPassword` is false; a
                  // password user sees it below the form as a re-link affordance.
                  Semantics(
                    identifier: 'password_set_entry',
                    button: true,
                    container: true,
                    child: OmdsPrimaryButton(
                      text: l10n.passwordSetEntryCta,
                      variant: widget.hasPassword
                          ? OmdsButtonVariant.outlined
                          : OmdsButtonVariant.primary,
                      // EDGE: password_set_entry → auth-set-password
                      // (?mode=in-app-social, D90). Pushed (forward nav, keeps a
                      // back stack to here); the JM-022 screen owns the POST +
                      // the D90 in-app-social exit (goNamed customer-profile).
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
