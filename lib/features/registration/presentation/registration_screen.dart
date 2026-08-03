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
import '../../../core/theme/jeeb_color_roles.dart';
import '../../../core/theme/jeeb_shadows.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_navy_surface_card.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/social/social_auth_cubit.dart';
import '../../auth/social/social_auth_service.dart';
import '../../auth/social/social_auth_token_store.dart';
import '../../auth/social/social_sign_in_section.dart';
import '../../profile_name/presentation/display_name_setup_screen.dart';
import '../application/registration_cubit.dart';
import '../application/registration_state.dart';
import '../domain/lebanon_phone.dart';
import '../domain/otp_service.dart';
import '../domain/registration_attempt_policy.dart';
import 'otp_verification_screen.dart';

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
      listenWhen: (prev, curr) => prev.step != curr.step,
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
            // The navy band bleeds under the status bar now that the app bar is
            // gone, so the system glyphs have to flip to their light variant.
            value: SystemUiOverlayStyle.light,
            child: Scaffold(
              // `column → content → flex:1 → docked note` (plan R1). The
              // LayoutBuilder/ConstrainedBox/IntrinsicHeight trio is what makes
              // the Spacer legal inside a scroll view: the sheet fills the
              // viewport when it fits and degrades to a real scroll when the
              // keyboard opens or text scales to 200%.
              body: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _RegisterHero(),
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              Spacing.xLarge,
                              Spacing.xLarge,
                              Spacing.xLarge,
                              0,
                            ),
                            child: _PhoneEntryBody(
                              state: state,
                              phoneController: _phoneController,
                              onSocialAuthenticated: () =>
                                  _onSocialAuthenticated(context),
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
}

/// The phone-entry composition, phone-first per the redesign board: label →
/// field row → helper → CTA → "or" divider → a compact two-up social row.
///
/// NOTE: the debug-only super-login entry points were RELOCATED to the login
/// screen (`lib/features/auth/presentation/login_screen.dart`) — P1 owner
/// request. They no longer live here.
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
        _PhoneField(
          controller: phoneController,
          errorText: state.phoneError == null
              ? null
              : _phoneErrorCopy(state.phoneError!, l10n),
          enabled: !state.isSendingCode,
          onChanged: (raw) =>
              context.read<RegistrationCubit>().phoneChanged(raw),
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

/// Phone send-code CTA — kept as an [OmdsLoadingButton] for the in-button
/// spinner, re-shaped to the board's navy pill (r999, h56, `ctaNavy` lift).
class _SendCodeButton extends StatelessWidget {
  const _SendCodeButton({required this.state, required this.phoneController});

  final RegistrationState state;
  final TextEditingController phoneController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    // BUG-1 (customer-spine blocker): the phone field — not the cubit — owns the
    // text while the user types (PR #45). Read the live controller text here and
    // hand it to `sendCode` so Send validates/sends the number actually rendered,
    // never a stale `state.phoneInput` that diverged and flipped the field red
    // while emitting zero OTP requests. Enablement also reads the live text so
    // the CTA can't be wrongly disabled when the controller leads the cubit.
    final renderedReady =
        LebanonPhone.tryParse(phoneController.text) != null || state.isPhoneReady;
    final canTap = renderedReady && !state.isSendingCode;
    return Semantics(
      identifier: 'register_phone_submit_cta',
      button: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: OmdsBorderRadius.pill,
          // §4.5 outline-over-shadow: only a live CTA is promoted; a disabled
          // pill drops the lift instead of floating over flat white.
          boxShadow: canTap ? JeebShadows.ctaNavy : null,
        ),
        child: OmdsLoadingButton(
          key: const Key('registration.sendCode'),
          text: l10n.registrationSendCode,
          isLoading: state.isSendingCode,
          // Enablement reads the live controller text (or the cubit's ready flag)
          // so the CTA can't be wrongly disabled when the field leads the cubit
          // (PR #45 made the field the source of truth while typing).
          isEnabled: canTap,
          height: Sizes.fiveXLarge,
          borderRadius: OmdsBorderRadius.pill,
          // OMDS only inks its own default style, so a supplied `textStyle`
          // MUST carry the on-primary colour or the label inherits the body
          // ink and disappears into the navy pill.
          textStyle:
              context.jeebText.button.copyWith(color: colorScheme.onPrimary),
          // BUG-1 fix: pass the field's live text to `sendCode`, which re-syncs it
          // into `state.phoneInput` and validates/sends the exact number the user
          // sees — never a stale cubit value that flipped the field red and emitted
          // zero OTP requests (also covers the run-2 on-device submit-path P0, since
          // the cubit re-commits the rendered text at submit before validating).
          onTap: () => context
              .read<RegistrationCubit>()
              .sendCode(renderedPhone: phoneController.text),
        ),
      ),
    );
  }
}

/// The navy welcome band (redesign board `tpl 66-76`): full-bleed to the top
/// edge, bottom-only r36, two off-canvas decorative rings, wordmark → headline
/// → bilingual tagline. Consumes the kit's `topBand` mode — screen 02 is its
/// only consumer, and the status-bar inset is folded into its padding there.
class _RegisterHero extends StatelessWidget {
  const _RegisterHero();

  static const String _logoAsset = 'assets/brand/jeeb_logo.svg';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return JeebNavySurfaceCard.topBand(
      identifier: '_register_hero',
      rings: const [JeebNavyRing.bandOuter, JeebNavyRing.bandInner],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            identifier: '_register_hero_logo',
            label: l10n.splashLogoSemantic,
            image: true,
            // Height-constrained so the wordmark scales to the band; width
            // derives from the SVG's intrinsic 182:73 ratio (no distortion).
            // The start alignment keeps it pinned to the gutter and mirrors.
            child: SvgPicture.asset(
              _logoAsset,
              height: Sizes.twoXLarge,
              fit: BoxFit.contain,
              alignment: AlignmentDirectional.centerStart,
            ),
          ),
          const SizedBox(height: Spacing.medium),
          Text(
            l10n.registrationWelcome,
            key: const Key('registration.welcome'),
            style: context.jeebText.h1.copyWith(color: colorScheme.onPrimary),
          ),
          const SizedBox(height: Spacing.xSmall),
          Text(
            // Periwinkle on navy is the board's pairing; the AA guard bans it
            // on light surfaces only. The string is authored per locale so each
            // one leads with its own script — no Directionality override.
            l10n.registrationTagline,
            style: context.jeebText.body
                .copyWith(color: colorScheme.onSecondaryContainer),
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
            // Deliberately `onSurfaceVariant`, NOT periwinkle: plan §4.1 and
            // `color_role_contrast_test.dart:129-137` both forbid periwinkle
            // body ink on a light surface.
            style: context.jeebText.bodySmall
                .copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ),
        Expanded(child: Divider(color: colorScheme.outlineVariant)),
      ],
    );
  }
}

/// Phone-number block: navy label → the +961 field row → helper/error line.
///
/// The Lebanese `+961` prefix is permanently pinned to the start of the row;
/// the [TextField] only ever receives the national digits.
///
/// EXEMPT(flutter-omds-design-system-usage): raw [TextField] retained.
/// - [OmdsPhoneInput] ships a country-picker UX; the product spec calls
///   for a fixed +961 with no picker (JEEB-55).
/// - [OmdsTextField] does not expose `prefixIconConstraints`, so a tight
///   inline "+961" glyph would inflate to the default 48dp prefix gutter
///   and break the digit-alignment design.
/// All styling still flows through the OMDS theme and the redesign token
/// layer: the fill is `colorScheme.surfaceContainerHigh`, the 2px stroke is
/// `colorScheme.primary`, the radius is [OmdsBorderRadius.medium] and the
/// focus ring is `JeebShadows.focusRing`. Promotion to OMDS tracked under
/// JEEB-57.
class _PhoneField extends StatefulWidget {
  const _PhoneField({
    required this.controller,
    required this.onChanged,
    this.errorText,
    this.enabled = true,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? errorText;
  final bool enabled;

  @override
  State<_PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<_PhoneField> {
  /// Owned here so the container can paint the board's focus ring — once the
  /// `InputDecoration` border is gone the field has no other focus feedback.
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final errorText = widget.errorText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The label doubles as a tap target for the field: Maestro's
        // `jm-009` taps the text "Phone number" and then types, which only
        // works while that string is attached to the input.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? _focusNode.requestFocus : null,
          child: Text(
            l10n.registrationPhoneHint,
            style: context.jeebText.cardTitle
                .copyWith(color: colorScheme.onSurface),
          ),
        ),
        const SizedBox(height: Spacing.small),
        ListenableBuilder(
          listenable: _focusNode,
          builder: (context, _) => Container(
            height: Sizes.sixXLarge,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: Spacing.medium,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: OmdsBorderRadius.medium,
              border: Border.all(
                color:
                    errorText == null ? colorScheme.primary : colorScheme.error,
                width: Sizes.threeXSmall,
              ),
              boxShadow: _focusNode.hasFocus ? JeebShadows.focusRing : null,
            ),
            child: Row(
              children: [
                Text(
                  // Its own Text, never merged into the dial code: the prefix
                  // test matches `find.text(LebanonPhone.dialCode)` exactly.
                  '🇱🇧',
                  style: context.jeebText.titleProminent,
                ),
                // The board draws the flag and the dial code as one span
                // separated by a literal space, so this pair is tighter than
                // the 12px rhythm of the rest of the row.
                const SizedBox(width: Spacing.twoXSmall),
                Text(
                  LebanonPhone.dialCode,
                  key: const Key('registration.phonePrefix'),
                  // Pinned LTR so the `+` stays on the correct side under `ar`.
                  textDirection: TextDirection.ltr,
                  style: context.jeebText.titleProminent
                      .copyWith(color: colorScheme.onSurface),
                ),
                const SizedBox(width: Spacing.small),
                Container(
                  width: 1,
                  height: Sizes.xLarge,
                  color: colorScheme.outlineVariant,
                ),
                const SizedBox(width: Spacing.small),
                Expanded(
                  child: Semantics(
                    identifier: 'register_phone_field',
                    textField: true,
                    container: true,
                    child: TextField(
                      key: const Key('registration.phoneField'),
                      controller: widget.controller,
                      focusNode: _focusNode,
                      enabled: widget.enabled,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      // Keep digits, the `+` (for users who paste a `+961…`
                      // block), and common separators (space, dash, parens).
                      // The cubit's `normalise` strips everything except the
                      // trailing 8 national digits for validation/sending; the
                      // field itself keeps what the user typed (we no longer
                      // mirror the normalised form back per-keystroke — that
                      // corrupted live editing, Maestro P0). No max-length here
                      // so a pasted +961 block isn't truncated at the wrong end
                      // before `normalise` sees it. No grouping formatter
                      // either: the board's `3 123 456` is the hint, and three
                      // regression tests exist because a controller rewrite once
                      // made on-device login impossible.
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d+\s\-()]')),
                      ],
                      style: context.jeebText.titleProminent.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: l10n.registrationPhoneExample,
                        hintStyle: context.jeebText.titleProminent.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      onChanged: widget.onChanged,
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.small),
                // Live-valid tick. Controller-driven rather than state-driven:
                // two regression tests set the controller text WITHOUT firing
                // `onChanged`, and the tick must agree with what is rendered.
                // `AnimatedOpacity` (not conditional insertion) so the row
                // never reflows per keystroke.
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: widget.controller,
                  builder: (context, value, _) {
                    final isValid = LebanonPhone.tryParse(value.text) != null;
                    return Semantics(
                      identifier: 'register_phone_valid_check',
                      child: AnimatedOpacity(
                        opacity: isValid ? 1 : 0,
                        duration: Durations.short3,
                        child: Icon(
                          Icons.check,
                          size: Sizes.large,
                          // The one sanctioned orange on this screen.
                          color: context.jeebRoles.accent,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Spacing.xSmall),
        Semantics(
          identifier: 'register_phone_helper',
          child: Text(
            errorText ?? l10n.registrationPhoneHelper,
            style: context.jeebText.bodySmall.copyWith(
              fontWeight: FontWeight.w500,
              // AA-safe brown, NOT the board's periwinkle: plan §4.1 forbids
              // periwinkle as body ink on a light surface.
              color: errorText == null
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.error,
            ),
          ),
        ),
      ],
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
