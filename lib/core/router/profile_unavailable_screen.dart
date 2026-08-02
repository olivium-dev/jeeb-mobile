import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../l10n/app_localizations.dart';




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
