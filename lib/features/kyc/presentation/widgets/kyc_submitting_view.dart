import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

/// Loading state rendered while [KycWizardCubit.submit] is in flight.
///
/// The bare [CircularProgressIndicator] previously used here gave no signal
/// that the upload was running, what was being sent, or how long it would
/// take — users tapped Submit a second time mid-upload. This view restores
/// design parity with the other capture steps: an icon, a headline, body
/// copy, and a single in-line spinner row, with a live region semantic so
/// VoiceOver / TalkBack announce the state change.
class KycSubmittingView extends StatelessWidget {
  const KycSubmittingView({super.key});

  static const Key rootKey = Key('kyc-submitting-root');
  static const Key titleKey = Key('kyc-submitting-title');
  static const Key spinnerKey = Key('kyc-submitting-spinner');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      key: rootKey,
      container: true,
      liveRegion: true,
      label: l10n.kycSubmittingTitle,
      hint: l10n.kycSubmittingBody,
      child: const Padding(
        padding: EdgeInsets.all(Spacing.large),
        child: _SubmittingBody(),
      ),
    );
  }
}

class _SubmittingBody extends StatelessWidget {
  const _SubmittingBody();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SubmittingIcon(scheme: theme.colorScheme),
        const SizedBox(height: Spacing.large),
        _SubmittingTitle(text: l10n.kycSubmittingTitle, theme: theme),
        const SizedBox(height: Spacing.small),
        _SubmittingBodyText(text: l10n.kycSubmittingBody, theme: theme),
        const SizedBox(height: Spacing.xLarge),
        const _SubmittingSpinner(),
      ],
    );
  }
}

class _SubmittingIcon extends StatelessWidget {
  const _SubmittingIcon({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: Sizes.nineXLarge,
        height: Sizes.nineXLarge,
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.cloud_upload_outlined,
          size: Sizes.fourXLarge,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _SubmittingTitle extends StatelessWidget {
  const _SubmittingTitle({required this.text, required this.theme});

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      key: KycSubmittingView.titleKey,
      textAlign: TextAlign.center,
      style: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SubmittingBodyText extends StatelessWidget {
  const _SubmittingBodyText({required this.text, required this.theme});

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _SubmittingSpinner extends StatelessWidget {
  const _SubmittingSpinner();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        key: KycSubmittingView.spinnerKey,
        width: Sizes.xLarge,
        height: Sizes.xLarge,
        child: OmdsLoadingState(
          size: Sizes.xLarge,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
