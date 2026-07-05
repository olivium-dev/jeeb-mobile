import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../core/theme/jeeb_color_roles.dart';
import '../../../l10n/app_localizations.dart';
import '../application/offline_cubit.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OfflineCubit, OfflineState>(
      builder: (context, state) {
        // JEBV4-13: honour the per-episode dismissal — DISMISS used to be a
        // dead `onTap: () {}`; the cubit re-arms on the next offline episode.
        if (state.status == ConnectivityStatus.online ||
            state.bannerDismissed) {
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
    final l10n = AppLocalizations.of(context);
    return MaterialBanner(
      content: Text(
        l10n.offlineBannerMessage,
        style: TextStyle(color: roles.onWarningContainer),
      ),
      leading: Icon(
        Icons.cloud_off,
        color: roles.onWarningContainer,
      ),
      backgroundColor: roles.warningContainer,
      actions: [
        OmdsPrimaryButton(
          text: l10n.commonDismiss,
          variant: OmdsButtonVariant.text,
          textColor: roles.onWarningContainer,
          onTap: () => context.read<OfflineCubit>().dismissBanner(),
        ),
      ],
    );
  }
}
