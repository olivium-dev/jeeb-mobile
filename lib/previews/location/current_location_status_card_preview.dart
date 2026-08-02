/// Widget previews for [CurrentLocationStatusCard] — run with
/// `flutter widget-preview start`.
///
/// The card is the visible half of JEBV4-176 / Q-060: the change that stopped
/// the app silently pinning a pickup to `33.8886, 35.4955` whenever GPS was
/// off or denied. Its whole contract is "tell the truth about the device fix",
/// so the states below are its six [CurrentGpsStatus] values — one preview
/// each. The happy path (`resolved`) is the one state the customer is least
/// likely to be looking at when something goes wrong.
///
/// Its inputs are one enum, one bool and four callbacks — no cubit, no
/// repository, no `Geolocator` — so these previews are network-free and
/// plugin-free by construction, not merely by the guard in [jeebPreviewHost].
///
/// Two things about the host are load-bearing:
///
/// * **The width is a real widget, not just a canvas hint.** `size` on
///   [JeebPreview] sizes the canvas, but the render tests pump on the default
///   800x600 surface, where nothing is ever tight enough to break. [_hosted]
///   reproduces the real slot — a 390pt phone inside the `ListView` the screen
///   builds with `DeliveryCreateLayout.pagePadding`, i.e. 350pt of content
///   width — so both readings agree.
/// * **The spinner is frozen.** `resolving` renders an indeterminate
///   [CircularProgressIndicator], which never stops scheduling frames and would
///   hang the render tests' `pumpAndSettle` forever. [TickerMode] mutes it,
///   which also makes the canvas deterministic.
///
/// `test/features/location/client_location_screen_test.dart` pins the
/// screen-level contract (only a `resolved` fix makes Confirm tappable); these
/// previews cover the half that test cannot see — what each recovery panel
/// looks like at 390pt, mirrored in Arabic, and at the 200% ceiling — plus one
/// state the screen can reach and nobody has looked at: see
/// [currentLocationStatusCardServiceDisabledUnselected].
library;

import 'package:flutter/material.dart';

import '../../features/location/application/location_select_state.dart';
import '../../features/location/presentation/widgets/current_location_status_card.dart';
import '../../features/location/presentation/widgets/delivery_create_layout.dart';
import '../harness/jeeb_preview.dart';

/// Reference phone width, matching the rest of the preview folder. Minus the
/// screen's 20pt gutters this leaves the card the 350pt it really gets.
const double _phoneWidth = 390;

/// `idle` renders the option row and nothing else.
const Size _optionOnlyBox = Size(_phoneWidth, 130);

/// Option row + a one-line status row.
const Size _statusRowBox = Size(_phoneWidth, 170);

/// Option row + a recovery panel with BOTH CTAs (primary + "Try again").
const Size _recoveryBox = Size(_phoneWidth, 390);

/// Option row + a recovery panel with a single CTA.
const Size _recoverySingleBox = Size(_phoneWidth, 330);

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
void resetCurrentLocationStatusCardTaps() {
  for (final String key in currentLocationStatusCardTaps.keys.toList()) {
    currentLocationStatusCardTaps[key] = 0;
  }
}

void _bump(String key) =>
    currentLocationStatusCardTaps[key] = currentLocationStatusCardTaps[key]! + 1;

/// Drops the card into the slot the Client Location screen gives it: a 390pt
/// phone, inside a scrolling list with the shared page gutters.
///
/// The [ListView] is not decoration — it is what hands the card the unbounded
/// vertical constraint it has in production, so the panel shrink-wraps its
/// content here exactly as it does on device.
Widget _hosted(
  CurrentGpsStatus status, {
  bool selected = true,
  double width = _phoneWidth,
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
              onSelect: () => _bump('select'),
              onRetry: () => _bump('retry'),
              onOpenLocationSettings: () => _bump('locationSettings'),
              onOpenAppSettings: () => _bump('appSettings'),
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
@JeebPreview(group: 'location', name: 'Idle · no detail', size: _optionOnlyBox)
Widget currentLocationStatusCardIdle() => _hosted(CurrentGpsStatus.idle);

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
/// visible on the canvas because [_hosted] gives the card its real 350pt width.
@JeebPreview(group: 'location', name: 'Resolving · spinner', size: _statusRowBox)
Widget currentLocationStatusCardResolving() =>
    _hosted(CurrentGpsStatus.resolving);

/// The happy path: a REAL device coordinate is held and Confirm is unlocked.
///
/// This is the ONLY state in which a current-location request can be created
/// (`LocationSelectState.hasCurrentGps`), which is why the confirmation line
/// exists at all — before JEBV4-176 the card looked like this unconditionally
/// and lied about a Beirut fallback.
@JeebPreview(group: 'location', name: 'Resolved · real fix', size: _statusRowBox)
Widget currentLocationStatusCardResolved() =>
    _hosted(CurrentGpsStatus.resolved);

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
@JeebPreview(group: 'location', name: 'Permission denied · recovery', size: _recoveryBox)
Widget currentLocationStatusCardPermissionDenied() =>
    _hosted(CurrentGpsStatus.permissionDenied);

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
  size: _recoveryBox,
)
Widget currentLocationStatusCardServiceDisabledUnselected() =>
    _hosted(CurrentGpsStatus.serviceDisabled, selected: false);

/// The platform simply failed to produce a fix — the one recovery panel with a
/// SINGLE action.
///
/// `failed` passes no `onRetry`/`retryLabel`, so "Try again" is promoted from
/// the secondary text button to the primary pill and the second row disappears.
/// That makes this the shortest panel, and the state to check when a layout
/// assumption about "the panel has two buttons" creeps in.
@JeebPreview(group: 'location', name: 'Failed · retry only', size: _recoverySingleBox)
Widget currentLocationStatusCardFailed() => _hosted(CurrentGpsStatus.failed);
