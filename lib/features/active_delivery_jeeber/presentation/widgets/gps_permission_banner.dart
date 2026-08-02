import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';
import '../../domain/jeeber_delivery_status.dart';
import 'delivery_status_stepper.dart';

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
// ============================== JEEB PREVIEWS ==============================
// One boolean + two callbacks. Boolean swaps copy + CTA (retry vs settings open).

/// Phone width (390 dp).
const double _gpsPermissionBannerPhoneWidth = 390;

/// Small phone width (320 dp).
const double _gpsPermissionBannerSmallPhoneWidth = 320;

/// Banner host at pinned width (scroll container, unbounded height).
Widget _gpsPermissionBannerHosted({
  required bool needsSystemSettings,
  double width = _gpsPermissionBannerPhoneWidth,
}) {
  return Align(
    alignment: AlignmentDirectional.topStart,
    child: SizedBox(
      width: width,
      child: SingleChildScrollView(
        child: GpsPermissionBanner(
          needsSystemSettings: needsSystemSettings,
          onOpenSettings: () {},
          onRetry: () {},
        ),
      ),
    ),
  );
}

/// Recoverable denial (CTA worth tapping: "Allow location", retry escalation).
@JeebPreview(
  group: 'active_delivery_jeeber',
  name: 'Recoverable denial',
  size: Size(_gpsPermissionBannerPhoneWidth, 240),
)
Widget gpsPermissionBannerRecoverable() =>
    _gpsPermissionBannerHosted(needsSystemSettings: false);

/// Needs system settings (permanent denial or Android 11+ upgrade).
@JeebPreview(
  group: 'active_delivery_jeeber',
  name: 'Needs system settings',
  size: Size(_gpsPermissionBannerPhoneWidth, 280),
)
Widget gpsPermissionBannerNeedsSystemSettings() =>
    _gpsPermissionBannerHosted(needsSystemSettings: true);

/// Small phone 320dp (longest copy, worst CTA break: 117 px overflow @ 200%).
@JeebPreview(
  group: 'active_delivery_jeeber',
  name: 'Small phone 320dp',
  size: Size(_gpsPermissionBannerSmallPhoneWidth, 340),
)
Widget gpsPermissionBannerSmallPhone() => _gpsPermissionBannerHosted(
      needsSystemSettings: true,
      width: _gpsPermissionBannerSmallPhoneWidth,
    );

/// Production: first item in delivery ListView (padded, 358 dp of 390 dp).
@JeebPreview(
  group: 'active_delivery_jeeber',
  name: 'First item in delivery list',
  size: Size(_gpsPermissionBannerPhoneWidth, 560),
)
Widget gpsPermissionBannerInDeliveryList() => Align(
      alignment: AlignmentDirectional.topStart,
      child: SizedBox(
        width: _gpsPermissionBannerPhoneWidth,
        child: Builder(
          builder: (BuildContext context) {
            final AppLocalizations l10n = AppLocalizations.of(context);
            return ListView(
              padding: const EdgeInsets.all(Spacing.medium),
              children: <Widget>[
                GpsPermissionBanner(
                  needsSystemSettings: false,
                  onOpenSettings: () {},
                  onRetry: () {},
                ),
                const SizedBox(height: Spacing.large),
                OMDSSectionCard(
                  title: l10n.activeDeliveryProgressTitle,
                  showDivider: false,
                  content: DeliveryStatusStepper(
                    currentStatus: JeeberDeliveryStatus.inTransit,
                    isTransitioning: false,
                    onAdvance: () {},
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
