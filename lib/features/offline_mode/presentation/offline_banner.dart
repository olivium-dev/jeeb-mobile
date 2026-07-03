import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../core/theme/jeeb_color_roles.dart';
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
        return const _OfflineMaterialBanner();
      },
    );
  }
}

class _OfflineMaterialBanner extends StatelessWidget {
  const _OfflineMaterialBanner();

  @override
  Widget build(BuildContext context) {
    // Offline-with-sync-pending is a warning state (recoverable, data safe),
    // not an error -> semantic warning role.
    final roles = context.jeebRoles;
    return MaterialBanner(
      content: Text(
        'You are offline. Changes will sync when connection is restored.',
        style: TextStyle(color: roles.onWarningContainer),
      ),
      leading: Icon(
        Icons.cloud_off,
        color: roles.onWarningContainer,
      ),
      backgroundColor: roles.warningContainer,
      actions: [
        OmdsPrimaryButton(
          text: 'DISMISS',
          variant: OmdsButtonVariant.text,
          textColor: roles.onWarningContainer,
          onTap: () {},
        ),
      ],
    );
  }
}
