import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

/// Error state shown when location permission is denied (T-MOB-012 AC4).
///
/// Renders an icon + copy and an "Open Settings" CTA. Opening native app
/// settings requires a platform-level plugin; the CTA is wired through
/// the [onOpenSettings] callback so the host (screen or test) decides
/// the exact platform call. The default is a no-op — production hosts
/// pass `() => AppSettings.openAppSettings()` (once the dependency is added).
class GpsDeniedState extends StatelessWidget {
  const GpsDeniedState({super.key, this.onOpenSettings});

  /// Callback invoked when the user taps "Open Settings".
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.xLarge,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIcon(colorScheme),
            const SizedBox(height: Spacing.medium),
            _buildTitle(context, l10n),
            const SizedBox(height: Spacing.xSmall),
            _buildBody(context, l10n, colorScheme),
            const SizedBox(height: Spacing.large),
            _buildCta(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(ColorScheme colorScheme) {
    return Icon(
      Icons.location_off_rounded,
      size: Sizes.fiveXLarge,
      color: colorScheme.error,
    );
  }

  Widget _buildTitle(BuildContext context, AppLocalizations l10n) {
    return Text(
      l10n.captureLocationGpsDeniedTitle,
      style: Theme.of(context).textTheme.titleMedium,
      textAlign: TextAlign.center,
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return Text(
      l10n.captureLocationGpsDeniedBody,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildCta(AppLocalizations l10n) {
    return OmdsPrimaryButton(
      text: l10n.captureLocationGpsDeniedOpenSettings,
      isEnabled: onOpenSettings != null,
      onTap: () => onOpenSettings?.call(),
    );
  }
}
