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
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/location/current_location_status_card_preview_test.dart
// ===========================================================================
// Widget previews for [CurrentLocationStatusCard] — run with
// `flutter widget-preview start`.
//
// The card is the visible half of JEBV4-176 / Q-060: the change that stopped
// the app silently pinning a pickup to `33.8886, 35.4955` whenever GPS was
// off or denied. Its whole contract is "tell the truth about the device fix",
// so the states below are its six [CurrentGpsStatus] values — one preview
// each. The happy path (`resolved`) is the one state the customer is least
// likely to be looking at when something goes wrong.
//
// Its inputs are one enum, one bool and four callbacks — no cubit, no
// repository, no `Geolocator` — so these previews are network-free and
// plugin-free by construction, not merely by the guard in [jeebPreviewHost].
//
// Two things about the host are load-bearing:
//
// * **The width is a real widget, not just a canvas hint.** `size` on
//   [JeebPreview] sizes the canvas, but the render tests pump on the default
//   800x600 surface, where nothing is ever tight enough to break. [_currentLocationStatusCardHosted]
//   reproduces the real slot — a 390pt phone inside the `ListView` the screen
//   builds with `DeliveryCreateLayout.pagePadding`, i.e. 350pt of content
//   width — so both readings agree.
// * **The spinner is frozen.** `resolving` renders an indeterminate
//   [CircularProgressIndicator], which never stops scheduling frames and would
//   hang the render tests' `pumpAndSettle` forever. [TickerMode] mutes it,
//   which also makes the canvas deterministic.
//
// `test/features/location/client_location_screen_test.dart` pins the
// screen-level contract (only a `resolved` fix makes Confirm tappable); these
// previews cover the half that test cannot see — what each recovery panel
// looks like at 390pt, mirrored in Arabic, and at the 200% ceiling — plus one
// state the screen can reach and nobody has looked at: see
// [currentLocationStatusCardServiceDisabledUnselected].

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
///
/// Wiring them all to `() {}` would render identically whether or not the
/// right CTA reaches the right handler — and the two recovery panels differ
/// mostly in exactly that: `permissionDenied` must open APP settings while
/// `serviceDisabled` must open LOCATION settings. A swap is invisible on the
/// canvas, so the render test taps each panel and asserts these move.
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
///
/// The [ListView] is not decoration — it is what hands the card the unbounded
/// vertical constraint it has in production, so the panel shrink-wraps its
/// content here exactly as it does on device.
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
///
/// `idle` is what an isolated host without a GPS resolver leaves the state at
/// (`LocationSelectCubit.resolveCurrentGps` returns early when `_resolver` is
/// null), and it is the first frame of every real session too.
///
/// It is worth a preview precisely because it renders `SizedBox.shrink()`: the
/// customer sees "Current Location" sitting there selected, with no spinner, no
/// coordinate and no explanation — while `canConfirm` is false underneath and
/// the Confirm CTA is disabled. Nothing on this card says why. Compare
/// [currentLocationStatusCardResolving], which is the same selection with an
/// honest progress row.
///
/// With no detail below it this is also the cleanest look at the option row
/// itself, and at the second thing the **EN 200% text** rendering exposes:
/// `ClientLocationOptionCard`'s label is a single ellipsized line inside an
/// `Expanded`, so it cannot wrap and cannot grow the row — past a certain scale
/// the option just reads "Current Locat…".
@JeebPreview(group: 'location', name: 'Idle · no detail', size: _currentLocationStatusCardOptionOnlyBox)
Widget currentLocationStatusCardIdle() => _currentLocationStatusCardHosted(CurrentGpsStatus.idle);

/// Acquiring a fix: the permission prompt is up, or the sensor is being read.
///
/// The progress row is a `liveRegion` [Semantics] node, so a screen reader
/// announces it when it appears — the only state here that speaks for itself.
///
/// Two things to look at. The spinner is a fixed 16pt box (`Sizes.medium`)
/// beside a `bodyMedium` label; in **EN 200% text** the label wraps and the
/// spinner does not grow with it, so the row stops reading as one unit — the
/// same fixed-glyph-beside-scaling-text pattern the recovery header repeats.
/// And the row's padding is `EdgeInsetsDirectional.only(top:, start:)` with no
/// `end`, so the label runs flush to the card's trailing edge while the option
/// row above it keeps 16pt of internal padding on both sides. Both edges are
/// visible on the canvas because [_currentLocationStatusCardHosted] gives the card its real 350pt width.
@JeebPreview(group: 'location', name: 'Resolving · spinner', size: _currentLocationStatusCardStatusRowBox)
Widget currentLocationStatusCardResolving() =>
    _currentLocationStatusCardHosted(CurrentGpsStatus.resolving);

/// The happy path: a REAL device coordinate is held and Confirm is unlocked.
///
/// This is the ONLY state in which a current-location request can be created
/// (`LocationSelectState.hasCurrentGps`), which is why the confirmation line
/// exists at all — before JEBV4-176 the card looked like this unconditionally
/// and lied about a Beirut fallback.
@JeebPreview(group: 'location', name: 'Resolved · real fix', size: _currentLocationStatusCardStatusRowBox)
Widget currentLocationStatusCardResolved() =>
    _currentLocationStatusCardHosted(CurrentGpsStatus.resolved);

/// Permission denied — the recovery panel, and the tallest shape this card
/// renders: icon + title + two-line message + a primary CTA + a "Try again".
///
/// The primary CTA must reach `onOpenAppSettings` (the app's own permission
/// page), NOT `onOpenLocationSettings`; the two panels are otherwise so alike
/// that a swapped handler would look perfectly correct here. The render test
/// pins the wiring.
///
/// Watch the CTAs in the **EN 200% text** rendering. `OmdsPrimaryButton` pins
/// its height to a fixed 48pt (`Sizes.fourXLarge`) and centres the label inside
/// it; the label follows the text scaler and the pill does not. Once the label
/// wraps it needs 80pt and gets 48, so "Open settings" is cut — on the panel
/// whose entire purpose is telling a blocked customer how to unblock
/// themselves. The render test measures exactly that, at 200% on a 390pt phone;
/// the wrap threshold there is pessimistic (the `FlutterTest` font is wider than
/// the shipped one) but the ceiling is structural — a 48pt box cannot hold two
/// scaled lines in any font.
@JeebPreview(group: 'location', name: 'Permission denied · recovery', size: _currentLocationStatusCardRecoveryBox)
Widget currentLocationStatusCardPermissionDenied() =>
    _currentLocationStatusCardHosted(CurrentGpsStatus.permissionDenied);

/// Device location services are off — same panel shape, different destination:
/// the OS location toggle rather than the app's permission page.
///
/// Rendered here with `selected: false`, which is the state nobody has looked
/// at: `_detail` switches on `status` ALONE and never consults `selected`, and
/// `LocationSelectCubit.selectSaved` does not clear `currentGpsStatus`. So a
/// customer whose GPS is off, who then picks a saved address, keeps this whole
/// error panel — error-colored icon, "Turn on location" CTA — pinned under an
/// unselected option they have already worked around. This preview is the
/// unselected option chrome (white surface, navy outline) and that defect in
/// one frame.
@JeebPreview(group: 'location', 
  name: 'Services off · unselected (panel persists)',
  size: _currentLocationStatusCardRecoveryBox,
)
Widget currentLocationStatusCardServiceDisabledUnselected() =>
    _currentLocationStatusCardHosted(CurrentGpsStatus.serviceDisabled, selected: false);

/// The platform simply failed to produce a fix — the one recovery panel with a
/// SINGLE action.
///
/// `failed` passes no `onRetry`/`retryLabel`, so "Try again" is promoted from
/// the secondary text button to the primary pill and the second row disappears.
/// That makes this the shortest panel, and the state to check when a layout
/// assumption about "the panel has two buttons" creeps in.
@JeebPreview(group: 'location', name: 'Failed · retry only', size: _currentLocationStatusCardRecoverySingleBox)
Widget currentLocationStatusCardFailed() => _currentLocationStatusCardHosted(CurrentGpsStatus.failed);
