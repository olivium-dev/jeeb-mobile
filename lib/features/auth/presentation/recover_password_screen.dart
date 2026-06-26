import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/network/auth_token_store.dart';
import '../../../l10n/app_localizations.dart';
import '../application/recover_password_cubit.dart';
import '../application/recover_password_state.dart';
import '../data/dio_auth_repository.dart';
import '../domain/auth_repository.dart';

/// `recover-password` (JM-020). Email-first password recovery entry: the user
/// types an email into `recover_email_field`, taps `recover_submit_cta`, and on
/// success routes to `/recover/verify` (the code is "emailed" — non-enumerating
/// per the W-1 FLOOR contract, so an unknown email still proceeds). The screen
/// also exposes `recover_signup_link` → sign-up and `recover_back_to_signin_link`
/// → `/login` (60_W0_TEST_PLAN §2.9, navigation matrix §3).
///
/// Reached from the login screen via `login_forgot_password_link` (JM-007).
/// Wires `AuthRepository.requestRecovery` (`POST /v1/auth/recovery/request`,
/// 42_GUARDRAILS_MOCK W-1 FLOOR) through the existing Dio-backed repo in DI.
class RecoverPasswordScreen extends StatelessWidget {
  const RecoverPasswordScreen({super.key});

  /// The production [AuthRepository] from DI. Falls back to a freshly
  /// constructed Dio-backed impl when GetIt is not configured (e.g. the
  /// integrator's `w0_routes_resolve_test.dart`, which mounts the route table
  /// without `configureDependencies()`), mirroring `login_screen.dart`'s
  /// `_resolveAuthRepository()`. The Dio + token store are cheap to construct
  /// and never touched until a submit fires.
  AuthRepository _resolveAuthRepository() {
    if (sl.isRegistered<AuthRepository>()) return sl<AuthRepository>();
    return DioAuthRepository(resolveGatewayDio(), AuthTokenStore());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RecoverPasswordCubit>(
      create: (_) =>
          RecoverPasswordCubit(repository: _resolveAuthRepository()),
      child: const _RecoverPasswordView(),
    );
  }
}

/// Constructor-injectable variant used by widget tests to pass a scripted
/// [AuthRepository] without touching GetIt.
class RecoverPasswordScreenForTest extends StatelessWidget {
  const RecoverPasswordScreenForTest({super.key, required this.repository});

  final AuthRepository repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RecoverPasswordCubit>(
      create: (_) => RecoverPasswordCubit(repository: repository),
      child: const _RecoverPasswordView(),
    );
  }
}

class _RecoverPasswordView extends StatefulWidget {
  const _RecoverPasswordView();

  @override
  State<_RecoverPasswordView> createState() => _RecoverPasswordViewState();
}

class _RecoverPasswordViewState extends State<_RecoverPasswordView> {
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'recover_root',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        appBar: OMDSAppBar(title: l10n.recoverTitle, showBackButton: true),
        body: SafeArea(
          child: BlocConsumer<RecoverPasswordCubit, RecoverPasswordState>(
            // Navigation is a one-shot side effect — gate it on the success
            // transition so it never fires from the builder (40_GUARDRAILS §3).
            listenWhen: (prev, curr) =>
                prev.status != curr.status &&
                curr.status == RecoverPasswordStatus.succeeded,
            listener: (context, state) {
              // EDGE: recover-password → recover-verify (21_NAV_PLAN §C, JM-020).
              // R-F: the verify screen (JM-021) needs the email to call
              // verifyRecovery; pass it via `extra` (40_GUARDRAILS_ARCH §5.3).
              // The route builds `const VerifyRecoveryCodeScreen()` today, so
              // JM-021 reads `state.extra as String?` when it lands.
              context.goNamed('recover-verify', extra: state.email.trim());
            },
            builder: (context, state) {
              final cubit = context.read<RecoverPasswordCubit>();
              return SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  Spacing.medium,
                  Spacing.large,
                  Spacing.medium,
                  Spacing.xLarge,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.recoverTitle,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: Spacing.xSmall),
                    Text(
                      l10n.recoverSubtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: Spacing.large),

                    // ── recover_email_field ──────────────────────────────
                    Semantics(
                      identifier: 'recover_email_field',
                      textField: true,
                      child: OmdsTextField(
                        controller: _emailController,
                        labelText: l10n.recoverEmailLabel,
                        hintText: l10n.recoverEmailHint,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.send,
                        enabled: !state.isSubmitting,
                        onChanged: cubit.emailChanged,
                        onSubmitted: (_) => cubit.submit(),
                      ),
                    ),

                    // Transient failure. The request is non-enumerating, so the
                    // only reachable failure is transport — surface neutral copy
                    // (R-F: reuse loginNetworkError; no recover-scoped error key
                    // exists — see 50_ROUTE_REQUESTS.md L10N REQUEST JM-020).
                    if (state.status == RecoverPasswordStatus.failed) ...[
                      const SizedBox(height: Spacing.small),
                      Semantics(
                        identifier: 'recover_error',
                        liveRegion: true,
                        child: Text(
                          l10n.loginNetworkError,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ),
                    ],

                    const SizedBox(height: Spacing.large),

                    // ── recover_submit_cta ───────────────────────────────
                    Semantics(
                      identifier: 'recover_submit_cta',
                      button: true,
                      child: OmdsLoadingButton(
                        text: l10n.recoverSubmitCta,
                        isLoading: state.isSubmitting,
                        isEnabled: state.canSubmit,
                        onTap: cubit.submit,
                      ),
                    ),

                    const SizedBox(height: Spacing.large),

                    // ── recover_back_to_signin_link ──────────────────────
                    Semantics(
                      identifier: 'recover_back_to_signin_link',
                      button: true,
                      child: OmdsPrimaryButton(
                        text: l10n.recoverBackToSigninLink,
                        variant: OmdsButtonVariant.text,
                        // EDGE: recover-password → login (21_NAV_PLAN §C, JM-020).
                        onTap: () => context.goNamed('login'),
                      ),
                    ),

                    const SizedBox(height: Spacing.xSmall),

                    // ── recover_signup_link ──────────────────────────────
                    Semantics(
                      identifier: 'recover_signup_link',
                      button: true,
                      child: OmdsPrimaryButton(
                        text: l10n.recoverSignupLink,
                        variant: OmdsButtonVariant.text,
                        // EDGE: recover-password → sign-up (21_NAV_PLAN §C, JM-020).
                        onTap: () => context.goNamed('sign-up'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
