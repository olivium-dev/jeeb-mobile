import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';
import '../../../l10n/app_localizations.dart';
import '../application/biometric_cubit.dart';

class BiometricPromptScreen extends StatelessWidget {
  const BiometricPromptScreen({super.key, this.cubit});

  final BiometricCubit? cubit;

  @override
  Widget build(BuildContext context) {
    final provided = cubit;
    if (provided != null) {
      return BlocProvider<BiometricCubit>.value(
        value: provided,
        child: const _BiometricPromptScaffold(),
      );
    }
    return BlocProvider(
      create: (_) => BiometricCubit()..checkAvailability(),
      child: const _BiometricPromptScaffold(),
    );
  }
}

class _BiometricPromptScaffold extends StatelessWidget {
  const _BiometricPromptScaffold();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BiometricCubit, BiometricState>(
      builder: (context, state) {
        return Semantics(
          identifier: 'biometric_prompt_root',
          container: true,
          child: Scaffold(
          body: SafeArea(
            child: Center(
              child: _PromptColumn(state: state),
            ),
          ),
        ),
        );
      },
    );
  }
}

class _PromptColumn extends StatelessWidget {
  const _PromptColumn({required this.state});
  final BiometricState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _PromptHeader(),
        const SizedBox(height: Spacing.fourXLarge),
        _PromptAction(state: state),
      ],
    );
  }
}

class _PromptHeader extends StatelessWidget {
  const _PromptHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(
          Icons.fingerprint,
          size: Sizes.eightXLarge,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: Spacing.xLarge),
        Text(
          AppLocalizations.of(context).useBiometrics,
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: Spacing.small),
        Text(
          'Sign in quickly with your fingerprint or face',
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _PromptAction extends StatelessWidget {
  const _PromptAction({required this.state});
  final BiometricState state;

  @override
  Widget build(BuildContext context) {
    if (state == BiometricState.available) {
      return Semantics(
        identifier: 'biometric_prompt_authenticate_cta',
        button: true,
        container: true,
        child: OmdsPrimaryButton(
        text: 'Authenticate',
        icon: const Icon(Icons.fingerprint),
        onTap: () => context.read<BiometricCubit>().authenticate(),
      ),
      );
    }
    if (state == BiometricState.checking) {
      return const OmdsLoadingState();
    }
    if (state == BiometricState.unavailable) {
      return Text(AppLocalizations.of(context).biometricNotAvailable);
    }
    return const SizedBox.shrink();
  }
}
