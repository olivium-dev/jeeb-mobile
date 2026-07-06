import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../l10n/app_localizations.dart';
import '../application/verify_recovery_code_cubit.dart';
import '../application/verify_recovery_code_state.dart';
import '../domain/auth_repository.dart';

/// `verify-code` (JM-021). Email-based recovery-code entry.
///
/// Reuses [OmdsOtpInput] but is **NOT phone-anchored** — it carries the recovery
/// `email` (handed in via route `extra` from the recover screen, JM-020). A
/// correct code → `POST /v1/auth/recovery/verify` mints a `resetToken`, then
/// routes to `/set-password?mode=recovery` carrying `email`+`resetToken` so the
/// set-password screen (JM-022) can complete the reset. A wrong/expired code →
/// inline `verify_code_error` (screen stays). `verify_code_resend_cta`
/// re-requests the code and stays on the screen (JM-021 AC3).
///
/// Semantics ids exposed (60_W0_TEST_PLAN §2.10):
///   `verify_code_input` · `verify_code_submit_cta` · `verify_code_resend_cta`
///   · `verify_code_error`.
///
/// Architecture (40_GUARDRAILS_ARCH §4): the screen owns its [BlocProvider] and
/// resolves [AuthRepository] from `sl<>()` with a constructor override for
/// tests. Navigation/DI live only in this presentation layer.
class VerifyRecoveryCodeScreen extends StatelessWidget {
  const VerifyRecoveryCodeScreen({
    super.key,
    this.email,
    this.authRepository,
    this.cubit,
  });

  /// The recovery email. Normally `null` here and read from the route `extra`
  /// in [build]; tests may inject it directly to bypass the router.
  final String? email;

  /// Test override for the repository. Production resolves `sl<AuthRepository>()`.
  final AuthRepository? authRepository;

  /// Catalog/test seam (40_GUARDRAILS_ARCH §5.4): inject a pre-built cubit
  /// (e.g. seeded into a specific state) instead of the DI-resolved one.
  /// Defaults to null — production behavior is unchanged.
  final VerifyRecoveryCodeCubit? cubit;

  /// Resolves the repository: explicit override → DI (when configured) →
  /// no-op fallback. The fallback mirrors `ClientOffersScreen._resolveRepository`
  /// so the route-resolution smoke test (which does NOT call
  /// `configureDependencies()`) can mount this screen without throwing.
  AuthRepository _resolveRepository() {
    final explicit = authRepository;
    if (explicit != null) return explicit;
    if (sl.isRegistered<AuthRepository>()) return sl<AuthRepository>();
    return const _UnconfiguredAuthRepository();
  }

  /// Reads the recovery email from the route `extra` (a `String`). Returns `''`
  /// when there is no GoRouter in scope (direct mount) or no payload (cold
  /// deep-link) — the screen still renders all Semantics nodes.
  static String _emailFromRoute(BuildContext context) {
    final extra = GoRouterState.of(context).extra;
    return extra is String ? extra : '';
  }

  @override
  Widget build(BuildContext context) {
    // Contract with the recover screen (JM-020): it navigates to
    // `/recover/verify` with `extra` = the recovery email (String). Defensive
    // cast — a cold deep-link has no extra, in which case we degrade to an
    // empty email (the verify call then surfaces `verify_code_error`, never a
    // crash; 40_GUARDRAILS_ARCH §5.3). The `extra` lookup is skipped when the
    // email is injected directly (tests) so the screen can be mounted without a
    // GoRouter in scope.
    final provided = cubit;
    if (provided != null) {
      return BlocProvider<VerifyRecoveryCodeCubit>.value(
        value: provided,
        child: const _VerifyRecoveryCodeView(),
      );
    }
    final resolvedEmail = email ?? _emailFromRoute(context);
    final repo = _resolveRepository();

    return BlocProvider<VerifyRecoveryCodeCubit>(
      create: (_) => VerifyRecoveryCodeCubit(
        authRepository: repo,
        email: resolvedEmail,
      ),
      child: const _VerifyRecoveryCodeView(),
    );
  }
}

class _VerifyRecoveryCodeView extends StatelessWidget {
  const _VerifyRecoveryCodeView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocConsumer<VerifyRecoveryCodeCubit, VerifyRecoveryCodeState>(
      listenWhen: (prev, curr) => prev.isVerified != curr.isVerified,
      listener: (context, state) {
        if (!state.isVerified) return;
        // JM-021 AC1 → JM-022: route to set-password in recovery mode. The
        // set-password route builder reads `?mode=`; we also pass `email` +
        // `resetToken` as query params (and `extra`) so JM-022's screen can
        // complete `POST /v1/auth/set-password` (which needs both). RECORDED
        // CONTRACT for JM-022: read `email` + `resetToken` from
        // `state.uri.queryParameters` (or `extra`, a Map).
        final uri = Uri(
          path: '/set-password',
          queryParameters: <String, String>{
            'mode': 'recovery',
            'email': state.email,
            'resetToken': state.resetToken!,
          },
        );
        context.go(
          uri.toString(),
          extra: <String, String>{
            'email': state.email,
            'resetToken': state.resetToken!,
          },
        );
      },
      builder: (context, state) {
        final cubit = context.read<VerifyRecoveryCodeCubit>();
        return Semantics(
          identifier: 'verify_code_root',
          container: true,
          explicitChildNodes: true,
          child: Scaffold(
            appBar: OMDSAppBar(
              title: l10n.verifyCodeTitle,
              centerTitle: false,
              showBackButton: true,
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Spacing.medium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.verifyCodeTitle,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: Spacing.xSmall),
                    Text(
                      // Email-based copy — never references a phone number.
                      l10n.verifyCodeSubtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: Spacing.large),
                    Semantics(
                      // Container id kept for back-compat (assertions/visibility).
                      identifier: 'verify_code_input',
                      container: true,
                      child: Center(
                        child: OmdsOtpInput(
                          // Re-key on each RESEND so a fresh code clears the
                          // entered digits. Keyed on the resend counter (NOT
                          // `code.isEmpty`) so the widget is NOT rebuilt — and
                          // its cells wiped — the instant the first digit is
                          // typed (RC-7: code goes empty→non-empty on digit 1).
                          key: ValueKey<int>(state.resendGeneration),
                          length: state.codeLength,
                          hasError: state.error != null,
                          // RC-7: per-cell ids verify_code_input_0..N-1 so a UI
                          // test driver can type one digit into each box (a
                          // single inputText on the container does not
                          // distribute across the N TextFields).
                          identifier: 'verify_code_input',
                          onChanged: cubit.codeChanged,
                          onCompleted: (code) {
                            cubit.codeChanged(code);
                            cubit.submit();
                          },
                        ),
                      ),
                    ),
                    if (state.error != null) ...[
                      const SizedBox(height: Spacing.small),
                      Semantics(
                        identifier: 'verify_code_error',
                        liveRegion: true,
                        child: Text(
                          l10n.verifyCodeError,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ),
                    ],
                    const SizedBox(height: Spacing.large),
                    Semantics(
                      identifier: 'verify_code_submit_cta',
                      button: true,
                      child: OmdsPrimaryButton(
                        text: l10n.verifyCodeSubmitCta,
                        isEnabled: state.isComplete && !state.isSubmitting,
                        onTap: cubit.submit,
                      ),
                    ),
                    const SizedBox(height: Spacing.medium),
                    Semantics(
                      identifier: 'verify_code_resend_cta',
                      button: true,
                      child: OmdsPrimaryButton(
                        text: l10n.verifyCodeResendCta,
                        variant: OmdsButtonVariant.text,
                        isEnabled: !state.isResending,
                        onTap: cubit.resend,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// DI-absent fallback (route-resolution smoke test only). Every leg reports a
/// failure so the screen surfaces `verify_code_error` rather than crashing or
/// silently "succeeding" if a code is ever submitted without configured DI.
/// Production always resolves the real [DioAuthRepository] from `sl<>()`.
class _UnconfiguredAuthRepository implements AuthRepository {
  const _UnconfiguredAuthRepository();

  @override
  Future<AuthSession> signup({
    required String email,
    required String password,
    String? name,
  }) =>
      throw const AuthRepositoryException(AuthFailure.unknown);

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) =>
      throw const AuthRepositoryException(AuthFailure.unknown);

  @override
  Future<RecoveryRequestResult> requestRecovery({required String email}) =>
      throw const AuthRepositoryException(AuthFailure.unknown);

  @override
  Future<RecoveryVerifyResult> verifyRecovery({
    required String email,
    required String code,
  }) =>
      throw const AuthRepositoryException(AuthFailure.unknown);

  @override
  Future<AuthSession> setPassword({
    required String email,
    required String password,
    String? resetToken,
  }) =>
      throw const AuthRepositoryException(AuthFailure.unknown);
}
