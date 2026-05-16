import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../application/registration_cubit.dart';
import '../application/registration_state.dart';
import '../data/fake_otp_service.dart';
import '../domain/lebanon_phone.dart';
import 'otp_verification_screen.dart';

/// Entry point for the phone+OTP registration flow (T-mobile-002).
///
/// Routed via `/register` (see `lib/core/router/app_router.dart`). Hosts the
/// [RegistrationCubit] and renders the phone-entry view. The OTP view is
/// pushed onto the navigation stack with the same cubit instance scoped via
/// [BlocProvider.value] so countdown and attempt state survives the
/// transition.
class RegistrationScreen extends StatelessWidget {
  const RegistrationScreen({super.key, this.cubit, this.onVerified});

  /// Optional injected cubit. Tests pass a pre-wired one; production
  /// instantiates a default with the dev [FakeOtpService] (until the real
  /// auth-service client lands).
  final RegistrationCubit? cubit;

  /// Called when the cubit reports a verified phone. Defaults to
  /// `context.go('/')` (home) in production; tests inject their own
  /// callback so the screen doesn't need a full GoRouter in scope.
  final VoidCallback? onVerified;

  @override
  Widget build(BuildContext context) {
    final view = _RegistrationView(onVerified: onVerified);
    if (cubit != null) {
      return BlocProvider<RegistrationCubit>.value(
        value: cubit!,
        child: view,
      );
    }
    return BlocProvider<RegistrationCubit>(
      create: (_) => RegistrationCubit(otpService: const FakeOtpService()),
      child: view,
    );
  }
}

class _RegistrationView extends StatefulWidget {
  const _RegistrationView({this.onVerified});

  final VoidCallback? onVerified;

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
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider<RegistrationCubit>.value(
          value: cubit,
          child: OtpVerificationScreen(onVerified: onVerified),
        ),
      ),
    );
    _pushedOtp = false;
  }

  void _navigateHome() {
    final onVerified = widget.onVerified;
    if (onVerified != null) {
      onVerified();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocConsumer<RegistrationCubit, RegistrationState>(
      listenWhen: (prev, curr) =>
          prev.step != curr.step || prev.phoneInput != curr.phoneInput,
      listener: (context, state) {
        _syncControllerText(state.phoneInput);
        if (state.step == RegistrationStep.otp && !_pushedOtp) {
          _openOtpRoute();
        }
        if (state.step == RegistrationStep.verified) {
          // Verified — drop the registration stack and land on home.
          _navigateHome();
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: Text(l10n.registrationPhoneTitle)),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Spacing.medium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Phone-number text field with the Lebanese +961 prefix permanently
/// pinned to the left. The TextField only ever receives the 8 national
/// digits; the prefix is decorative. We don't use [OmdsPhoneInput] here
/// because the product spec calls for a fixed +961 with no picker — see
/// JEEB-55. The styling still flows through the OMDS theme via the
/// surrounding [InputDecoration].
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
