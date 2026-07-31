import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

/// Loud, user-visible notice that the jeeber's live-GPS uploader is PARKED on
/// a missing background-location grant — so the customer's tracking map is
/// receiving nothing.
///
/// ## Why this exists
///
/// The uploader could already park itself
/// ([BackgroundGpsPhase.permissionDenied]) and did so on **every** delivery,
/// because `ACCESS_BACKGROUND_LOCATION` was never declared in the manifest and
/// geolocator therefore could not report `always` on Android 10+. The manifest
/// line fixes the cause. This banner fixes the far more expensive half: the
/// park was **silent**. No log, no UI, no difference of any kind between a
/// jeeber whose position was streaming and one whose position had never left
/// the phone. The bug survived months of hands-on testing for exactly that
/// reason.
///
/// So this widget is not decoration and must not be made dismissible or
/// conditional on a "don't show again" flag: while it is on screen, a core
/// product promise (the customer watching the courier approach) is broken, and
/// only the jeeber can repair it.
///
/// ## CTA choice is load-bearing
///
/// Android 11+ does **not** grant "Allow all the time" from an in-app dialog —
/// the platform routes that upgrade through the app's system settings page, and
/// a permanent denial cannot be re-prompted at all. So when
/// [needsSystemSettings] is true the primary CTA opens settings; offering
/// "Try again" there would fire a request the OS silently drops, which would
/// re-create the original defect one layer up.
///
/// ## OMDS
///
/// OMDS exports no flat notice-strip primitive (`OMDSProgressBanner` is a
/// progress-ring card, not this band), so — exactly as `ChatFeeBanner` does —
/// the band is composed from OMDS tokens (`Spacing`, `Sizes`,
/// `OmdsBorderRadius`, the M3 `ColorScheme` roles) with an OMDS button for the
/// CTA. No raw Material widget that has an OMDS equivalent is used, and the
/// shared OMDS library is not edited.
class GpsPermissionBanner extends StatelessWidget {
  const GpsPermissionBanner({
    super.key,
    required this.needsSystemSettings,
    required this.onOpenSettings,
    required this.onRetry,
  });

  /// True when only the OS settings page can help — a permanent denial, or the
  /// Android 11+ "Allow all the time" upgrade. Selects which CTA is shown.
  final bool needsSystemSettings;

  /// Opens this app's OS settings page.
  final VoidCallback onOpenSettings;

  /// Re-runs the in-app permission escalation.
  final VoidCallback onRetry;

  /// Stable handle for widget tests and Maestro flows.
  static const Key bannerKey = Key('active-delivery-gps-permission-banner');

  /// Semantics identifier — the id a Maestro `tapOn: { id: … }` matches and the
  /// id the `[jeeb-diag]` gesture recorder reports.
  static const String semanticsId = 'active_delivery_gps_permission_banner';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: semanticsId,
      // NOT a merging container: the CTA below must keep its own independently
      // addressable button node, or a flow can see the banner and be unable to
      // act on it (the same selector gap ChatFeeBanner documents).
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
  const _Cta({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: OMDSOutlinedButton(
        identifier: 'active_delivery_gps_permission_cta',
        text: label,
        onTap: onTap,
      ),
    );
  }
}
