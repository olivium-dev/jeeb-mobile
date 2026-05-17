import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../application/biometric_cubit.dart';

class BiometricPromptScreen extends StatelessWidget {
  const BiometricPromptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BiometricCubit()..checkAvailability(),
      child: BlocBuilder<BiometricCubit, BiometricState>(
        builder: (context, state) {
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.fingerprint,
                      size: 80,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Use Biometrics',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Sign in quickly with your fingerprint or face',
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    if (state == BiometricState.available)
                      FilledButton.icon(
                        onPressed: () =>
                            context.read<BiometricCubit>().authenticate(),
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('Authenticate'),
                      ),
                    if (state == BiometricState.checking)
                      const CircularProgressIndicator(),
                    if (state == BiometricState.unavailable)
                      const Text('Biometric authentication not available'),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
