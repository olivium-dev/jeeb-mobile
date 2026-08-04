import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../../core/widgets/jeeb/jeeb_surface_tone.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/location_select_state.dart';
import 'client_location_option_card.dart';

/// The "Current Location" option plus its honest GPS-acquisition state
/// (JEBV4-176 / Q-060).
///
/// This REPLACES the old silent Beirut fallback. Instead of always presenting
/// "Current Location" as a confirmable safe default (which quietly created
/// requests pinned to `33.8886, 35.4955` when GPS was off/denied), the card
/// reflects the real acquisition lifecycle and, when the device cannot yield a
/// fix, offers the correct recovery affordance:
///
///   * [CurrentGpsStatus.resolving] → a "finding your location" progress row;
///   * [CurrentGpsStatus.resolved] → a confirmation the real fix is in use
///     (with its accuracy radius when the sensor reported one);
///   * [CurrentGpsStatus.permissionDenied] → "open app settings" + retry;
///   * [CurrentGpsStatus.serviceDisabled] → "turn on location" + retry;
///   * [CurrentGpsStatus.failed] → retry.
///
/// Redesign 09: the resolving/resolved lines render INSIDE the option card's
/// subtitle slot (the board's address card is icon + title + meta line); the
/// multi-CTA recovery panel keeps its own block below the card, because two
/// buttons do not fit inside a list card.
///
/// All copy is localized (RTL-safe) and every measurement is a design token.
class CurrentLocationStatusCard extends StatelessWidget {
  const CurrentLocationStatusCard({
    super.key,
    required this.status,
    required this.selected,
    required this.onSelect,
    required this.onRetry,
    required this.onOpenLocationSettings,
    required this.onOpenAppSettings,
    this.accuracyMeters,
  });

  final CurrentGpsStatus status;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onRetry;
  final VoidCallback onOpenLocationSettings;
  final VoidCallback onOpenAppSettings;

  /// Horizontal accuracy of the resolved device fix, in metres. Null when the
  /// platform reported none — the subtitle then falls back to the plain
  /// "using your current location" line. Device sensor value only.
  final double? accuracyMeters;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final detail = _belowCardDetail(l10n);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClientLocationOptionCard(
          label: l10n.clientLocationCurrentOption,
          selected: selected,
          onTap: onSelect,
          subtitle: _inCardDetail(l10n),
        ),
        ?detail,
      ],
    );
  }

  /// The lines that belong in the card's subtitle slot. They keep their OWN
  /// Semantics nodes (`current_location_gps_resolving` / `_resolved`), which
  /// survive because the card's wrapper is `explicitChildNodes`.
  Widget? _inCardDetail(AppLocalizations l10n) {
    switch (status) {
      case CurrentGpsStatus.resolving:
        return _Resolving(label: l10n.clientLocationGpsResolving);
      case CurrentGpsStatus.resolved:
        final meters = accuracyMeters;
        return _Resolved(
          label: meters == null
              ? l10n.clientLocationGpsResolved
              : l10n.clientLocationGpsAccuracy(meters.round()),
        );
      case CurrentGpsStatus.idle:
      case CurrentGpsStatus.permissionDenied:
      case CurrentGpsStatus.serviceDisabled:
      case CurrentGpsStatus.failed:
        return null;
    }
  }

  /// The recovery panel, which is a two-CTA block and therefore sits BELOW the
  /// card rather than inside it.
  Widget? _belowCardDetail(AppLocalizations l10n) {
    switch (status) {
      case CurrentGpsStatus.idle:
      case CurrentGpsStatus.resolving:
      case CurrentGpsStatus.resolved:
        return null;
      case CurrentGpsStatus.permissionDenied:
        return _Recovery(
          identifier: 'current_location_gps_recovery',
          icon: Icons.location_disabled,
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
          icon: Icons.location_off,
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
          icon: Icons.gps_off,
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
    // The host card publishes its own meta ink, so rest glass and the selected
    // emphasis fill each get the right muted step with nothing to remember.
    final ink = JeebSurfaceTone.of(context).mutedInk;
    return Semantics(
      identifier: 'current_location_gps_resolving',
      liveRegion: true,
      child: Row(
        children: [
          SizedBox(
            width: Sizes.medium,
            height: Sizes.medium,
            child: CircularProgressIndicator(
              strokeWidth: UIConstants.strokeWidthNormal,
              color: ink,
            ),
          ),
          const SizedBox(width: Spacing.xSmall),
          Expanded(
            child: Text(
              label,
              style: context.jeebText.bodySmall.copyWith(color: ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _Resolved extends StatelessWidget {
  const _Resolved({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ink = JeebSurfaceTone.of(context).mutedInk;
    return Semantics(
      identifier: 'current_location_gps_resolved',
      child: Text(
        label,
        style: context.jeebText.bodySmall.copyWith(color: ink),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// A recovery panel: icon + title + message + a primary CTA and an optional
/// "try again" text action. Used for the denied / services-off / failed states.
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
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: identifier,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(top: Spacing.small),
        child: JeebOutlinedCard(
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
                    style: context.jeebText.cardTitle
                        .copyWith(color: scheme.onSurface),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.xSmall),
            Text(
              message,
              style: context.jeebText.body
                  .copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: Spacing.medium),
            Semantics(
              identifier: 'current_location_gps_primary_cta',
              button: true,
              child: JeebCtaButton.primary(
                label: primaryLabel,
                onTap: onPrimary,
              ),
            ),
            if (onRetry != null && retryLabel != null) ...[
              const SizedBox(height: Spacing.xSmall),
              Semantics(
                identifier: 'current_location_gps_retry_cta',
                button: true,
                child: JeebCtaButton.text(
                  label: retryLabel!,
                  expand: true,
                  onTap: onRetry!,
                ),
              ),
            ],
          ],
        ),
        ),
      ),
    );
  }
}
