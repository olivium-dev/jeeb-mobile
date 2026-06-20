import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';
import '../application/offline_cubit.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OfflineCubit, OfflineState>(
      builder: (context, state) {
        if (!state.showBanner) {
          return const SizedBox.shrink();
        }
        return const _OfflineMaterialBanner();
      },
    );
  }
}

class _OfflineMaterialBanner extends StatelessWidget {
  const _OfflineMaterialBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MaterialBanner(
      content: Text(
        'You are offline. Changes will sync when connection is restored.',
        style: TextStyle(color: theme.colorScheme.onErrorContainer),
      ),
      leading: Icon(
        Icons.cloud_off,
        color: theme.colorScheme.onErrorContainer,
      ),
      backgroundColor: theme.colorScheme.errorContainer,
      actions: [
        OmdsPrimaryButton(
          text: 'DISMISS',
          variant: OmdsButtonVariant.text,
          textColor: theme.colorScheme.onErrorContainer,
          onTap: () => context.read<OfflineCubit>().dismissBanner(),
        ),
      ],
    );
  }
}
