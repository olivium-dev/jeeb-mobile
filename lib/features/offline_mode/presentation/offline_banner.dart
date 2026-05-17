import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../application/offline_cubit.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OfflineCubit, OfflineState>(
      builder: (context, state) {
        if (state.status == ConnectivityStatus.online) {
          return const SizedBox.shrink();
        }
        return MaterialBanner(
          content: Text(
            'You are offline. Changes will sync when connection is restored.',
            style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
          ),
          leading: Icon(
            Icons.cloud_off,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          actions: [
            TextButton(
              onPressed: () {},
              child: const Text('DISMISS'),
            ),
          ],
        );
      },
    );
  }
}
