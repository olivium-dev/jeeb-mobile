import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

class GpsPermissionBanner extends StatelessWidget {
  const GpsPermissionBanner({
    super.key,
    required this.needsSystemSettings,
    required this.onOpenSettings,
    required this.onRetry,
  });

  final bool needsSystemSettings;

  final VoidCallback onOpenSettings;

  final VoidCallback onRetry;

  static const Key bannerKey = Key('active-delivery-gps-permission-banner');

  static const String semanticsId = 'active_delivery_gps_permission_banner';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: semanticsId,
      explicitChildNodes: true,
      child: Container(
        key: bannerKey,
        width: double.infinity,
        padding: const EdgeInsetsDirectional.all(Spacing.medium),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: OmdsBorderRadius.medium,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Headline(l10n: l10n, colorScheme: colorScheme),
            const SizedBox(height: Spacing.xSmall),
            Text(
              needsSystemSettings
                  ? l10n.activeDeliveryGpsBannerBodySettings
                  : l10n.activeDeliveryGpsBannerBody,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: colorScheme.onErrorContainer),
            ),
            const SizedBox(height: Spacing.small),
            _Cta(
              label: needsSystemSettings
                  ? l10n.activeDeliveryGpsBannerOpenSettings
                  : l10n.activeDeliveryGpsBannerRetry,
              onTap: needsSystemSettings ? onOpenSettings : onRetry,
              colorScheme: colorScheme,
            ),
          ],
        ),
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.l10n, required this.colorScheme});

  final AppLocalizations l10n;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.location_off_outlined,
          color: colorScheme.onErrorContainer,
          size: Sizes.large,
        ),
        const SizedBox(width: Spacing.xSmall),
        Expanded(
          child: Text(
            l10n.activeDeliveryGpsBannerTitle,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}

class _Cta extends StatelessWidget {
  const _Cta({
    required this.label,
    required this.onTap,
    required this.colorScheme,
  });

  final String label;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: OMDSOutlinedButton(
        identifier: 'active_delivery_gps_permission_cta',
        text: label,
        onTap: onTap,
        backgroundColor: colorScheme.onErrorContainer,
        textColor: colorScheme.errorContainer,
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.large,
          vertical: Spacing.small,
        ),
      ),
    );
  }
}
