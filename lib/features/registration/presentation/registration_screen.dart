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

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/registration_screen_fixtures.dart';

class RegistrationScreen extends StatelessWidget {
  const RegistrationScreen({
    super.key,
    this.cubit,
    this.socialAuthCubit,
    this.onVerified,
    this.onSocialAuthenticated,
  });

  final RegistrationCubit? cubit;

  final SocialAuthCubit? socialAuthCubit;

  final VoidCallback? onVerified;

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

  /// DEFECT FIX (Maestro P0): field is source of truth during typing; only re-seed on step change.
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
          child: OtpVerificationScreen(onVerified: onVerified ?? () {}),
        ),
      ),
    );
    _pushedOtp = false;
  }

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
      onVerified();
      return;
    }
    if (!mounted) return;
    await context.read<OnboardingCubit>().complete();
    if (!mounted) return;
    // ignore: use_build_context_synchronously
    await _refreshSession(context);
    if (!mounted) return;
    // ignore: use_build_context_synchronously
    context.go('/');
  }

  /// Reads SessionCubit if available (null in tests without app shell).
  static Future<void> _refreshSession(BuildContext context) async {
    final session = context.read<SessionCubit?>();
    if (session != null) await session.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocConsumer<RegistrationCubit, RegistrationState>(
      listenWhen: (prev, curr) => prev.step != curr.step,
      listener: (context, state) async {
        _syncControllerText(state.phoneInput);
        if (state.step == RegistrationStep.otp && !_pushedOtp) {
          _openOtpRoute();
        }
        if (state.step == RegistrationStep.verified) {
          if (widget.onVerified == null) await _openDisplayNameStep();
          await _navigateHome();
        }
      },
      builder: (context, state) {
        return Semantics(
          identifier: 'registration_root',
          container: true,
          child: Scaffold(
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
        _SendCodeButton(state: state, phoneController: phoneController),
      ],
    );
  }
}

class _SendCodeButton extends StatelessWidget {
  const _SendCodeButton({required this.state, required this.phoneController});

  final RegistrationState state;
  final TextEditingController phoneController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final renderedReady =
        LebanonPhone.tryParse(phoneController.text) != null || state.isPhoneReady;
    return Semantics(
      identifier: 'register_phone_submit_cta',
      button: true,
      container: true,
      child: OmdsLoadingButton(
      key: const Key('registration.sendCode'),
      text: l10n.registrationSendCode,
      isLoading: state.isSendingCode,
      isEnabled: renderedReady && !state.isSendingCode,
      onTap: () => context
          .read<RegistrationCubit>()
          .sendCode(renderedPhone: phoneController.text),
      ),
    );
  }
}

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
      explicitChildNodes: true,
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

/// Fixed +961 prefix; TextField receives 8 national digits only.
/// EXEMPT(flutter-omds-design-system-usage): raw TextField retained (JEEB-55 requires fixed +961, no picker).
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
    return Semantics(
      identifier: 'register_phone_field',
      textField: true,
      container: true,
      child: TextField(
      key: const Key('registration.phoneField'),
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.phone,
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
      return l10n.registrationPhoneInvalid;
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/registration/registration_screen_preview_test.dart
// ===========================================================================
//
// This is a SCREEN, so three things differ from a widget preview.
//
// 1. It owns its own `Scaffold` (OMDSAppBar + a scrolling body) and
//    [jeebPreviewHost] wraps every child in one as well, so the canvas shows
//    two nested Scaffolds. The inner one is the real surface; the outer
//    contributes only a background. The canvas box is therefore a real device
//    ([_registrationScreenPhoneBox], 390x844) rather than the harness's default
//    390x200 — a hero band, a welcome stack, two social buttons, a divider, a
//    phone field and a CTA cannot be judged in a 200 pt strip.
//
// 2. No `Router` and no GetIt. [RegistrationScreen] already ships `cubit:`,
//    `socialAuthCubit:` and `onVerified:` seams (built for exactly this kind of
//    router-free mount). With both cubits injected the screen never reaches
//    `sl<OtpService>()`, `resolveGatewayDio()` or `SecureSocialAuthTokenStore()`
//    — no Dio, no injection container, no Keychain. `onVerified: () {}` is what
//    keeps `context.go('/')` out of the listener. Network-free by construction,
//    not merely by the guard in [jeebPreviewHost].
//
// 3. [_RegistrationScreenHost] OWNS the two cubits and closes them in
//    `dispose`. The screen injects them with `BlocProvider.value`, which by
//    contract does not close what it did not create, so a preview that built a
//    cubit inline would leak one per canvas rebuild.
//
// Every fixture is shared verbatim with the designer-facing Screen Catalog
// entry (`lib/devtool/catalog/fixtures/registration_screen_fixtures.dart`), so
// the catalog and the canvas cannot drift into two different notions of "the
// sending state". The catalog names three of these states; the other five are
// the states that break, which a three-state catalog entry does not reach.
//
// One state is deliberately absent: `RegistrationStep.otp` / `.verified`. Both
// exist only to fire the listener — the first pushes `OtpVerificationScreen`
// (which has its own preview section) and the second navigates away — so they
// are transitions, not pictures.
//
// What these previews surfaced in the screen — see the notes on each:
//
//  * a VALID number that the gateway could not be asked about, or that the
//    gateway refused with a 429, is reported to the user as an INVALID number.
//    `_phoneErrorCopy` maps `RegistrationPhoneError.networkError` and
//    `.rateLimited` onto `l10n.registrationPhoneInvalid` ("Enter a valid
//    Lebanese phone number."), so three of these previews render the identical
//    red line under three different numbers, two of which parse cleanly. The
//    only remedy the copy suggests — fix your number — is wrong for two of the
//    three causes, and re-typing the same correct digits cannot clear it. The
//    code comment calls this an interim reuse (JEEB-56); the cards are what it
//    costs. There is no `registrationPhoneNetwork` or `registrationPhoneRateLimited`
//    key in either ARB.
//  * nothing throttles a retry after a 429. `Send refused · gateway 429` leaves
//    the field enabled and the CTA live, so the screen invites an immediate
//    re-tap of the endpoint that just rate-limited it — while telling the user
//    the reason is their phone number.
//  * a pasted `+961 …` number is drawn NEXT TO the permanent `+961` prefix, so
//    the field reads "+961  +961 71 123 456". `_PhoneField`'s own doc comment
//    states "The TextField only ever receives the 8 national digits; the prefix
//    is decorative" — that contract is no longer true. `inputFormatters`
//    explicitly allows `+`, and PR #45 removed the per-keystroke mirror-back of
//    the normalised value (it corrupted live editing, Maestro P0), so nothing
//    strips the dial code from the rendered text. Only `sendCode` normalises,
//    and it never writes back. Visible on `Pasted +961 block`.
//  * the app bar and the body do NOT repeat the title here — `OMDSAppBar` shows
//    "Enter your phone" and the body leads with "Welcome to Jeeb", which is the
//    right shape and worth contrasting with the sibling OTP screen, where the
//    same title is drawn twice.

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _registrationScreenPhoneBox = Size(390, 844);

/// Owns the two cubits [RegistrationScreen] takes by injection, and closes
/// them.
///
/// The screen provides both with `BlocProvider.value`, which does not close a
/// cubit it did not create — so without this the canvas would leak one
/// [RegistrationCubit] and one [SocialAuthCubit] per rebuild, and (worse) two
/// cards could end up sharing a mutable one.
///
/// The social half is inert in every preview:
/// [registrationScreenFakeSocialAuthCubit] answers every tap with
/// `SocialAuthError.cancelled`, the one failure the cubit returns to idle
/// silently, so tapping Google/Apple in the canvas lands back where it started
/// instead of on an error nobody asked to review. `SocialSignInSection`'s own
/// preview section owns those states.
class _RegistrationScreenHost extends StatefulWidget {
  const _RegistrationScreenHost({super.key, required this.createCubit});

  final RegistrationCubit Function() createCubit;

  @override
  State<_RegistrationScreenHost> createState() =>
      _RegistrationScreenHostState();
}

class _RegistrationScreenHostState extends State<_RegistrationScreenHost> {
  late final RegistrationCubit _registration = widget.createCubit();
  late final SocialAuthCubit _social = registrationScreenFakeSocialAuthCubit();

  @override
  void dispose() {
    _registration.close();
    _social.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RegistrationScreen(
        cubit: _registration,
        socialAuthCubit: _social,
        // The seam that keeps `context.go('/')` — and therefore a GoRouter —
        // out of these previews. Never reached: no preview seeds `verified`.
        onVerified: () {},
      );
}

/// Mounts [RegistrationScreen] over a freshly built cubit.
///
/// [stateKey] is a per-preview [ValueKey]. It matters in the render test rather
/// than the canvas: two previews of this screen build the identical element
/// shape, so without distinct keys Flutter would update the host in place,
/// `createCubit` would never run again, and the second pump would silently
/// re-render the first preview's state.
Widget _registrationScreenHosted(
  String stateKey,
  RegistrationCubit Function() createCubit,
) =>
    _RegistrationScreenHost(
      key: ValueKey<String>('registration-screen-preview-$stateKey'),
      createCubit: createCubit,
    );

/// Cold entry — the screen every unauthenticated user lands on.
///
/// The EMPTY state: no digits, the "Phone number" hint at full opacity, no
/// error, and `registration.sendCode` disabled. Note that the hint is the ONLY
/// thing distinguishing this card's copy from the others, and Flutter keeps the
/// hint mounted at zero opacity in every other state — so the render test
/// proves this one by its empty controller and its dead CTA, not by copy alone.
///
/// Matrixed because the whole composition is here and it is the RTL-sensitive
/// one: `_RegisterHero`, the welcome stack, the social column, the "or" divider
/// whose two `Expanded` rules must stay balanced, and — the part that actually
/// moves — the field's `prefixIcon`. `prefixIcon` is DIRECTIONAL, so the fixed
/// "+961" jumps to the trailing edge under `Locale('ar')` while the digits
/// typed into the field stay LTR. The EN 200% card is the ceiling for a column
/// that has to scroll: at that scale the CTA is well below the fold.
@JeebPreview(
  group: 'registration',
  name: 'Idle · empty field',
  size: _registrationScreenPhoneBox,
  matrix: true,
)
Widget registrationScreenIdle() =>
    _registrationScreenHosted('idle', registrationScreenIdleCubit);

/// Mid-typing: six digits in, one short of the 7-digit minimum.
///
/// The state that separates "not finished" from "wrong". `phoneChanged` clears
/// `phoneError` on every keystroke, so the CTA is disabled and there is NO red
/// line — read this card next to `Rejected locally · too short`, which is the
/// same unparseable field after a Send.
///
/// It is also the value the Maestro P0 regression erases down to
/// (`test/registration_screen_test.dart`): before PR #45 the cubit mirrored its
/// own normalised value back into the field per keystroke, so this state was a
/// trap — erasing one more digit dropped a valid one and the field could never
/// climb back to eight.
@JeebPreview(
  group: 'registration',
  name: 'Typing · below the 7-digit minimum',
  size: _registrationScreenPhoneBox,
)
Widget registrationScreenTyping() =>
    _registrationScreenHosted('typing', registrationScreenTypingCubit);

/// A full, valid national number: the CTA is live and nothing is red.
///
/// The happy path, and the only card in the set where `registration.sendCode`
/// is enabled with no send in flight. Tapping it in the canvas runs the real
/// `sendCode` over [FakeOtpService], which answers `sent` — so the canvas walks
/// on to the real `OtpVerificationScreen`, exactly as the app does.
@JeebPreview(
  group: 'registration',
  name: 'Valid number · CTA live',
  size: _registrationScreenPhoneBox,
)
Widget registrationScreenReady() =>
    _registrationScreenHosted('ready', registrationScreenReadyCubit);

/// Send tapped on a number too short to parse — rejected locally, before the
/// network.
///
/// `sendCode` validates and emits `phoneError: invalid` synchronously, without
/// touching [OtpService] at all, so no request is made. This is the ONLY one of
/// the screen's three error states whose copy is actually true: "Enter a valid
/// Lebanese phone number." The other two say the same thing about numbers that
/// are already valid.
@JeebPreview(
  group: 'registration',
  name: 'Rejected locally · too short',
  size: _registrationScreenPhoneBox,
)
Widget registrationScreenInvalidNumber() => _registrationScreenHosted(
      'invalid',
      registrationScreenInvalidNumberCubit,
    );

/// `POST /v1/auth/otp/request` is in flight.
///
/// The LOADING state, and the screen handles it well: the CTA swaps its label
/// for an in-button spinner (`OmdsLoadingButton`) and the field goes
/// `enabled: false`, so the number cannot be edited out from under a request
/// that is already carrying it. The fixture's [OtpService] never resolves,
/// because every real outcome lands on the next microtask and the state would
/// be gone before a reviewer saw it.
///
/// The spinner is an indeterminate `CircularProgressIndicator`, so this preview
/// can never be pumped with `pumpAndSettle` — see the dedicated group in the
/// render test.
@JeebPreview(
  group: 'registration',
  name: 'Send in flight',
  size: _registrationScreenPhoneBox,
)
Widget registrationScreenSending() =>
    _registrationScreenHosted('sending', registrationScreenSendingCubit);

/// A VALID number the gateway could not be asked about — and the screen says
/// the number is invalid.
///
/// `_phoneErrorCopy` collapses `RegistrationPhoneError.networkError` onto
/// `l10n.registrationPhoneInvalid`, so an offline device produces a frame that
/// is pixel-identical to `Rejected locally · too short` apart from the digits
/// above the error. `76001122` parses; there is nothing for the user to fix,
/// and re-typing the same correct number cannot clear the line. Nothing on the
/// screen mentions the connection.
@JeebPreview(
  group: 'registration',
  name: 'Send failed · gateway unreachable',
  size: _registrationScreenPhoneBox,
)
Widget registrationScreenNetworkError() => _registrationScreenHosted(
      'network-error',
      registrationScreenNetworkErrorCubit,
    );

/// The gateway refused the send with a 429 — same wrong copy, plus an open
/// door.
///
/// `81445566` is valid, so again the user is told to fix a number that is not
/// broken. Worse than the offline card: the field stays enabled and the CTA
/// stays live, with no client-side cooldown anywhere in `sendCode`, so the one
/// action the screen makes available is an immediate re-tap of the endpoint
/// that just rate-limited it. Compare with the sibling OTP screen, which routes
/// its own 429 into a lockout step with a visible countdown.
@JeebPreview(
  group: 'registration',
  name: 'Send refused · gateway 429',
  size: _registrationScreenPhoneBox,
)
Widget registrationScreenRateLimited() => _registrationScreenHosted(
      'rate-limited',
      registrationScreenRateLimitedCubit,
    );

/// A full international number pasted out of Contacts — the longest content the
/// field can hold, and a doubled dial code.
///
/// The field renders `+961 71 123 456` immediately to the right of the
/// permanent, non-editable `+961` prefix, so the row reads "+961 +961 71 123
/// 456". `_PhoneField` documents the opposite ("The TextField only ever
/// receives the 8 national digits; the prefix is decorative") but nothing
/// enforces it: `inputFormatters` allows `+` on purpose so a pasted block is
/// not truncated at the wrong end, and PR #45 removed the only code that used
/// to write the normalised value back. `LebanonPhone.normalise` still strips it
/// on Send, so the request is correct — this is a display defect, not a
/// delivery one, but it is the first thing a user sees after pasting.
///
/// Matrixed for that reason: `prefixIcon` is directional, so the AR RTL card
/// puts the decorative "+961" on the opposite side of a field whose own text is
/// still LTR, and the EN 200% card is where 15 characters plus a prefix decide
/// whether the row wraps, ellipsizes or overflows.
@JeebPreview(
  group: 'registration',
  name: 'Pasted +961 block · doubled dial code',
  size: _registrationScreenPhoneBox,
  matrix: true,
)
Widget registrationScreenPasted() =>
    _registrationScreenHosted('pasted', registrationScreenPastedCubit);
