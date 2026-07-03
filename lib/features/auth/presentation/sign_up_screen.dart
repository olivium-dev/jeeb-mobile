import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/dev_seam/social_auth_seam.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/network/auth_token_store.dart';
import '../../../core/theme/jeeb_color_roles.dart';
import '../../../l10n/app_localizations.dart';
import '../application/sign_up_cubit.dart';
import '../application/sign_up_state.dart';
import '../data/dio_auth_repository.dart';
import '../domain/auth_repository.dart';
import '../social/social_auth_cubit.dart';
import '../social/social_auth_service.dart';
import '../social/social_auth_state.dart';
import '../social/social_auth_token_store.dart';
import '../social/social_provider.dart';
import 'social_collision_sheet.dart';

/// Optional cubit factory the screen exposes for tests. Production leaves it
/// `null` so the default DI-backed cubit is used.
typedef SignUpCubitFactory = SignUpCubit Function(AuthRepository repository);

/// `sign-up` (JM-008). Email-first sign-up (CTO-D1): collects Name / Email /
/// Password, derives a password-strength hint, and on submit routes to phone-OTP
/// verification (the reused `/register` step, G8) before the account is active.
/// The account is created `status:"active"` but the **email is NOT verified
/// here** (D21) and the **phone still needs OTP** (G8). A 409 `email_collision`
/// (D22) opens the social-collision prompt (JM-019).
///
/// Wiring (42_GUARDRAILS_MOCK W-1 FLOOR): `POST /v1/auth/signup` via
/// [AuthRepository] (DI-registered `DioAuthRepository`). 201 → session persisted
/// → phone-OTP; 409 → [SocialCollisionSheet].
///
/// Semantics identifiers exposed (EXACT, 60_W0_TEST_PLAN §2.4):
///   signup_name_field · signup_email_field · signup_password_field ·
///   signup_password_visibility_toggle · signup_password_strength_hint ·
///   signup_submit_cta · signup_login_link ·
///   signup_social_google · signup_social_facebook · signup_social_apple
class SignUpScreen extends StatelessWidget {
  const SignUpScreen({
    super.key,
    this.repository,
    this.cubitFactory,
    this.onSubmittedForOtp,
  });

  /// Test seam — production leaves null and resolves [AuthRepository] from DI.
  final AuthRepository? repository;

  /// Test seam — see [SignUpCubitFactory].
  final SignUpCubitFactory? cubitFactory;

  /// Test seam — overrides the post-signup navigation (defaults to routing to
  /// the reused phone-OTP verify step). Tests inject their own so the screen
  /// doesn't need the full router in scope.
  final VoidCallback? onSubmittedForOtp;

  AuthRepository _resolveRepository() {
    final explicit = repository;
    if (explicit != null) return explicit;
    // Fall back to a freshly constructed Dio-backed impl when GetIt is not
    // configured (e.g. the integrator's `w0_routes_resolve_test.dart`, which
    // mounts the route table without `configureDependencies()`), mirroring
    // `login_screen.dart`'s `_resolveAuthRepository()`.
    if (sl.isRegistered<AuthRepository>()) return sl<AuthRepository>();
    return DioAuthRepository(resolveGatewayDio(), AuthTokenStore());
  }

  @override
  Widget build(BuildContext context) {
    final repo = _resolveRepository();
    return BlocProvider<SignUpCubit>(
      create: (_) => (cubitFactory ?? (r) => SignUpCubit(repository: r))(repo),
      child: _SignUpView(onSubmittedForOtp: onSubmittedForOtp),
    );
  }
}

class _SignUpView extends StatefulWidget {
  const _SignUpView({this.onSubmittedForOtp});

  final VoidCallback? onSubmittedForOtp;

  @override
  State<_SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends State<_SignUpView> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    final state = context.read<SignUpCubit>().state;
    _nameController = TextEditingController(text: state.name);
    _emailController = TextEditingController(text: state.email);
    _passwordController = TextEditingController(text: state.password);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Routes to the reused phone-OTP verification step (CTO-D1 / G8). The
  /// registered `register` route hosts the phone+OTP flow whose OTP input
  /// surfaces `phone_otp_input` (JM-009 — the nav-matrix destination for a
  /// valid sign-up). Tests inject [onSubmittedForOtp] to capture this instead.
  void _goToPhoneOtp() {
    final override = widget.onSubmittedForOtp;
    if (override != null) {
      override();
      return;
    }
    context.goNamed('register');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocListener<SignUpCubit, SignUpState>(
      listenWhen: (prev, curr) => prev.status != curr.status,
      listener: (context, state) async {
        switch (state.status) {
          case SignUpStatus.succeeded:
            // Acknowledge first so a rebuild doesn't re-fire, then route.
            context.read<SignUpCubit>().acknowledge();
            _goToPhoneOtp();
          case SignUpStatus.collision:
            context.read<SignUpCubit>().acknowledge();
            // D22 → JM-019 prompt. The sheet's CTAs own the /login + /sign-up
            // navigation (21_NAV_PLAN §C); we only present it.
            await SocialCollisionSheet.show(context, email: state.email.trim());
          case SignUpStatus.failed:
            showOmdsErrorSnackbar(
              context,
              message: _errorCopy(l10n, state.error),
            );
            context.read<SignUpCubit>().acknowledge();
          case SignUpStatus.idle:
          case SignUpStatus.submitting:
            break;
        }
      },
      child: Semantics(
        identifier: 'signup_root',
        container: true,
        child: Scaffold(
          appBar: OMDSAppBar(title: l10n.signupTitle, showBackButton: true),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                Spacing.medium,
                Spacing.medium,
                Spacing.medium,
                Spacing.xLarge,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _NameField(controller: _nameController),
                  const SizedBox(height: Spacing.medium),
                  _EmailField(controller: _emailController),
                  const SizedBox(height: Spacing.medium),
                  _PasswordField(controller: _passwordController),
                  const SizedBox(height: Spacing.xSmall),
                  const _PasswordStrengthHint(),
                  const SizedBox(height: Spacing.large),
                  const _SubmitButton(),
                  const SizedBox(height: Spacing.medium),
                  const _LoginLink(),
                  const SizedBox(height: Spacing.large),
                  _OrDivider(label: l10n.registrationSocialDivider),
                  const SizedBox(height: Spacing.large),
                  const _SocialRow(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Maps a non-collision [AuthFailure] to localized copy (40_GUARDRAILS_ARCH §3).
String _errorCopy(AppLocalizations l10n, AuthFailure? failure) {
  switch (failure) {
    case AuthFailure.network:
      return l10n.loginNetworkError;
    case AuthFailure.emailCollision:
    case AuthFailure.invalidCredentials:
    case AuthFailure.invalidRecoveryCode:
    case AuthFailure.invalidToken:
    case AuthFailure.badRequest:
    case AuthFailure.unknown:
    case null:
      // Generic fallback — `email_collision` never reaches here (routed to the
      // sheet); the remaining auth-leg codes are not produced by signup.
      return l10n.registrationSocialErrorGeneric;
  }
}

class _NameField extends StatelessWidget {
  const _NameField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<SignUpCubit>().state;
    return Semantics(
      identifier: 'signup_name_field',
      textField: true,
      child: OmdsTextField(
        controller: controller,
        labelText: l10n.signupNameLabel,
        hintText: l10n.signupNameHint,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        enabled: !state.isSubmitting,
        onChanged: (value) => context.read<SignUpCubit>().nameChanged(value),
      ),
    );
  }
}

class _EmailField extends StatelessWidget {
  const _EmailField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<SignUpCubit>().state;
    return Semantics(
      identifier: 'signup_email_field',
      textField: true,
      child: OmdsTextField(
        controller: controller,
        labelText: l10n.signupEmailLabel,
        hintText: l10n.signupEmailHint,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        enabled: !state.isSubmitting,
        onChanged: (value) => context.read<SignUpCubit>().emailChanged(value),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<SignUpCubit>();
    final state = context.watch<SignUpCubit>().state;
    return Semantics(
      identifier: 'signup_password_field',
      textField: true,
      obscured: !state.passwordVisible,
      child: OmdsTextField(
        controller: controller,
        labelText: l10n.signupPasswordLabel,
        hintText: l10n.signupPasswordHint,
        obscureText: !state.passwordVisible,
        textInputAction: TextInputAction.done,
        enabled: !state.isSubmitting,
        onChanged: cubit.passwordChanged,
        onSubmitted: (_) => cubit.submit(),
        // Visibility toggle (signup_password_visibility_toggle) — flips masking
        // on the field above without losing focus/value (JM-008 AC2b).
        suffixIcon: Semantics(
          identifier: 'signup_password_visibility_toggle',
          button: true,
          toggled: state.passwordVisible,
          child: IconButton(
            icon: Icon(
              state.passwordVisible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            onPressed: cubit.togglePasswordVisibility,
          ),
        ),
      ),
    );
  }
}

/// Reflects the entered password's strength (signup_password_strength_hint,
/// JM-008 AC2a). Always present on the screen; the copy + color track the
/// derived bucket. A blank-but-present node keeps the id assertable even before
/// the user types (R-F least-surprising).
class _PasswordStrengthHint extends StatelessWidget {
  const _PasswordStrengthHint();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final strength = context.select<SignUpCubit, PasswordStrength>(
      (cubit) => cubit.state.passwordStrength,
    );

    final (String label, Color color) = switch (strength) {
      PasswordStrength.empty => ('', theme.colorScheme.onSurfaceVariant),
      PasswordStrength.weak => (
          l10n.signupPasswordStrengthWeak,
          theme.colorScheme.error,
        ),
      // Strength meter reads in semantic roles: weak = error, medium =
      // warning, strong = success (brand tertiary/primary were doing state duty).
      PasswordStrength.medium => (
          l10n.signupPasswordStrengthMedium,
          context.jeebRoles.warning,
        ),
      PasswordStrength.strong => (
          l10n.signupPasswordStrengthStrong,
          context.jeebRoles.success,
        ),
    };

    return Semantics(
      identifier: 'signup_password_strength_hint',
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: color),
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<SignUpCubit>();
    final state = context.watch<SignUpCubit>().state;
    return Semantics(
      identifier: 'signup_submit_cta',
      button: true,
      enabled: state.isSubmittable,
      label: l10n.signupSubmitCta,
      child: ExcludeSemantics(
        child: OmdsLoadingButton(
          text: l10n.signupSubmitCta,
          isLoading: state.isSubmitting,
          isEnabled: state.isSubmittable,
          onTap: cubit.submit,
        ),
      ),
    );
  }
}

/// "Already have an account? Sign in" → /login (signup_login_link, JM-008 AC3).
class _LoginLink extends StatelessWidget {
  const _LoginLink();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Semantics(
        identifier: 'signup_login_link',
        button: true,
        label: l10n.signupLoginLink,
        // EDGE (21_NAV_PLAN §C, JM-008→JM-007): signup_login_link → /login.
        onTap: () => context.goNamed('login'),
        child: ExcludeSemantics(
          child: TextButton(
            onPressed: () => context.goNamed('login'),
            child: Text(
              l10n.signupLoginLink,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.primary,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "— or —" divider above the social row. Mirrors the registration screen's
/// themed divider (OMDS ships no divider component).
class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: Divider(color: colorScheme.outlineVariant)),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: Spacing.medium,
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        Expanded(child: Divider(color: colorScheme.outlineVariant)),
      ],
    );
  }
}

/// The social-sign-up row (JM-008 AC4, JM-018). Google / Facebook / Apple are
/// all present per 60_W0_TEST_PLAN §2.4 (all three regardless of platform — the
/// presence assertion does not platform-gate Apple). JM-018 owns the wire-up:
/// each button drives the [SocialAuthCubit] (provided here) and the cubit's
/// outcomes route per the JM-018 ACs — success+no-phone → phone-OTP (G8),
/// 409 → the `social-collision-prompt` sheet (JM-019). Brand names are proper
/// nouns (not translated), consistent with `social_sign_in_button.dart`.
class _SocialRow extends StatelessWidget {
  const _SocialRow();

  @override
  Widget build(BuildContext context) {
    // JM-018: the sign-up screen does not otherwise need a SocialAuthCubit, so
    // it is scoped to the social row. Production wires the Dio-backed
    // DefaultSocialAuthService (mirrors login_screen.dart / registration_screen.dart).
    return BlocProvider<SocialAuthCubit>(
      create: (_) => SocialAuthCubit(
        service: DefaultSocialAuthService(
          dio: resolveGatewayDio(),
          // DEBUG-ONLY (62_SEAM_HARNESS.md): `jeeb.seam.social_login` drives a
          // deterministic social result (no live OAuth). No-op in release.
          seamResolver: SocialAuthSeam.resolver,
        ),
        tokenStore: SecureSocialAuthTokenStore(),
      ),
      child: BlocListener<SocialAuthCubit, SocialAuthState>(
        listenWhen: (prev, curr) => prev.status != curr.status,
        listener: (context, state) {
          // G8 / D22 routing (JM-018), identical to the login screen's hooks.
          if (state.status == SocialAuthStatus.authenticated &&
              state.requiresPhoneVerification) {
            context.goNamed('register');
          } else if (state.status == SocialAuthStatus.collision) {
            context.read<SocialAuthCubit>().acknowledgeCollision();
            SocialCollisionSheet.show(context);
          } else if (state.status == SocialAuthStatus.failed) {
            final l10n = AppLocalizations.of(context);
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            showOmdsErrorSnackbar(
              context,
              message: l10n.registrationSocialErrorGeneric,
            );
            context.read<SocialAuthCubit>().clearError();
          }
        },
        child: const _SocialButtons(),
      ),
    );
  }
}

class _SocialButtons extends StatelessWidget {
  const _SocialButtons();

  @override
  Widget build(BuildContext context) {
    final busy = context.select<SocialAuthCubit, bool>((c) => c.state.isBusy);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _SocialButton(
          identifier: 'signup_social_google',
          icon: Icons.g_mobiledata,
          brandLabel: 'Google',
          provider: SocialProvider.google,
          busy: busy,
        ),
        _SocialButton(
          identifier: 'signup_social_facebook',
          icon: Icons.facebook,
          brandLabel: 'Facebook',
          provider: SocialProvider.facebook,
          busy: busy,
        ),
        _SocialButton(
          identifier: 'signup_social_apple',
          icon: Icons.apple,
          brandLabel: 'Apple',
          provider: SocialProvider.apple,
          busy: busy,
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.identifier,
    required this.icon,
    required this.brandLabel,
    required this.provider,
    required this.busy,
  });

  final String identifier;
  final IconData icon;
  final String brandLabel;
  final SocialProvider provider;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: identifier,
      button: true,
      enabled: !busy,
      label: brandLabel,
      child: ExcludeSemantics(
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            shape: const RoundedRectangleBorder(
              borderRadius: OmdsBorderRadius.medium,
            ),
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: Spacing.large,
              vertical: Spacing.medium,
            ),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          // JM-018: launch the OS-mediated social flow; outcomes route in the
          // _SocialRow listener above (G8 → phone-OTP, 409 → collision sheet).
          onPressed:
              busy ? null : () => context.read<SocialAuthCubit>().signInWith(provider),
          child: Icon(icon, color: colorScheme.onSurface),
        ),
      ),
    );
  }
}
