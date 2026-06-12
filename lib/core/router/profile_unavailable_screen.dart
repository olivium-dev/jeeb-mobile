import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../l10n/app_localizations.dart';

/// Release-safe fallback rendered when a `/profile/*` route is reached without
/// the typed view-data it needs. Replaces the debug-only fixture so no
/// hardcoded PII can render in a release build (see [AppRouter] profile routes).
class ProfileUnavailableScreen extends StatelessWidget {
  const ProfileUnavailableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: OMDSAppBar(
        title: l10n.profileUnavailableTitle,
        showBackButton: true,
      ),
      body: Center(
        child: OmdsErrorState(
          key: const Key('profile_unavailable_state'),
          title: l10n.profileUnavailableTitle,
          message: l10n.profileUnavailableBody,
          icon: Icons.person_off_outlined,
        ),
      ),
    );
  }
}
