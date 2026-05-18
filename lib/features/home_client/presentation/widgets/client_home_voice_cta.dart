import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

/// Quick-action button that opens the voice request recorder. Sits below
/// the greeting on the home tab — large, tappable, mic-iconed — so the
/// dominant CTA is "make a new request" even when the user has active ones.
class ClientHomeVoiceCta extends StatelessWidget {
  const ClientHomeVoiceCta({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.xSmall,
      ),
      child: OmdsPrimaryButton(
        key: const Key('client-home-voice-cta'),
        text: l10n.homeRecordVoiceRequest,
        onTap: onPressed,
        icon: const Icon(Icons.mic, size: Sizes.large),
      ),
    );
  }
}
