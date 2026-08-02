import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/location_select_state.dart';
import 'client_location_option_card.dart';

class CurrentLocationStatusCard extends StatelessWidget {
  const CurrentLocationStatusCard({
    super.key,
    required this.status,
    required this.selected,
    required this.onSelect,
    required this.onRetry,
    required this.onOpenLocationSettings,
    required this.onOpenAppSettings,
  });

  final CurrentGpsStatus status;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onRetry;
  final VoidCallback onOpenLocationSettings;
  final VoidCallback onOpenAppSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClientLocationOptionCard(
          label: l10n.clientLocationCurrentOption,
          selected: selected,
          onTap: onSelect,
        ),
        _detail(context, l10n),
      ],
    );
  }

  Widget _detail(BuildContext context, AppLocalizations l10n) {
    switch (status) {
      case CurrentGpsStatus.idle:
        return const SizedBox.shrink();
      case CurrentGpsStatus.resolving:
        return _Resolving(label: l10n.clientLocationGpsResolving);
      case CurrentGpsStatus.resolved:
        return _Resolved(label: l10n.clientLocationGpsResolved);
      case CurrentGpsStatus.permissionDenied:
        return _Recovery(
          identifier: 'current_location_gps_recovery',
          icon: Icons.location_disabled_outlined,
          title: l10n.clientLocationGpsPermissionDeniedTitle,
          message: l10n.clientLocationGpsPermissionDeniedMessage,
          primaryLabel: l10n.clientLocationGpsOpenAppSettings,
          onPrimary: onOpenAppSettings,
          onRetry: onRetry,
          retryLabel: l10n.clientLocationGpsRetry,
        );
      case CurrentGpsStatus.serviceDisabled:
        return _Recovery(
          identifier: 'current_location_gps_recovery',
          icon: Icons.location_off_outlined,
          title: l10n.clientLocationGpsServiceDisabledTitle,
          message: l10n.clientLocationGpsServiceDisabledMessage,
          primaryLabel: l10n.clientLocationGpsOpenLocationSettings,
          onPrimary: onOpenLocationSettings,
          onRetry: onRetry,
          retryLabel: l10n.clientLocationGpsRetry,
        );
      case CurrentGpsStatus.failed:
        return _Recovery(
          identifier: 'current_location_gps_recovery',
          icon: Icons.gps_off_outlined,
          title: l10n.clientLocationGpsFailedTitle,
          message: l10n.clientLocationGpsFailedMessage,
          primaryLabel: l10n.clientLocationGpsRetry,
          onPrimary: onRetry,
        );
    }
  }
}

class _Resolving extends StatelessWidget {
  const _Resolving({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'current_location_gps_resolving',
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          top: Spacing.small,
          start: Spacing.xSmall,
        ),
        child: Row(
          children: [
            SizedBox(
              width: Sizes.medium,
              height: Sizes.medium,
              child: CircularProgressIndicator(
                strokeWidth: UIConstants.strokeWidthNormal,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: Spacing.small),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Resolved extends StatelessWidget {
  const _Resolved({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'current_location_gps_resolved',
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          top: Spacing.small,
          start: Spacing.xSmall,
        ),
        child: Row(
          children: [
            Icon(
              Icons.my_location_outlined,
              size: Sizes.medium,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: Spacing.small),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Recovery extends StatelessWidget {
  const _Recovery({
    required this.identifier,
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.onRetry,
    this.retryLabel,
  });

  final String identifier;
  final IconData icon;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      identifier: identifier,
      child: Container(
        margin: const EdgeInsetsDirectional.only(top: Spacing.small),
        padding: const EdgeInsets.all(Spacing.medium),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: OmdsBorderRadius.uiLarge,
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: Sizes.large, color: scheme.error),
                const SizedBox(width: Spacing.small),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.xSmall),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Spacing.medium),
            Semantics(
              identifier: 'current_location_gps_primary_cta',
              button: true,
              child: OmdsPrimaryButton(
                text: primaryLabel,
                onTap: onPrimary,
                borderRadius: OmdsBorderRadius.pill,
              ),
            ),
            if (onRetry != null && retryLabel != null) ...[
              const SizedBox(height: Spacing.xSmall),
              Semantics(
                identifier: 'current_location_gps_retry_cta',
                button: true,
                child: OmdsPrimaryButton(
                  text: retryLabel!,
                  onTap: onRetry!,
                  variant: OmdsButtonVariant.text,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
