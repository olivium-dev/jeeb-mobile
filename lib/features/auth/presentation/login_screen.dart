import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/dev_seam/social_auth_seam.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/network/auth_token_store.dart';
import '../../../core/network/mock_gateway_client.dart';
import '../../../core/onboarding/onboarding_cubit.dart';
import '../../../core/session/session_cubit.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/data/repositories/biometric_preference_repository_impl.dart';
import '../application/login_cubit.dart';
import '../application/login_state.dart';
import '../data/dio_auth_repository.dart';
import '../domain/auth_repository.dart';
import '../social/social_auth_cubit.dart';
import '../social/social_auth_service.dart';
import '../social/social_auth_state.dart';
import '../social/social_auth_token_store.dart';
import '../social/social_provider.dart';
import 'social_collision_sheet.dart';

/// `login` (JM-007, CTO-D1 email-first funnel). Email + password sign-in that
/// posts the VERIFIED `POST /v1/auth/login` contract (42_GUARDRAILS_MOCK W-1
/// FLOOR) via [AuthRepository]; on success it refreshes the session and lets
/// the router promote `/` to the Requests tab (`shell_tab_requests`, D75).
///
/// Surfaces (60_W0_TEST_PLAN §2.3 — every id is asserted by `jm-007-login.yaml`):
///   login_email_field · login_password_field · login_password_visibility_toggle
///   login_continue_cta · login_forgot_password_link · login_signup_link
///   login_social_google · login_social_facebook · login_social_apple
///   login_biometric_affordance (D23 — only when biometric is enrolled).
///
/// Social CTAs drive the OS-mediated [SocialAuthCubit] (JM-018 owns the
/// post-tap flow; 50_EXECUTION_PLAN: social is a native sheet, NOT a route).
class LoginScreen extends StatelessWidget {
  const LoginScreen({
    super.key,
    this.loginCubit,
    this.socialAuthCubit,
    this.biometricEnrolledOverride,
    this.onLoggedIn,
  });

  /// Test seam (40_GUARDRAILS_ARCH §5.4): inject a cubit with a fake repo.
  /// Production resolves `sl<AuthRepository>()`.
  final LoginCubit? loginCubit;

  /// Test seam: inject a social cubit with a fake service. Production wires the
  /// Dio-backed [DefaultSocialAuthService] (mirrors `registration_screen.dart`).
  final SocialAuthCubit? socialAuthCubit;

  /// Test seam: forces the D23 biometric affordance visible/hidden without a
  /// keystore. `null` in production → reads [BiometricPreferenceRepositoryImpl].
  final bool? biometricEnrolledOverride;

  /// Test seam: replaces the post-login session-refresh + `context.go('/')`
  /// navigation so widget tests don't need the full app shell. `null` in
  /// production → the real promote-to-Requests path runs.
  final VoidCallback? onLoggedIn;

  @override
  Widget build(BuildContext context) {
    Widget withLogin(Widget child) {
      if (loginCubit != null) {
        return BlocProvider<LoginCubit>.value(value: loginCubit!, child: child);
      }
      return BlocProvider<LoginCubit>(
        create: (_) => LoginCubit(repository: _resolveAuthRepository()),
        child: child,
      );
    }

    Widget withSocial(Widget child) {
      if (socialAuthCubit != null) {
        return BlocProvider<SocialAuthCubit>.value(
          value: socialAuthCubit!,
          child: child,
        );
      }
      return BlocProvider<SocialAuthCubit>(
        create: (_) => SocialAuthCubit(
          service: DefaultSocialAuthService(
            dio: MockGatewayClient.createDio(),
            // DEBUG-ONLY (62_SEAM_HARNESS.md): `jeeb.seam.social_login` drives a
            // deterministic social result (no live OAuth). No-op in release.
            seamResolver: SocialAuthSeam.resolver,
          ),
          tokenStore: SecureSocialAuthTokenStore(),
        ),
        child: child,
      );
    }

    return withLogin(
      withSocial(
        _LoginView(
          biometricEnrolledOverride: biometricEnrolledOverride,
          onLoggedIn: onLoggedIn,
        ),
      ),
    );
  }

  /// The production [AuthRepository] from DI. Falls back to a freshly
  /// constructed Dio-backed impl when GetIt is not configured (e.g. the
  /// integrator's `w0_routes_resolve_test.dart`, which mounts the route table
  /// without `configureDependencies()`), mirroring `registration_screen.dart`'s
  /// `MockGatewayClient.createDio()` fallback for its social cubit. The Dio +
  /// token store are cheap to construct and never touched until a submit fires.
  AuthRepository _resolveAuthRepository() {
    if (sl.isRegistered<AuthRepository>()) return sl<AuthRepository>();
    return DioAuthRepository(MockGatewayClient.createDio(), AuthTokenStore());
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView({this.biometricEnrolledOverride, this.onLoggedIn});

  final bool? biometricEnrolledOverride;
  final VoidCallback? onLoggedIn;

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  /// D23 biometric affordance gate. Resolved once on init from the biometric
  /// preference (the "is biometric enrolled?" signal). Null while the async
  /// read is in flight so we never flash the affordance before it resolves.
  bool? _biometricEnrolled;

  /// Local masking state so the eye toggle can carry its own
  /// `login_password_visibility_toggle` Semantics id (the OMDS password field
  /// hides its toggle internally, which Maestro can't tap by id).
  bool _passwordObscured = true;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _resolveBiometricEnrollment();
  }

  Future<void> _resolveBiometricEnrollment() async {
    final override = widget.biometricEnrolledOverride;
    if (override != null) {
      setState(() => _biometricEnrolled = override);
      return;
    }
    // CTO-D R-F: the biometric-enrolled signal is the persisted preference flag.
    // The dev-seam `biometric_enrolled_logged_out` session pre-seed (60 §6) sets
    // it; the integrator/JM-005 own that plumbing. Until then the stub returns
    // false, which is the correct default for `logged_out_returning` (AC1–5).
    // Guard the DI read so the route-resolve test (no `configureDependencies()`)
    // mounts the screen without throwing — absent DI ⇒ affordance hidden.
    if (!sl.isRegistered<SharedPreferences>()) {
      if (mounted) setState(() => _biometricEnrolled = false);
      return;
    }
    final enrolled = await BiometricPreferenceRepositoryImpl(
      prefs: sl<SharedPreferences>(),
    ).isEnabled();
    if (!mounted) return;
    setState(() => _biometricEnrolled = enrolled);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Post-login: mark onboarding complete (so `/` resolves to the shell, not
  /// the walkthrough), refresh the production [SessionCubit] so the router gate
  /// sees the freshly-persisted token, then land on `/` — the `_firstRunRedirect`
  /// routes a logged-in customer to the Requests tab (D75). Mirrors the verified
  /// pattern in `registration_screen.dart` (FR-P0-3 / DEF-1).
  Future<void> _navigateAfterLogin() async {
    final onLoggedIn = widget.onLoggedIn;
    if (onLoggedIn != null) {
      onLoggedIn();
      return;
    }
    await context.read<OnboardingCubit>().complete();
    if (!mounted) return;
    await context.read<SessionCubit?>()?.refresh();
    if (!mounted) return;
    context.go('/');
  }

  void _onSocialTap(SocialProvider provider) {
    context.read<SocialAuthCubit>().signInWith(provider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'login_root',
      container: true,
      child: Scaffold(
        appBar: OMDSAppBar(title: l10n.loginTitle, centerTitle: false),
        body: SafeArea(
          child: BlocConsumer<LoginCubit, LoginState>(
            listenWhen: (prev, curr) => prev.status != curr.status,
            listener: (context, state) async {
              if (state.status == LoginStatus.succeeded) {
                await _navigateAfterLogin();
              } else if (state.status == LoginStatus.failed) {
                showOmdsErrorSnackbar(
                  context,
                  message: _errorCopy(l10n, state.error),
                );
                context.read<LoginCubit>().acknowledgeError();
              }
            },
            builder: (context, state) {
              final cubit = context.read<LoginCubit>();
              return ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  Spacing.medium,
                  Spacing.large,
                  Spacing.medium,
                  Spacing.xLarge,
                ),
                children: [
                  // ── Email ──────────────────────────────────────────────
                  Semantics(
                    identifier: 'login_email_field',
                    textField: true,
                    child: OmdsTextField(
                      controller: _emailController,
                      labelText: l10n.loginEmailLabel,
                      hintText: l10n.loginEmailHint,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      enabled: !state.isSubmitting,
                      autoValidate: false,
                      onChanged: cubit.emailChanged,
                    ),
                  ),
                  const SizedBox(height: Spacing.medium),

                  // ── Password + visibility toggle ───────────────────────
                  Semantics(
                    identifier: 'login_password_field',
                    textField: true,
                    child: OmdsTextField(
                      controller: _passwordController,
                      labelText: l10n.loginPasswordLabel,
                      hintText: l10n.loginPasswordHint,
                      obscureText: _passwordObscured,
                      enabled: !state.isSubmitting,
                      autoValidate: false,
                      textInputAction: TextInputAction.done,
                      onChanged: cubit.passwordChanged,
                      onSubmitted: (_) => cubit.submit(),
                      suffixIcon: Semantics(
                        identifier: 'login_password_visibility_toggle',
                        button: true,
                        child: IconButton(
                          icon: Icon(
                            _passwordObscured
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          tooltip: l10n.loginPasswordLabel,
                          onPressed: () => setState(
                            () => _passwordObscured = !_passwordObscured,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Forgot password link ───────────────────────────────
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Semantics(
                      identifier: 'login_forgot_password_link',
                      button: true,
                      child: TextButton(
                        // EDGE: login → recover-password (60 nav matrix, JM-020).
                        onPressed: () => context.goNamed('recover-password'),
                        child: Text(l10n.loginForgotPasswordLink),
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.small),

                  // ── Primary submit ─────────────────────────────────────
                  Semantics(
                    identifier: 'login_continue_cta',
                    button: true,
                    enabled: state.canSubmit,
                    child: OmdsPrimaryButton(
                      text: l10n.loginContinueCta,
                      isEnabled: state.canSubmit,
                      onTap: cubit.submit,
                      child: state.isSubmitting
                          ? const SizedBox(
                              height: Sizes.large,
                              width: Sizes.large,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                    ),
                  ),

                  // ── D23 biometric affordance (enrolled returning users) ─
                  if (_biometricEnrolled == true) ...[
                    const SizedBox(height: Spacing.small),
                    Semantics(
                      identifier: 'login_biometric_affordance',
                      button: true,
                      child: OmdsPrimaryButton(
                        text: l10n.loginBiometricAffordance,
                        variant: OmdsButtonVariant.outlined,
                        icon: const Icon(Icons.fingerprint),
                        // EDGE: login → biometric lock (D23, JM-005). The lock
                        // route is registered by the integrator (`/lock`).
                        onTap: () => context.goNamed('biometric-lock'),
                      ),
                    ),
                  ],

                  const SizedBox(height: Spacing.large),

                  // ── "or" divider ───────────────────────────────────────
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: Spacing.small,
                        ),
                        child: Text(
                          l10n.registrationSocialDivider,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: Spacing.large),

                  // ── Social row (JM-018 owns the post-tap flow) ──────────
                  _SocialRow(onTap: _onSocialTap),

                  const SizedBox(height: Spacing.large),

                  // ── Sign-up link ───────────────────────────────────────
                  Center(
                    child: Semantics(
                      identifier: 'login_signup_link',
                      button: true,
                      child: TextButton(
                        // EDGE: login → sign-up (60 nav matrix, JM-008).
                        onPressed: () => context.goNamed('sign-up'),
                        child: Text(l10n.loginSignupLink),
                      ),
                    ),
                  ),

                  // ── Phone-OTP entry link (DEFECT-3) ────────────────────
                  // The LIVE gateway has no `/v1/auth/login` or `/v1/auth/signup`
                  // route, so this email screen (and the sign-up link above)
                  // 401 against it. The phone-OTP flow (`/register`,
                  // `POST /v1/auth/otp/request` → `/v1/auth/otp/verify`) is the
                  // ONLY auth that works. The email screens are kept for a later
                  // gateway fix, but this link keeps the working phone-OTP entry
                  // reachable from `/login` too.
                  Center(
                    child: Semantics(
                      identifier: 'login_phone_entry_link',
                      button: true,
                      child: TextButton(
                        onPressed: () => context.goNamed('register'),
                        child: Text(l10n.loginPhoneEntryLink),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The three social CTAs. All three render unconditionally (the platform gate
/// in `SocialSignInButton` hides Apple on Android, but `jm-007-login.yaml` AC5
/// asserts `login_social_apple` regardless of platform, so this screen exposes
/// its own row keyed by the required identifiers). Busy/disabled state reflects
/// the in-flight provider so a double-tap can't open two native sheets.
class _SocialRow extends StatelessWidget {
  const _SocialRow({required this.onTap});

  final ValueChanged<SocialProvider> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocConsumer<SocialAuthCubit, SocialAuthState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status || prev.error != curr.error,
      listener: (context, state) {
        if (state.status == SocialAuthStatus.failed && state.error != null) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          showOmdsErrorSnackbar(
            context,
            message: l10n.registrationSocialErrorGeneric,
          );
          context.read<SocialAuthCubit>().clearError();
        }
        // EDGE (JM-018): social post-auth routing — the hooks JM-007 left.
        // G8: a social success with NO phone on file routes to the reused
        // phone-OTP step (`/register`, JM-009) — never straight home. A 409
        // collision (D22) opens the `social-collision-prompt` sheet (JM-019). A
        // success WITH a phone falls through to the normal session promote.
        if (state.status == SocialAuthStatus.authenticated &&
            state.requiresPhoneVerification) {
          context.goNamed('register');
        } else if (state.status == SocialAuthStatus.collision) {
          context.read<SocialAuthCubit>().acknowledgeCollision();
          SocialCollisionSheet.show(context);
        }
      },
      builder: (context, state) {
        final busy = state.isBusy;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              identifier: 'login_social_google',
              button: true,
              enabled: !busy,
              child: OmdsSocialButtons.google(
                icon: const Icon(Icons.g_mobiledata, size: Sizes.xLarge),
                text: l10n.registrationContinueWithGoogle,
                onTap: busy ? null : () => onTap(SocialProvider.google),
              ),
            ),
            const SizedBox(height: Spacing.small),
            Semantics(
              identifier: 'login_social_facebook',
              button: true,
              enabled: !busy,
              // JM-018: Facebook is now a first-class `SocialProvider` value and
              // posts `provider: "facebook"` to `/v1/auth/social` (B2). Visible
              // label reuses the locale-safe generic `actionContinue` to keep
              // StaticGreen green today (no `Facebook` key exists yet); the
              // dedicated `socialContinueWithFacebook` key is requested in
              // 50_ROUTE_REQUESTS.md for a copy-polish swap. Maestro keys on the
              // `login_social_facebook` id, never the text.
              child: OmdsSocialButtons.facebook(
                icon: const Icon(Icons.facebook, color: Colors.white),
                text: l10n.actionContinue,
                onTap: busy ? null : () => onTap(SocialProvider.facebook),
              ),
            ),
            const SizedBox(height: Spacing.small),
            Semantics(
              identifier: 'login_social_apple',
              button: true,
              enabled: !busy,
              child: OmdsSocialButtons.apple(
                icon: const Icon(Icons.apple, color: Colors.white),
                text: l10n.registrationContinueWithApple,
                onTap: busy ? null : () => onTap(SocialProvider.apple),
              ),
            ),
          ],
        );
      },
    );
  }
}

String _errorCopy(AppLocalizations l10n, AuthFailure? failure) {
  switch (failure) {
    case AuthFailure.network:
      return l10n.loginNetworkError;
    // login only mints `invalidCredentials` / `network` / `badRequest` /
    // `unknown` (W-1 FLOOR); the recovery/set-password/collision failures are
    // listed for switch-exhaustiveness and all degrade to the generic
    // bad-credentials copy on this screen (i18n-safe; Maestro keys on ids).
    case AuthFailure.invalidCredentials:
    case AuthFailure.emailCollision:
    case AuthFailure.badRequest:
    case AuthFailure.invalidRecoveryCode:
    case AuthFailure.invalidToken:
    case AuthFailure.unknown:
    case null:
      return l10n.loginInvalidCredentials;
  }
}
