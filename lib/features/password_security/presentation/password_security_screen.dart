import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/layout/bottom_inset.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../application/password_security_cubit.dart';
import '../application/password_security_state.dart';

/// password-security (JM-061, MIDNIGHT M3-26). Reached from the customer
/// profile's `customer_profile_password_row`
/// (`customer_profile_screen.dart:154` → `pushNamed('password-security')`).
///
/// WHAT THIS SCREEN ACTUALLY MANAGES — it is two halves, and only one works:
///  * The change-password form is LOCAL VALIDATION ONLY. [PasswordSecurityCubit]
///    holds no repository; a valid submit emits `unavailable` and shows the
///    honest "not available yet" notice (B-33). There is no change-password
///    endpoint anywhere in the app.
///  * `password_set_entry` → `/set-password?mode=in-app-social` IS live and
///    writes: JM-022 owns `POST /v1/auth/set-password` via
///    `DioAuthRepository.setPassword`. The router kept `/set-password` through
///    JEBV4-199 precisely for this authenticated path.
///
/// So post-JEBV4-199 (phone-OTP + social sign-in only) the screen's real job is
/// ADDING a password to an OTP/social account, not changing an existing one.
/// See [hasPassword] for why the dead half still renders by default.
///
/// MIDNIGHT: nearest tile is R22 settings (already shipped at M2-19) — same
/// settings family, same in-body top bar, reached from the same profile chain.
/// Carried over: `content` field with the orange glow at `topEnd` and NO
/// periwinkle wash (R22 declares none), transparent scaffold, the 24px gutter,
/// `scrollBodyBottomInset`, and R22's band rhythm — `JeebSectionLabel` + 8 over
/// each control group, 20 between bands. R22 is board-still, so nothing here
/// animates.
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
  /// change-password form; `false` (social-only, D90) → only
  /// `password_set_entry` shows.
  ///
  /// STILL DEFAULTS TRUE, and that is now questionable: the `account_type` seam
  /// this was meant to read never landed, and JEBV4-199 removed the only funnel
  /// that could set a password, so nearly every live account is in fact
  /// `false`. Flipping the default is a product call (it would also unmount
  /// five frozen ids from the default render), so M3-26 restyled both halves
  /// and raised it instead. See 50_ROUTE_REQUESTS.md JM-061.
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

  /// B-33: the form validated but there is no change-password endpoint to call,
  /// so we surface an honest "not available yet" notice and STAY on screen.
  void _onUnavailable(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showOmdsSnackbar(context, message: l10n.passwordChangeUnavailable);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'password_security_root',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: JeebMidnightField(
          variant: JeebFieldVariant.content,
          // R22's only radial, and it declares no periwinkle wash.
          glowPlacement: JeebFieldGlowPlacement.topEnd,
          animateDecor: false,
          child: SafeArea(
            // The list reserves the nav-bar inset itself (R22).
            bottom: false,
            child: Column(
              children: [
                // In-body top bar, kept OUTSIDE the consumer so the header
                // renders identically in every phase (R22 / escalate shape).
                JeebTopBar.back(
                  title: l10n.passwordSecurityTitle,
                  identifier: 'password_back',
                  // EDGE: password_back → customer-profile (JM-061 AC).
                  onLeadingPressed: () => context.canPop()
                      ? context.pop()
                      : context.goNamed('customer-profile'),
                ),
                Expanded(
                  child:
                      BlocConsumer<PasswordSecurityCubit, PasswordSecurityState>(
                    listenWhen: (p, n) =>
                        p.status != n.status &&
                        n.status == PasswordSecurityStatus.unavailable,
                    listener: (context, state) => _onUnavailable(context),
                    builder: (context, state) => _body(context, l10n, state),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l10n,
    PasswordSecurityState state,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final submitting = state.status == PasswordSecurityStatus.submitting;
    return ListView(
      padding: EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        Spacing.medium,
        Spacing.xLarge,
        Spacing.xLarge + context.scrollBodyBottomInset,
      ),
      children: [
        Text(
          l10n.passwordSecurityBody,
          // `onSurfaceVariant` IS the Midnight muted-ink role (#8A93D8).
          style: context.jeebText.body.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),

        // ---- Change-password form (password accounts) ----
        if (widget.hasPassword) ...[
          const SizedBox(height: Spacing.large),
          JeebSectionLabel(l10n.settingsSecuritySection),
          const SizedBox(height: Spacing.xSmall),
          Semantics(
            identifier: 'password_current_field',
            textField: true,
            child: OmdsTextField(
              controller: _currentController,
              // Reuses the login password label/hint; dedicated
              // `passwordCurrent*` keys requested in 50_ROUTE_REQUESTS.md.
              labelText: l10n.loginPasswordLabel,
              hintText: l10n.loginPasswordHint,
              obscureText: state.currentObscured,
              autoValidate: false,
              enabled: !submitting,
              textInputAction: TextInputAction.next,
              onChanged: (_) =>
                  context.read<PasswordSecurityCubit>().acknowledgeError(),
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
              onChanged: (_) =>
                  context.read<PasswordSecurityCubit>().acknowledgeError(),
              suffixIcon: _RevealToggle(
                identifier: 'password_new_visibility_toggle',
                obscured: state.newObscured,
                onPressed:
                    context.read<PasswordSecurityCubit>().toggleNewObscured,
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
              onChanged: (_) =>
                  context.read<PasswordSecurityCubit>().acknowledgeError(),
              onSubmitted: (_) => _onSubmit(),
              suffixIcon: _RevealToggle(
                identifier: 'password_confirm_visibility_toggle',
                obscured: state.confirmObscured,
                onPressed:
                    context.read<PasswordSecurityCubit>().toggleConfirmObscured,
              ),
            ),
          ),
          // The two guards are mutually exclusive (the policy returns one
          // verdict), so at most one note renders.
          if (state.hasStrengthError) ...[
            const SizedBox(height: Spacing.small),
            Semantics(
              identifier: 'password_strength_error',
              liveRegion: true,
              child: JeebInfoNote.error(
                icon: Icons.error_outline,
                text: l10n.setpwValidationError,
              ),
            ),
          ],
          if (state.hasMismatchError) ...[
            const SizedBox(height: Spacing.small),
            Semantics(
              identifier: 'password_mismatch_error',
              liveRegion: true,
              child: JeebInfoNote.error(
                icon: Icons.error_outline,
                text: l10n.setpwValidationError,
              ),
            ),
          ],
          const SizedBox(height: Spacing.large),
          Semantics(
            identifier: 'password_submit_cta',
            button: true,
            child: JeebCtaButton.primary(
              label: l10n.setpwSubmitCta,
              isEnabled: !submitting,
              isLoading: submitting,
              onTap: _onSubmit,
            ),
          ),
        ],

        // ---- Social "Set a password" entry (D90) ----
        // The live half. Banded under its own label so it reads as a separate
        // act, not a second button belonging to the form above.
        const SizedBox(height: Spacing.large),
        JeebSectionLabel(l10n.settingsAccountSection),
        const SizedBox(height: Spacing.xSmall),
        Semantics(
          identifier: 'password_set_entry',
          button: true,
          container: true,
          child: JeebCtaButton(
            label: l10n.passwordSetEntryCta,
            // Glass when it is the secondary act, periwinkle when it is the
            // only one. Never accent: R22 spends its orange on one lit frame.
            variant: widget.hasPassword
                ? JeebCtaVariant.outline
                : JeebCtaVariant.primary,
            // EDGE: password_set_entry → auth-set-password
            // (?mode=in-app-social, D90). Pushed, so back returns here.
            onTap: () => context.pushNamed(
              'set-password',
              queryParameters: const <String, String>{'mode': 'in-app-social'},
            ),
          ),
        ),
      ],
    );
  }
}

/// The obscure/reveal eye on a password field.
///
/// Inked `onSurfaceVariant` on purpose: it is a field affordance, not an act,
/// so it takes the muted role rather than heading ink.
class _RevealToggle extends StatelessWidget {
  const _RevealToggle({
    required this.identifier,
    required this.obscured,
    required this.onPressed,
  });

  final String identifier;
  final bool obscured;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: identifier,
      button: true,
      child: IconButton(
        icon: Icon(obscured ? Icons.visibility : Icons.visibility_off),
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        onPressed: onPressed,
      ),
    );
  }
}
