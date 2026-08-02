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
