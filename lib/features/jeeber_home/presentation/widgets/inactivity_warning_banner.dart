import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

/// Banner shown 30 minutes before the 8h auto-offline kicks in.
///
/// Tapping the CTA fires [onExtend] which resets the idle timer in the
/// cubit; dismissing it does NOT extend (the warning re-appears next tick).
class InactivityWarningBanner extends StatelessWidget {
  const InactivityWarningBanner({
    super.key,
    required this.onExtend,
  });

  static const Key rootKey = Key('availability-inactivity-banner-root');
  static const Key ctaKey = Key('availability-inactivity-banner-cta');

  final VoidCallback onExtend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      key: rootKey,
      margin: const EdgeInsets.symmetric(horizontal: Spacing.medium),
      padding: const EdgeInsets.all(Spacing.medium),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(Sizes.medium),
        border: Border.all(color: colorScheme.tertiary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.access_time, color: colorScheme.onTertiaryContainer),
              const SizedBox(width: Spacing.small),
              Expanded(
                child: Text(
                  l10n.availabilityInactivityWarningTitle,
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xSmall),
          Text(
            l10n.availabilityInactivityWarningBody,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onTertiaryContainer,
            ),
          ),
          const SizedBox(height: Spacing.small),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: OmdsPrimaryButton(
              key: ctaKey,
              text: l10n.availabilityInactivityWarningCta,
              onTap: onExtend,
            ),
          ),
        ],
      ),
    );
  }
}
