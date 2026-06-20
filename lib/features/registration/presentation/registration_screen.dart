import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/dev_seam/dev_seam.dart';
import '../../../core/dev_seam/social_auth_seam.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/network/mock_gateway_client.dart';
import '../../../core/onboarding/onboarding_cubit.dart';
import '../../../core/session/session_cubit.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/social/social_auth_cubit.dart';
import '../../auth/social/social_auth_service.dart';
import '../../auth/social/social_auth_token_store.dart';
import '../../auth/social/social_sign_in_section.dart';
import '../application/registration_cubit.dart';
import '../application/registration_state.dart';
import '../domain/lebanon_phone.dart';
import '../domain/otp_service.dart';
import '../domain/registration_attempt_policy.dart';
import 'otp_verification_screen.dart';
import 'super_login/super_login_picker.dart';
import 'super_login/super_login_sheet.dart';

/// Entry point for the phone+OTP registration flow (T-mobile-002).
///
/// Routed via `/register` (see `lib/core/router/app_router.dart`). Hosts the
/// [RegistrationCubit] and renders the phone-entry view. The OTP view is
/// pushed onto the navigation stack with the same cubit instance scoped via
/// [BlocProvider.value] so countdown and attempt state survives the
/// transition.
class RegistrationScreen extends StatelessWidget {
  const RegistrationScreen({
    super.key,
    this.cubit,
    this.socialAuthCubit,
    this.onVerified,
    this.onSocialAuthenticated,
  });

  /// Optional injected cubit. Tests pass a pre-wired one; production
  /// instantiates a default with the dev [FakeOtpService] (until the real
  /// auth-service client lands).
  final RegistrationCubit? cubit;

  /// Optional injected social auth cubit. Tests inject one with a fake
  /// [SocialAuthService]; production wires the real Dio-backed
  /// [DefaultSocialAuthService] + secure token store.
  final SocialAuthCubit? socialAuthCubit;

  /// Called when the cubit reports a verified phone. Defaults to
  /// `context.go('/')` (home) in production; tests inject their own
  /// callback so the screen doesn't need a full GoRouter in scope.
  final VoidCallback? onVerified;

  /// Called when a social sign-in completes successfully. Defaults to the
  /// same handler as [onVerified] — first-time users will land in the
  /// link-phone follow-up once that ticket lands (JEEB-58).
  final VoidCallback? onSocialAuthenticated;

  @override
  Widget build(BuildContext context) {
    final view = _RegistrationView(
      onVerified: onVerified,
      onSocialAuthenticated: onSocialAuthenticated,
    );

    Widget withRegistration(Widget child) {
      if (cubit != null) {
        return BlocProvider<RegistrationCubit>.value(value: cubit!, child: child);
      }
      return BlocProvider<RegistrationCubit>(
        create: (_) => RegistrationCubit(
          otpService: sl<OtpService>(),
          // DEBUG-ONLY (62_SEAM_HARNESS.md): `jeeb.seam.otp_countdown_expired`
          // zeroes the app-driven resend cooldown so `phone_otp_resend_cta` is
          // immediately tappable (JM-009 AC2) without the flow waiting out the
          // real 60 s timer. kDebugMode-gated + DevSeam is empty in release, so
          // production always uses the default 60 s policy.
          policy: _otpResendPolicy(),
        ),
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

    return withRegistration(withSocial(view));
  }
}

/// DEBUG-ONLY resend policy for the phone-OTP flow (62_SEAM_HARNESS.md, JM-009).
///
/// Returns a zero-cooldown [RegistrationAttemptPolicy] when the
/// `jeeb.seam.otp_countdown_expired` seam is set, so `phone_otp_resend_cta` is
/// tappable on the first frame (the resend countdown is app-driven by
/// [RegistrationCubit] off `policy.resendCooldown`). Everything else (max
/// attempts, lockout duration) keeps the production default. In release —
/// where [DevSeam.current] is always empty and `kDebugMode` is false — this
/// always returns the default `const RegistrationAttemptPolicy()`.
RegistrationAttemptPolicy _otpResendPolicy() {
  if (kDebugMode && DevSeam.current.otpCountdownExpired) {
    return const RegistrationAttemptPolicy(resendCooldown: Duration.zero);
  }
  return const RegistrationAttemptPolicy();
}

class _RegistrationView extends StatefulWidget {
  const _RegistrationView({this.onVerified, this.onSocialAuthenticated});

  final VoidCallback? onVerified;
  final VoidCallback? onSocialAuthenticated;

  @override
  State<_RegistrationView> createState() => _RegistrationViewState();
}

class _RegistrationViewState extends State<_RegistrationView> {
  late final TextEditingController _phoneController;
  bool _pushedOtp = false;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(
      text: context.read<RegistrationCubit>().state.phoneInput,
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  /// Re-seeds the phone field from cubit state. ONLY called on a step
  /// transition (e.g. returning from the OTP step via "change number"), never
  /// on a per-keystroke `phoneInput` change.
  ///
  /// DEFECT (Maestro real-backend P0): the previous build mirrored the cubit's
  /// *normalised* `phoneInput` back into the controller on every keystroke. The
  /// field is the source of truth while the user types, so that mirror-back
  /// fought live editing: typing a 9th digit made `normalise` front-truncate to
  /// the first 8 and overwrite the field, so erasing the (now wrong) trailing
  /// digit dropped a valid one — the field stuck below 8 digits, `tryParse`
  /// returned null, and `sendCode()` bailed at its guard, so no OTP was ever
  /// requested (on-device login impossible). We now only re-seed on a genuine,
  /// non-typing state change, and only when the text actually differs — the
  /// equality guard preserves the user's live cursor/selection otherwise.
  void _syncControllerText(String value) {
    if (_phoneController.text == value) return;
    _phoneController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  Future<void> _openOtpRoute() async {
    if (_pushedOtp || !mounted) return;
    _pushedOtp = true;
    final cubit = context.read<RegistrationCubit>();
    final onVerified = widget.onVerified;
    await Navigator.of(context).push(
      OmdsSlideRoute<void>(
        page: BlocProvider<RegistrationCubit>.value(
          value: cubit,
          child: OtpVerificationScreen(onVerified: onVerified),
        ),
      ),
    );
    _pushedOtp = false;
  }

  Future<void> _navigateHome() async {
    final onVerified = widget.onVerified;
    if (onVerified != null) {
      // Test seam: caller controls navigation; no OnboardingCubit required.
      onVerified();
      return;
    }
    // Production path: persist completion flag so the router lets the user
    // through to the shell. The super-login dev seam manages this separately.
    if (!mounted) return;
    await context.read<OnboardingCubit>().complete();
    if (!mounted) return;
    // FR-P0-3 (defect DEF-1): re-evaluate the session BEFORE navigating so the
    // router's first-run gate sees the freshly-persisted token and lets `/`
    // resolve to Home instead of bouncing back to `/register`.
    // ignore: use_build_context_synchronously
    await _refreshSession(context);
    if (!mounted) return;
    // ignore: use_build_context_synchronously
    context.go('/');
  }

  /// Re-reads the session keystore via the production [SessionCubit] (when one
  /// is in scope) so the router redirect promotes the user to Home. Reads it as
  /// a nullable type: under widget tests that mount the screen without the app
  /// shell there is no [SessionCubit] provider, so this is a no-op there.
  static Future<void> _refreshSession(BuildContext context) async {
    final session = context.read<SessionCubit?>();
    if (session != null) await session.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocConsumer<RegistrationCubit, RegistrationState>(
      // Listen on `step` ONLY. We deliberately do NOT listen on `phoneInput`:
      // the text field owns its own text while the user types, and re-seeding it
      // from the cubit's normalised value on every keystroke corrupted live
      // editing (Maestro real-backend P0 — see `_syncControllerText`). We still
      // re-seed the controller on a step transition so the field shows the right
      // digits when the user returns from the OTP step ("change number").
      listenWhen: (prev, curr) => prev.step != curr.step,
      listener: (context, state) async {
        _syncControllerText(state.phoneInput);
        if (state.step == RegistrationStep.otp && !_pushedOtp) {
          _openOtpRoute();
        }
        if (state.step == RegistrationStep.verified) {
          // Verified — persist onboarding completion and land on home.
          await _navigateHome();
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: OMDSAppBar(
            title: l10n.registrationPhoneTitle,
            centerTitle: false,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Spacing.medium),
              child: _PhoneEntryBody(
                state: state,
                phoneController: _phoneController,
                onSocialAuthenticated: () => _onSocialAuthenticated(context),
                onSuperLogin: () => _openSuperLogin(context),
                onSuperLoginPlus: () => _openSuperLoginPlus(context),
              ),
            ),
          ),
        );
      },
    );
  }

  void _onSocialAuthenticated(BuildContext context) {
    final cb = widget.onSocialAuthenticated ?? widget.onVerified;
    if (cb != null) {
      cb();
    } else {
      context.go('/');
    }
  }

  /// Opens the FR-P0-4 credential sheet. On a server-validated success the
  /// sheet pops `true`; we then mark onboarding complete and land on home —
  /// using the **real** tokens the sheet persisted, never a client mint.
  Future<void> _openSuperLogin(BuildContext context) async {
    final signedIn = await showSuperLoginSheet(context);
    if (signedIn != true || !context.mounted) return;
    await context.read<OnboardingCubit>().complete();
    if (!context.mounted) return;
    final onVerified = widget.onVerified;
    if (onVerified != null) {
      onVerified();
      return;
    }
    // FR-P0-3 (defect DEF-1): the sheet persisted the real tokens, but the
    // router's session gate still reads `unauthenticated` until the SessionCubit
    // re-reads the keystore. Refresh it FIRST so `context.go('/')` lands on Home
    // immediately (previously the redirect bounced back to `/register` and Home
    // only appeared after a relaunch).
    await _refreshSession(context);
    if (!context.mounted) return;
    context.go('/');
  }

  /// "Super user login plus": first opens the demo-user picker, then opens the
  /// SAME credential sheet pre-filled with the chosen user's userId + passcode.
  /// The user still taps "Sign in" → the sheet POSTs to the gateway for real
  /// server-side validation, then the post-success path is identical to
  /// [_openSuperLogin] (onboarding complete → session refresh → home).
  Future<void> _openSuperLoginPlus(BuildContext context) async {
    final user = await showSuperLoginPicker(context);
    if (user == null || !context.mounted) return;
    final signedIn = await showSuperLoginSheet(
      context,
      initialUserId: user.userId,
      initialPasscode: user.passcode,
    );
    if (signedIn != true || !context.mounted) return;
    await context.read<OnboardingCubit>().complete();
    if (!context.mounted) return;
    final onVerified = widget.onVerified;
    if (onVerified != null) {
      onVerified();
      return;
    }
    await _refreshSession(context);
    if (!context.mounted) return;
    context.go('/');
  }
}

/// The phone-entry composition: branded hero → welcome → social → "or"
/// divider → phone field → send-code CTA → (debug) super-login link. Mirrors
/// the Rahma/Salehly layout grouping while keeping Jeeb's phone+OTP + OMDS.
class _PhoneEntryBody extends StatelessWidget {
  const _PhoneEntryBody({
    required this.state,
    required this.phoneController,
    required this.onSocialAuthenticated,
    required this.onSuperLogin,
    required this.onSuperLoginPlus,
  });

  final RegistrationState state;
  final TextEditingController phoneController;
  final VoidCallback onSocialAuthenticated;
  final VoidCallback onSuperLogin;
  final VoidCallback onSuperLoginPlus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _RegisterHero(),
        const SizedBox(height: Spacing.large),
        const _WelcomeHeading(),
        const SizedBox(height: Spacing.large),
        SocialSignInSection(onAuthenticated: (_) => onSocialAuthenticated()),
        const SizedBox(height: Spacing.twoXLarge),
        _OrDivider(label: l10n.registrationSocialDivider),
        const SizedBox(height: Spacing.twoXLarge),
        _PhoneField(
          controller: phoneController,
          hintText: l10n.registrationPhoneHint,
          errorText: state.phoneError == null
              ? null
              : _phoneErrorCopy(state.phoneError!, l10n),
          enabled: !state.isSendingCode,
          onChanged: (raw) =>
              context.read<RegistrationCubit>().phoneChanged(raw),
        ),
        const SizedBox(height: Spacing.large),
        _SendCodeButton(state: state),
        // SECURITY: the super-login dev affordance is compiled out of release
        // builds (only mounted under `kDebugMode`). It opens a server-validated
        // credential sheet instead of the old gate-less `mock-jwt-*` mint
        // (FR-P0-4). Full removal is owner-gated (JEEB-PLAN.md §6, defect #2).
        if (kDebugMode) ...[
          const SizedBox(height: Spacing.twoXLarge),
          _SuperLoginLink(onTap: onSuperLogin),
          const SizedBox(height: Spacing.medium),
          // "Super user login plus": opens a demo-user picker first, then the
          // SAME credential sheet pre-filled with the chosen user. Sits NEXT TO
          // the original link; both share the debug-only gate.
          _SuperLoginPlusLink(onTap: onSuperLoginPlus),
        ],
      ],
    );
  }
}

/// Phone send-code CTA — upgraded to [OmdsLoadingButton] for an in-button
/// spinner (Rahma/Salehly parity) over the old label-swap.
class _SendCodeButton extends StatelessWidget {
  const _SendCodeButton({required this.state});

  final RegistrationState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OmdsLoadingButton(
      key: const Key('registration.sendCode'),
      text: l10n.registrationSendCode,
      isLoading: state.isSendingCode,
      isEnabled: state.isPhoneReady && !state.isSendingCode,
      onTap: () => context.read<RegistrationCubit>().sendCode(),
    );
  }
}

/// Branded wordmark hero band (DESIGN-FIRST-RUN §2c / §3.2 #3). Reuses the
/// splash wordmark on the brand-navy field — token-clean, swappable for the
/// Figma hero asset once the node id is captured (FR-P1-3 [FIGMA-BLOCKER]).
class _RegisterHero extends StatelessWidget {
  const _RegisterHero();

  static const String _logoAsset = 'assets/brand/jeeb_logo.svg';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: '_register_hero',
      container: true,
      child: Container(
        height: Sizes.tenXLarge,
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: OmdsBorderRadius.large,
        ),
        alignment: Alignment.center,
        child: Semantics(
          identifier: '_register_hero_logo',
          label: l10n.splashLogoSemantic,
          image: true,
          // Height-constrained so the wordmark scales to the band; width
          // derives from the SVG's intrinsic 182:73 ratio (no distortion).
          child: SvgPicture.asset(
            _logoAsset,
            height: Sizes.fiveXLarge,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

/// "Welcome to Jeeb" heading + the existing phone-step subtitle, promoted
/// above the form to match the Salehly/Rahma welcome stack.
class _WelcomeHeading extends StatelessWidget {
  const _WelcomeHeading();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.registrationWelcome,
          key: const Key('registration.welcome'),
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: Spacing.xSmall),
        Text(
          l10n.registrationPhoneSubtitle,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// "social — or — phone" divider (DESIGN-FIRST-RUN §2c). Themed [Divider]s
/// (a structural primitive; OMDS ships no divider widget) around the label.
class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      key: const Key('registration.orDivider'),
      children: [
        Expanded(child: Divider(color: colorScheme.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.medium),
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ),
        Expanded(child: Divider(color: colorScheme.outlineVariant)),
      ],
    );
  }
}

/// Debug-only "Super User Login" text link that opens the credential sheet.
class _SuperLoginLink extends StatelessWidget {
  const _SuperLoginLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Semantics(
        identifier: '_super_login_link',
        button: true,
        label: l10n.superLoginTitle,
        child: GestureDetector(
          key: const Key('registration.superLogin'),
          onTap: onTap,
          child: Text(
            l10n.superLoginTitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary
                      .withValues(alpha: UIConstants.opacityMedium),
                  decoration: TextDecoration.underline,
                ),
          ),
        ),
      ),
    );
  }
}

/// Debug-only "Super user login plus" text link. Opens a demo-user picker that
/// pre-fills the credential sheet. Rendered next to [_SuperLoginLink]; the
/// existing direct-sheet link is kept unchanged.
class _SuperLoginPlusLink extends StatelessWidget {
  const _SuperLoginPlusLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Semantics(
        identifier: 'super_login_plus_button',
        button: true,
        label: l10n.superLoginPlusTitle,
        child: GestureDetector(
          key: const Key('registration.superLoginPlus'),
          onTap: onTap,
          child: Text(
            l10n.superLoginPlusTitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary
                      .withValues(alpha: UIConstants.opacityMedium),
                  decoration: TextDecoration.underline,
                ),
          ),
        ),
      ),
    );
  }
}

/// Phone-number text field with the Lebanese +961 prefix permanently
/// pinned to the left. The TextField only ever receives the 8 national
/// digits; the prefix is decorative.
///
/// EXEMPT(flutter-omds-design-system-usage): raw [TextField] retained.
/// - [OmdsPhoneInput] ships a country-picker UX; the product spec calls
///   for a fixed +961 with no picker (JEEB-55).
/// - [OmdsTextField] does not expose `prefixIconConstraints`, so a tight
///   inline "+961" glyph would inflate to the default 48dp prefix gutter
///   and break the digit-alignment design.
/// All styling still flows through the OMDS theme: `fillColor`,
/// `border`, `contentPadding`, and typography pull from
/// `colorScheme.surfaceContainerHighest`, [OmdsBorderRadius.medium], and
/// [Spacing]. Promotion to OMDS tracked under JEEB-57.
class _PhoneField extends StatelessWidget {
  const _PhoneField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.errorText,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return TextField(
      key: const Key('registration.phoneField'),
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.phone,
      // Keep digits, the `+` (for users who paste a `+961…` block), and
      // common separators (space, dash, parens). The cubit's `normalise`
      // strips everything except the trailing 8 national digits for
      // validation/sending; the field itself keeps what the user typed (we no
      // longer mirror the normalised form back per-keystroke — that corrupted
      // live editing, Maestro P0). No max-length here so a pasted +961 block
      // isn't truncated at the wrong end before `normalise` sees it.
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d+\s\-()]')),
      ],
      style: textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: hintText,
        errorText: errorText,
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.medium,
            vertical: Spacing.small,
          ),
          child: Text(
            LebanonPhone.dialCode,
            key: const Key('registration.phonePrefix'),
            style: textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        border: const OutlineInputBorder(
          borderRadius: OmdsBorderRadius.medium,
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.medium,
          vertical: Spacing.small,
        ),
      ),
      onChanged: onChanged,
    );
  }
}

String _phoneErrorCopy(RegistrationPhoneError error, AppLocalizations l10n) {
  switch (error) {
    case RegistrationPhoneError.invalid:
      return l10n.registrationPhoneInvalid;
    case RegistrationPhoneError.networkError:
    case RegistrationPhoneError.rateLimited:
      // The ARB file ships an invalid-only copy today; reuse it for these
      // adjacent errors to avoid surfacing an English fallback to RTL
      // users until product copies the strings (tracked under JEEB-56).
      return l10n.registrationPhoneInvalid;
  }
}
