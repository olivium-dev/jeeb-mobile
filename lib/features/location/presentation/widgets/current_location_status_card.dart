import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/location_select_state.dart';
import 'client_location_option_card.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';
import 'delivery_create_layout.dart';

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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// Reference phone width, matching the rest of the preview folder. Minus the
/// screen's 20pt gutters this leaves the card the 350pt it really gets.
const double _currentLocationStatusCardPhoneWidth = 390;

/// `idle` renders the option row and nothing else.
const Size _currentLocationStatusCardOptionOnlyBox = Size(_currentLocationStatusCardPhoneWidth, 130);

/// Option row + a one-line status row.
const Size _currentLocationStatusCardStatusRowBox = Size(_currentLocationStatusCardPhoneWidth, 170);

/// Option row + a recovery panel with BOTH CTAs (primary + "Try again").
const Size _currentLocationStatusCardRecoveryBox = Size(_currentLocationStatusCardPhoneWidth, 390);

/// Option row + a recovery panel with a single CTA.
const Size _currentLocationStatusCardRecoverySingleBox = Size(_currentLocationStatusCardPhoneWidth, 330);

/// Counters for the four injected callbacks.
/// Wiring them all to `() {}` would render identically whether or not the
final Map<String, int> currentLocationStatusCardTaps = <String, int>{
  'select': 0,
  'retry': 0,
  'locationSettings': 0,
  'appSettings': 0,
};

/// Resets [currentLocationStatusCardTaps]; the counters are top-level, so one
/// test's taps would otherwise leak into the next.
void currentLocationStatusCardResetTaps() {
  for (final String key in currentLocationStatusCardTaps.keys.toList()) {
    currentLocationStatusCardTaps[key] = 0;
  }
}

void _currentLocationStatusCardBump(String key) =>
    currentLocationStatusCardTaps[key] = currentLocationStatusCardTaps[key]! + 1;

/// Drops the card into the slot the Client Location screen gives it: a 390pt
/// phone, inside a scrolling list with the shared page gutters.
Widget _currentLocationStatusCardHosted(
  CurrentGpsStatus status, {
  bool selected = true,
  double width = _currentLocationStatusCardPhoneWidth,
}) {
  return TickerMode(
    enabled: false,
    child: Align(
      alignment: AlignmentDirectional.topCenter,
      child: SizedBox(
        width: width,
        child: ListView(
          padding: DeliveryCreateLayout.pagePadding,
          children: <Widget>[
            CurrentLocationStatusCard(
              status: status,
              selected: selected,
              onSelect: () => _currentLocationStatusCardBump('select'),
              onRetry: () => _currentLocationStatusCardBump('retry'),
              onOpenLocationSettings: () => _currentLocationStatusCardBump('locationSettings'),
              onOpenAppSettings: () => _currentLocationStatusCardBump('appSettings'),
            ),
          ],
        ),
      ),
    ),
  );
}

/// No acquisition attempted yet — the option row alone, with no detail at all.
/// `idle` is what an isolated host without a GPS resolver leaves the state at
@JeebPreview(group: 'location', name: 'Idle · no detail', size: _currentLocationStatusCardOptionOnlyBox)
Widget currentLocationStatusCardIdle() => _currentLocationStatusCardHosted(CurrentGpsStatus.idle);

/// Acquiring a fix: the permission prompt is up, or the sensor is being read.
/// The progress row is a `liveRegion` [Semantics] node, so a screen reader
@JeebPreview(group: 'location', name: 'Resolving · spinner', size: _currentLocationStatusCardStatusRowBox)
Widget currentLocationStatusCardResolving() =>
    _currentLocationStatusCardHosted(CurrentGpsStatus.resolving);

/// The happy path: a REAL device coordinate is held and Confirm is unlocked.
/// This is the ONLY state in which a current-location request can be created
@JeebPreview(group: 'location', name: 'Resolved · real fix', size: _currentLocationStatusCardStatusRowBox)
Widget currentLocationStatusCardResolved() =>
    _currentLocationStatusCardHosted(CurrentGpsStatus.resolved);

/// Permission denied — the recovery panel, and the tallest shape this card
/// renders: icon + title + two-line message + a primary CTA + a "Try again".
@JeebPreview(group: 'location', name: 'Permission denied · recovery', size: _currentLocationStatusCardRecoveryBox)
Widget currentLocationStatusCardPermissionDenied() =>
    _currentLocationStatusCardHosted(CurrentGpsStatus.permissionDenied);

/// Device location services are off — same panel shape, different destination:
/// the OS location toggle rather than the app's permission page.
@JeebPreview(group: 'location', 
  name: 'Services off · unselected (panel persists)',
  size: _currentLocationStatusCardRecoveryBox,
)
Widget currentLocationStatusCardServiceDisabledUnselected() =>
    _currentLocationStatusCardHosted(CurrentGpsStatus.serviceDisabled, selected: false);

/// The platform simply failed to produce a fix — the one recovery panel with a
/// SINGLE action.
@JeebPreview(group: 'location', name: 'Failed · retry only', size: _currentLocationStatusCardRecoverySingleBox)
Widget currentLocationStatusCardFailed() => _currentLocationStatusCardHosted(CurrentGpsStatus.failed);
