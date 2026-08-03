import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/network/auth_token_store.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../application/set_password_cubit.dart';
import '../application/set_password_state.dart';
import '../data/dio_auth_repository.dart';
import '../domain/auth_repository.dart';

/// The exit of the set-password screen (JM-061 password-security, D90).
///   * [inAppSocial] — reached from password-security for a social-only account;
///                     on success → customer-profile.
///
/// The former `recovery` mode (reached from the hidden email/password recovery
/// funnel) was removed with that funnel (JEBV4-199, Q-044): the only end-user
/// auth surfaces are phone-OTP + Apple/Google social, so there is no email
/// recovery flow to land here anymore. This screen now serves ONLY the
/// authenticated password-security settings path.
enum SetPasswordMode {
  inAppSocial;

  /// Parses the `?mode=` query param. Always resolves to [inAppSocial] — the
  /// single surviving mode — regardless of the (now legacy) value (R-F).
  static SetPasswordMode fromQuery(String? value) => SetPasswordMode.inAppSocial;
}

/// `auth-set-password` (JM-022, JM-061). In-app-social set-password screen
/// (`?mode=in-app-social`, D90). New + confirm password fields with
/// strength/mismatch validation and per-field eye toggles.
///
/// Data flows through [AuthRepository.setPassword] → `POST /v1/auth/set-password`
/// (the VERIFIED W-1 FLOOR contract, 42_GUARDRAILS_MOCK). On success it lands on
/// customer-profile (`customer-profile` route, customer_profile_wallet_chip)
/// [D90, JM-035].
///
/// Reached ONLY from password-security (a social-only account adding a password
/// from settings). The former recovery entry (email/password recovery funnel)
/// was removed in JEBV4-199; `email`/`resetToken` stay as optional inputs the
/// authenticated caller may forward but are not required in-app-social.
///
/// redesign-2026-08: re-skinned onto the Jeeb system so it reads as one product
/// with its caller (`password_security_screen.dart`) and its settings-family
/// sibling (`profile_edit_screen.dart`). Bands, top to bottom: in-body
/// [JeebTopBar] → the two password fields at 24px gutters → the validation
/// note → a real empty band → the docked [JeebCtaFooter] Save pill. The flow,
/// the copy, the cubit calls and every `Semantics(identifier:)` are unchanged.
class SetPasswordScreen extends StatelessWidget {
  const SetPasswordScreen({
    super.key,
    this.mode = SetPasswordMode.inAppSocial,
    this.email = '',
    this.resetToken,
    this.cubitFactory,
  });

  final SetPasswordMode mode;

  /// The account email the password is being set for. Carried from the
  /// recovery verify step (JM-021); empty for the seam capture path.
  final String email;

  /// The recovery reset token (recovery mode). Optional for in-app-social.
  final String? resetToken;

  /// Test seam: overrides the DI-backed cubit construction
  /// (40_GUARDRAILS_ARCH §5.4).
  final SetPasswordCubit Function()? cubitFactory;

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
    return BlocProvider<SetPasswordCubit>(
      create: (_) =>
          cubitFactory?.call() ??
          SetPasswordCubit(
            repository: _resolveAuthRepository(),
            email: email,
            resetToken: resetToken,
          ),
      child: _SetPasswordView(mode: mode),
    );
  }
}

class _SetPasswordView extends StatefulWidget {
  const _SetPasswordView({required this.mode});

  final SetPasswordMode mode;

  @override
  State<_SetPasswordView> createState() => _SetPasswordViewState();
}

class _SetPasswordViewState extends State<_SetPasswordView> {
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  @override
  void dispose() {
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _onSubmit() {
    context.read<SetPasswordCubit>().submit(
          newPassword: _newController.text,
          confirmPassword: _confirmController.text,
        );
  }

  /// Routes off the screen on a successful set-password. Runs only in the
  /// `listener` (never the builder), gated by the succeeded edge.
  void _onSucceeded(BuildContext context) {
    // EDGE: set-password (in-app-social) → customer-profile
    // (60_W0_TEST_PLAN nav matrix, JM-022 → JM-035, D90). This is the only
    // surviving exit now that the email recovery funnel is gone (JEBV4-199).
    context.goNamed('customer-profile');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'setpw_root',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        // The header is an in-body [JeebTopBar] row, not a Material app bar
        // (§5 #1) — the same swap password-security and profile-edit made.
        body: BlocConsumer<SetPasswordCubit, SetPasswordState>(
          listenWhen: (p, n) =>
              p.status != n.status && n.status == SetPasswordStatus.succeeded,
          listener: (context, state) => _onSucceeded(context),
          builder: (context, state) {
            final cubit = context.read<SetPasswordCubit>();
            final submitting = state.status == SetPasswordStatus.submitting;
            return SafeArea(
              // The docked footer owns the bottom inset, so the scroll body
              // must not claim it (same split as profile_edit_screen.dart).
              bottom: false,
              child: Column(
                children: [
                  // Back is still the guarded `Navigator.maybePop()` the
                  // OMDSAppBar back button called — the kit's default
                  // `onLeadingPressed` is that same call, so the route's
                  // `backFallbacks['set-password']` wrapper is untouched.
                  JeebTopBar.back(
                    title: l10n.setpwTitle,
                    identifier: 'setpw_back',
                  ),
                  Expanded(
                    child: ListView(
                      // 24px side gutters (§4.3), shared with every redesigned
                      // settings-family screen; the band below the last field
                      // stays white — the CTA is docked, not last in the list.
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        Spacing.xLarge,
                        Spacing.medium,
                        Spacing.xLarge,
                        Spacing.large,
                      ),
                      children: [
                        // New password field + its eye toggle.
                        Semantics(
                          identifier: 'setpw_new_field',
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
                              identifier: 'setpw_new_visibility_toggle',
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
                        // Confirm password field + its eye toggle.
                        Semantics(
                          identifier: 'setpw_confirm_field',
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
                              identifier: 'setpw_confirm_visibility_toggle',
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
                        // Validation / submit error node. Mismatch or weak
                        // password (AC3) and any server failure both surface
                        // here so QA has a single assertable id
                        // (60_W0_TEST_PLAN §2.11). Same soft `errorContainer`
                        // note the caller renders for its own guards — never
                        // the legacy red-slab body text.
                        if (state.hasError) ...[
                          const SizedBox(height: Spacing.small),
                          Semantics(
                            identifier: 'setpw_validation_error',
                            liveRegion: true,
                            child: JeebInfoNote.error(
                              icon: Icons.error,
                              text: l10n.setpwValidationError,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Primary submit CTA, docked over the empty band (§3).
                  SafeArea(
                    top: false,
                    child: JeebCtaFooter.single(
                      child: Semantics(
                        identifier: 'setpw_submit_cta',
                        button: true,
                        child: JeebCtaButton.primary(
                          label: l10n.setpwSubmitCta,
                          isEnabled: !submitting,
                          onTap: _onSubmit,
                        ),
                      ),
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
