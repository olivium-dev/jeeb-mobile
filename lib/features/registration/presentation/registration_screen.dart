import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/network/auth_token_store.dart';
import '../../../core/network/mock_gateway_client.dart';
import '../../../core/onboarding/onboarding_cubit.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/social/social_auth_cubit.dart';
import '../../auth/social/social_auth_service.dart';
import '../../auth/social/social_auth_token_store.dart';
import '../../auth/social/social_sign_in_section.dart';
import '../application/registration_cubit.dart';
import '../application/registration_state.dart';
import '../domain/lebanon_phone.dart';
import '../domain/otp_service.dart';
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
        create: (_) => RegistrationCubit(otpService: sl<OtpService>()),
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
          ),
          tokenStore: SecureSocialAuthTokenStore(),
        ),
        child: child,
      );
    }

    return withRegistration(withSocial(view));
  }
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

  void _syncControllerText(String normalised) {
    if (_phoneController.text == normalised) return;
    _phoneController.value = TextEditingValue(
      text: normalised,
      selection: TextSelection.collapsed(offset: normalised.length),
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
    // ignore: use_build_context_synchronously
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocConsumer<RegistrationCubit, RegistrationState>(
      listenWhen: (prev, curr) =>
          prev.step != curr.step || prev.phoneInput != curr.phoneInput,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SocialSignInSection(
                    onAuthenticated: (_) {
                      final cb =
                          widget.onSocialAuthenticated ?? widget.onVerified;
                      if (cb != null) {
                        cb();
                      } else {
                        context.go('/');
                      }
                    },
                  ),
                  const SizedBox(height: Spacing.large),
                  Text(
                    l10n.registrationPhoneTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: Spacing.xSmall),
                  Text(
                    l10n.registrationPhoneSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: Spacing.large),
                  _PhoneField(
                    controller: _phoneController,
                    hintText: l10n.registrationPhoneHint,
                    errorText: state.phoneError == null
                        ? null
                        : _phoneErrorCopy(state.phoneError!, l10n),
                    enabled: !state.isSendingCode,
                    onChanged: (raw) =>
                        context.read<RegistrationCubit>().phoneChanged(raw),
                  ),
                  const SizedBox(height: Spacing.large),
                  OmdsPrimaryButton(
                    key: const Key('registration.sendCode'),
                    text: state.isSendingCode
                        ? l10n.registrationSending
                        : l10n.registrationSendCode,
                    isEnabled: state.isPhoneReady && !state.isSendingCode,
                    onTap: () => context.read<RegistrationCubit>().sendCode(),
                  ),
                  // SECURITY: the super-login dev backdoor mints a
                  // `mock-jwt-access-super-user` token that bypasses real
                  // auth. It is now compiled out of release builds — the
                  // tap target only exists under `kDebugMode` (debug/profile
                  // dev seam). Full removal is owner-gated (see
                  // design/JEEB-PLAN.md §6, defect #2 / P0-2).
                  if (kDebugMode) ...[
                    const SizedBox(height: Spacing.twoXLarge),
                    Center(
                      child: GestureDetector(
                        key: const Key('registration.superLogin'),
                        onTap: () => _superLogin(context),
                        child: Text(
                          'Super User Login',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: UIConstants.opacityMedium),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _superLogin(BuildContext context) async {
    final tokenStore = sl<AuthTokenStore>();
    await tokenStore.save(
      accessToken: 'mock-jwt-access-super-user',
      refreshToken: 'mock-jwt-refresh-super-user',
      userId: 'super-user-001',
    );

    if (!context.mounted) return;

    // Mark onboarding as done via the cubit so the router redirect sees the
    // state change and lets us through to the shell.
    await context.read<OnboardingCubit>().complete();

    if (!context.mounted) return;

    final onVerified = widget.onVerified;
    if (onVerified != null) {
      onVerified();
    } else {
      context.go('/');
    }
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
      // strips everything except the trailing 8 national digits and
      // mirrors that canonical form back into the controller via
      // `_syncControllerText` — so we don't enforce a max-length here, or
      // we'd truncate the wrong end of a pasted +961 string.
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
