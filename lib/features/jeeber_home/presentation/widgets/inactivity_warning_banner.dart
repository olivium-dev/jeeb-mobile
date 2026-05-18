import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

/// Banner shown 30 minutes before the 8h auto-offline kicks in.
///
/// Tapping the CTA fires [onExtend] which resets the idle timer in the
/// cubit; dismissing it does NOT extend (the warning re-appears next tick).
class InactivityWarningBanner extends StatelessWidget {
  const InactivityWarningBanner({super.key, required this.onExtend});

  static const Key rootKey = Key('availability-inactivity-banner-root');
  static const Key ctaKey = Key('availability-inactivity-banner-cta');

  final VoidCallback onExtend;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: rootKey,
      margin: const EdgeInsets.symmetric(horizontal: Spacing.medium),
      padding: const EdgeInsets.all(Spacing.medium),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer,
        borderRadius: OmdsBorderRadius.medium,
        border: Border.all(color: colorScheme.tertiary),
      ),
      child: _BannerBody(onExtend: onExtend),
    );
  }
}

class _BannerBody extends StatelessWidget {
  const _BannerBody({required this.onExtend});

  final VoidCallback onExtend;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _BannerHeader(),
        const SizedBox(height: Spacing.xSmall),
        const _BannerDescription(),
        const SizedBox(height: Spacing.small),
        _BannerCta(onExtend: onExtend),
      ],
    );
  }
}

class _BannerHeader extends StatelessWidget {
  const _BannerHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Icon(Icons.access_time, color: theme.colorScheme.onTertiaryContainer),
        const SizedBox(width: Spacing.small),
        Expanded(
          child: Text(
            l10n.availabilityInactivityWarningTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onTertiaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _BannerDescription extends StatelessWidget {
  const _BannerDescription();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Text(
      l10n.availabilityInactivityWarningBody,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onTertiaryContainer,
      ),
    );
  }
}

class _BannerCta extends StatelessWidget {
  const _BannerCta({required this.onExtend});

  final VoidCallback onExtend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: OmdsPrimaryButton(
        key: InactivityWarningBanner.ctaKey,
        text: l10n.availabilityInactivityWarningCta,
        onTap: onExtend,
      ),
    );
  }
}
