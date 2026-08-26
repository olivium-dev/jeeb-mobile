import 'dart:async';

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
import '../../../core/onboarding/onboarding_cubit.dart';
import '../../../core/session/session_cubit.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/jeeb_color_roles.dart';
import '../../../core/theme/jeeb_radii.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/social/social_auth_cubit.dart';
import '../../auth/social/social_auth_service.dart';
import '../../auth/social/social_auth_token_store.dart';
import '../../auth/social/social_sign_in_section.dart';
import '../../profile_name/presentation/display_name_setup_screen.dart';
import '../application/registration_cubit.dart';
import '../application/registration_state.dart';
import '../domain/international_phone.dart';
import '../domain/otp_service.dart';
import '../domain/registration_attempt_policy.dart';
import 'otp_verification_screen.dart';
import 'registration_country_options.dart';

/// Board gap from the wordmark block down to the "PHONE NUMBER" label (36).
const double _kWelcomeToFormGap = 36;

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
        return BlocProvider<RegistrationCubit>.value(
          value: cubit!,
          child: child,
        );
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
            dio: resolveGatewayDio(),
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
  bool _pushedNameStep = false;

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
          // Production (null [onVerified]): pass a NO-OP so this HOST owns the
          // whole post-verify continuation (display-name step → _navigateHome)
          // instead of the OTP screen's default `context.go('/')` racing it and
          // tearing the stack down before the name step can show. Tests that
          // inject their own callback keep the previous contract untouched.
          child: OtpVerificationScreen(onVerified: onVerified ?? () {}),
        ),
      ),
    );
    _pushedOtp = false;
  }

  /// Post-OTP display-name step (profile-name onboarding): asks for a friendly
  /// display name and PUTs it to `/api/User/profile` (`username`) so the
  /// gateway projection carries a real name instead of a synthetic handle.
  /// Optional-but-encouraged: the step always offers a skip exit and a failed
  /// save never blocks registration (fail-soft inside the screen). Production
  /// path ONLY — test seams that inject [_RegistrationView.onVerified] keep
  /// the verified → callback contract unchanged.
  Future<void> _openDisplayNameStep() async {
    if (_pushedNameStep || !mounted) return;
    _pushedNameStep = true;
    final navigator = Navigator.of(context);
    await navigator.push(
      OmdsSlideRoute<void>(
        page: DisplayNameSetupScreen(onDone: () => navigator.pop()),
      ),
    );
    _pushedNameStep = false;
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
    return BlocConsumer<RegistrationCubit, RegistrationState>(
      // Listen on `step` ONLY. We deliberately do NOT listen on `phoneInput`:
      // the text field owns its own text while the user types, and re-seeding it
      // from the cubit's normalised value on every keystroke corrupted live
      // editing (Maestro real-backend P0 — see `_syncControllerText`). We still
      // re-seed the controller on a step transition so the field shows the right
      // digits when the user returns from the OTP step ("change number").
      listenWhen: (prev, curr) =>
          prev.step != curr.step ||
          prev.selectedCountryCode != curr.selectedCountryCode,
      listener: (context, state) async {
        _syncControllerText(state.phoneInput);
        if (state.step == RegistrationStep.otp && !_pushedOtp) {
          _openOtpRoute();
        }
        if (state.step == RegistrationStep.verified) {
          // Verified — production path first offers the OPTIONAL display-name
          // step (skip-allowed; a failed save never blocks), then persists
          // onboarding completion and lands on home. Test seams (injected
          // onVerified) bypass the name step to preserve the prior contract.
          if (widget.onVerified == null) await _openDisplayNameStep();
          await _navigateHome();
        }
      },
      builder: (context, state) {
        return Semantics(
          identifier: 'registration_root',
          container: true,
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            // The field bleeds under BOTH bands: raw `.light` paints the
            // Android nav bar black instead of page navy.
            value: AppTheme.systemOverlayStyle,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              // MIDNIGHT R6: the welcome run sits straight on the field (the
              // tile draws no hero box) and the bloom is the ORANGE glow at the
              // top END — measured on the tile, not the periwinkle wash.
              body: JeebMidnightField(
                variant: JeebFieldVariant.content,
                // R6 declares .28 against the ratified single .24.
                glowColor: context.jeebRoles.accent.withValues(alpha: 0.28),
                glowPlacement: JeebFieldGlowPlacement.topEnd,
                animateDecor: false,
                // `column → content → flex:1 → docked note` (plan R1). The
                // LayoutBuilder/ConstrainedBox/IntrinsicHeight trio is what
                // makes the Spacer legal inside a scroll view: the sheet fills
                // the viewport when it fits and degrades to a real scroll when
                // the keyboard opens or text scales to 200%.
                child: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsetsDirectional.fromSTEB(
                                  Spacing.xLarge,
                                  Spacing.large,
                                  Spacing.xLarge,
                                  0,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const _WelcomeBlock(),
                                    const SizedBox(height: _kWelcomeToFormGap),
                                    _PhoneEntryBody(
                                      state: state,
                                      phoneController: _phoneController,
                                      onSocialAuthenticated: () =>
                                          unawaited(_onSocialAuthenticated()),
                                    ),
                                  ],
                                ),
                              ),
                              // Real emptiness (plan R1) — never fill it.
                              const Spacer(),
                              const _TrustNote(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _onSocialAuthenticated() async {
    final cb = widget.onSocialAuthenticated ?? widget.onVerified;
    if (cb != null) {
      cb();
    } else {
      await _navigateHome();
    }
  }
}

/// The phone-entry composition, phone-first per the redesign board: label →
/// field row → helper → CTA → "or" divider → a compact two-up social row.
///
/// NOTE: the debug-only super-login entry points were removed from this screen
/// with the email/password funnel (JEBV4-199, Q-044 RATIFIED). Phone-OTP plus
/// Apple/Google social is the whole of end-user auth.
class _PhoneEntryBody extends StatelessWidget {
  const _PhoneEntryBody({
    required this.state,
    required this.phoneController,
    required this.onSocialAuthenticated,
  });

  final RegistrationState state;
  final TextEditingController phoneController;
  final VoidCallback onSocialAuthenticated;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InternationalPhoneField(
          state: state,
          controller: phoneController,
          errorText: state.phoneError == null
              ? null
              : _phoneErrorCopy(state.phoneError!, l10n),
          enabled: !state.isSendingCode,
        ),
        const SizedBox(height: Spacing.medium),
        _SendCodeButton(state: state, phoneController: phoneController),
        const SizedBox(height: Spacing.xLarge),
        _OrDivider(label: l10n.registrationSocialDivider),
        const SizedBox(height: Spacing.medium),
        // Social is demoted below the phone funnel and laid out two-up
        // (Google at the start, Apple at the end) per the board.
        SocialSignInSection(
          axis: Axis.horizontal,
          onAuthenticated: (_) => onSocialAuthenticated(),
        ),
      ],
    );
  }
}

/// Phone send-code CTA — the board's ORANGE pill (h58, `ctaOrange` glow),
/// which is `JeebCtaButton.accent`. It keeps the in-button spinner.
class _SendCodeButton extends StatelessWidget {
  const _SendCodeButton({required this.state, required this.phoneController});

  final RegistrationState state;
  final TextEditingController phoneController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // BUG-1 (customer-spine blocker): the phone field — not the cubit — owns the
    // text while the user types (PR #45). Read the live controller text here and
    // hand it to `sendCode` so Send validates/sends the number actually rendered,
    // never a stale `state.phoneInput` that diverged and flipped the field red
    // while emitting zero OTP requests. Enablement also reads the live text so
    // the CTA can't be wrongly disabled when the controller leads the cubit.
    final renderedReady =
        InternationalPhone.tryParse(
          countryCode: state.selectedCountryCode,
          raw: phoneController.text,
        ) !=
        null;
    final canTap = renderedReady && !state.isSendingCode;
    return JeebCtaButton.accent(
      key: const Key('registration.sendCode'),
      identifier: 'register_phone_submit_cta',
      label: l10n.registrationSendCode,
      isLoading: state.isSendingCode,
      isEnabled: canTap,
      height: JeebCtaButton.primaryHeightTall,
      // BUG-1 fix: pass the field's live text to `sendCode`, which re-syncs it
      // into `state.phoneInput` and validates/sends the exact number the user
      // sees — never a stale cubit value that flipped the field red and emitted
      // zero OTP requests (also covers the run-2 on-device submit-path P0, since
      // the cubit re-commits the rendered text at submit before validating).
      onTap: () => context.read<RegistrationCubit>().sendCode(
        renderedPhone: phoneController.text,
      ),
    );
  }
}

/// Wordmark → headline → bilingual tagline, set straight on the field.
///
/// The pass-1 navy band is GONE: the R6 tile caption reads "welcome typography
/// sits straight on the glowing field (no hero box)". `_register_hero` is
/// Maestro-frozen (jm-009, jm-018), so it re-homes onto this run.
class _WelcomeBlock extends StatelessWidget {
  const _WelcomeBlock();

  static const String _logoAsset = 'assets/brand/jeeb_logo.svg';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: '_register_hero',
      container: true,
      // Without it the wordmark's own label is swallowed into the run.
      explicitChildNodes: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            identifier: '_register_hero_logo',
            label: l10n.splashLogoSemantic,
            image: true,
            // Height-constrained so the wordmark scales; width derives from the
            // SVG's intrinsic 182:73 ratio (no distortion). The start alignment
            // keeps it pinned to the gutter and mirrors.
            child: SvgPicture.asset(
              _logoAsset,
              height: Sizes.twoXLarge,
              fit: BoxFit.contain,
              alignment: AlignmentDirectional.centerStart,
            ),
          ),
          // Board gap wordmark→headline is 22 and h1 carries ~11 of it as
          // leading, so the box is the small rung, not the large one.
          const SizedBox(height: Spacing.small),
          Text(
            l10n.registrationWelcome,
            key: const Key('registration.welcome'),
            style: context.jeebText.h1.copyWith(color: colorScheme.onSurface),
          ),
          const SizedBox(height: Spacing.twoXSmall),
          Text(
            // Both runs are one periwinkle ink on the tile. The string is
            // authored per locale so each leads with its own script.
            l10n.registrationTagline,
            style: context.jeebText.body.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
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
            style: context.jeebText.bodySmall.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Divider(color: colorScheme.outlineVariant)),
      ],
    );
  }
}

/// Registration phone entry delegates its complete picker/input UX to OMDS.
class _InternationalPhoneField extends StatefulWidget {
  const _InternationalPhoneField({
    required this.state,
    required this.controller,
    this.errorText,
    this.enabled = true,
  });

  final RegistrationState state;
  final TextEditingController controller;
  final String? errorText;
  final bool enabled;

  @override
  State<_InternationalPhoneField> createState() =>
      _InternationalPhoneFieldState();
}

class _InternationalPhoneFieldState extends State<_InternationalPhoneField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final countries = RegistrationCountryOptions.forLocale(locale);
    final selected = RegistrationCountryOptions.selectedFor(
      locale: locale,
      countryCode: widget.state.selectedCountryCode,
    );
    return _PhoneInputContent(
      field: widget,
      focusNode: _focusNode,
      countries: countries,
      selectedCountry: selected,
    );
  }
}

class _PhoneInputContent extends StatelessWidget {
  const _PhoneInputContent({
    required this.field,
    required this.focusNode,
    required this.countries,
    required this.selectedCountry,
  });

  final _InternationalPhoneField field;
  final FocusNode focusNode;
  final List<OmdsCountry> countries;
  final OmdsCountry selectedCountry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<RegistrationCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PhoneInputLabel(focusNode: focusNode, enabled: field.enabled),
        const SizedBox(height: Spacing.xSmall),
        _ConfiguredOmdsPhoneInput(
          countries: countries,
          selectedCountry: selectedCountry,
          controller: field.controller,
          focusNode: focusNode,
          enabled: field.enabled,
          errorText: field.errorText,
          l10n: l10n,
          cubit: cubit,
        ),
        if (field.errorText == null) const _PhoneInputHelper(),
      ],
    );
  }
}

class _ConfiguredOmdsPhoneInput extends OmdsPhoneInput {
  _ConfiguredOmdsPhoneInput({
    required super.countries,
    required OmdsCountry selectedCountry,
    required TextEditingController controller,
    required FocusNode focusNode,
    required super.enabled,
    required super.errorText,
    required AppLocalizations l10n,
    required RegistrationCubit cubit,
  }) : super(
         selectedCountry: selectedCountry,
         controller: controller,
         focusNode: focusNode,
         hintText: l10n.registrationPhoneHint,
         pickerTitleText: l10n.registrationCountryPickerTitle,
         searchHintText: l10n.registrationCountrySearchHint,
         noResultsText: l10n.registrationCountryNoResults,
         countrySelectorSemanticsLabel: l10n.registrationCountrySelectorA11y,
         countrySearchSemanticsLabel: l10n.registrationCountrySearchA11y,
         countrySemanticsLabelBuilder: (country) =>
             l10n.registrationCountryOptionA11y(country.name, country.dialCode),
         identifier: 'register_phone_field',
         textFieldKey: const Key('registration.phoneField'),
         countrySelectorKey: const Key('registration.phoneCountry'),
         textDirection: TextDirection.ltr,
         inputFormatters: _registrationPhoneFormatters,
         onCountryChanged: (country) => cubit.countryChanged(country.code),
         onPhoneChanged: (_, raw) => cubit.phoneChanged(raw),
       );
}

final List<TextInputFormatter> _registrationPhoneFormatters =
    <TextInputFormatter>[
      FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩۰-۹+\s\-()]')),
    ];

class _PhoneInputLabel extends StatelessWidget {
  const _PhoneInputLabel({required this.focusNode, required this.enabled});

  final FocusNode focusNode;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final label = AppLocalizations.of(context).registrationPhoneHint;
    return Semantics(
      identifier: 'register_phone_label',
      label: label,
      button: true,
      enabled: enabled,
      onTap: enabled ? focusNode.requestFocus : null,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? focusNode.requestFocus : null,
        child: JeebSectionLabel(label),
      ),
    );
  }
}

class _PhoneInputHelper extends StatelessWidget {
  const _PhoneInputHelper();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: Spacing.xSmall),
      child: Semantics(
        identifier: 'register_phone_helper',
        child: Text(
          l10n.registrationPhoneHelper,
          style: context.jeebText.bodySmall.copyWith(
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Docked trust footer: no card, no in-app payment, and the number is only
/// shared with the accepted Jeeber. Kit `JeebInfoNote` in its muted tone.
class _TrustNote extends StatelessWidget {
  const _TrustNote();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        // A floor under the Spacer so the note never touches the social row on
        // a short viewport or at 200% text scale.
        Spacing.xLarge,
        Spacing.xLarge,
        Spacing.twoXLarge + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: JeebInfoNote.muted(
        icon: Icons.shield,
        iconSize: Sizes.large,
        // Board r14, one rung under the note's r18 default.
        radius: JeebRadii.md,
        text: l10n.registrationTrustNote,
        identifier: 'register_trust_note',
      ),
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
