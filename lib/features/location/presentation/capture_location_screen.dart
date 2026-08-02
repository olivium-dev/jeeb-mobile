import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import 'widgets/capture_location_pin.dart';
import 'widgets/capture_map_viewport.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/capture_location_screen_fixtures.dart';

class CaptureLocationScreen extends StatelessWidget {
  const CaptureLocationScreen({
    super.key,
    this.onPinned,
    this.mapBuilder,
    this.isConfirming = false,
  });

  final VoidCallback? onPinned;

  final WidgetBuilder? mapBuilder;

  final bool isConfirming;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: OMDSAppBar(
        title: l10n.captureLocationTitle,
        showBackButton: true,
        onBackPressed: () => Navigator.of(context).maybePop(),
      ),
      body: SafeArea(
        child: _Body(
          mapBuilder: mapBuilder,
          onPinned: onPinned,
          isConfirming: isConfirming,
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.mapBuilder,
    required this.onPinned,
    required this.isConfirming,
  });

  final WidgetBuilder? mapBuilder;
  final VoidCallback? onPinned;
  final bool isConfirming;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _MapStack(mapBuilder: mapBuilder)),
        _PinCta(onPinned: onPinned, isConfirming: isConfirming),
      ],
    );
  }
}

class _PinCta extends StatelessWidget {
  const _PinCta({required this.onPinned, required this.isConfirming});

  final VoidCallback? onPinned;
  final bool isConfirming;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.large,
        Spacing.medium,
        Spacing.large,
        Spacing.medium,
      ),
      child: Semantics(
        identifier: 'capture_location_pin_cta',
        button: true,
        child: OmdsPrimaryButton(
          text: l10n.captureLocationPinCta,
          isEnabled: !isConfirming,
          onTap: () => _onPin(context),
        ),
      ),
    );
  }

  void _onPin(BuildContext context) {
    final handler = onPinned;
    if (handler != null) {
      handler();
    } else {
      Navigator.of(context).maybePop();
    }
  }
}

class _MapStack extends StatelessWidget {
  const _MapStack({required this.mapBuilder});

  final WidgetBuilder? mapBuilder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        Semantics(
          identifier: 'capture_location_map',
          label: l10n.captureLocationMapSemantic,
          child: mapBuilder?.call(context) ?? const CaptureMapViewport(),
        ),
        const Center(child: CaptureLocationPin()),
      ],
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
// Render tests: test/previews/location/capture_location_screen_preview_test.dart
// ===========================================================================
//
// Widget previews for [CaptureLocationScreen] — run with
// `flutter widget-preview start`.
//
// This is a SCREEN, so two things differ from the widget previews elsewhere in
// this feature.
//
// First, the map. Production injects `GoogleMapCaptureView` — a
// `google_maps_flutter` platform view — through [CaptureLocationScreen.mapBuilder].
// A platform view renders nothing headless and needs a key plus billed tiles on
// a device, so every state below is built from the shared stand-ins in
// `lib/devtool/catalog/fixtures/capture_location_screen_fixtures.dart`. They
// are the same fixtures a Screen Catalog entry for this screen would use (there
// is none today), so the two dev surfaces cannot drift into two different fake
// maps. There is no cubit and no repository anywhere in this screen — its whole
// input surface is three constructor arguments — so these previews are
// network-free by construction, not merely because [jeebPreviewHost] guards the
// wire.
//
// Second, the Scaffold. [jeebPreviewHost] wraps every preview in
// `Scaffold(body: SafeArea(...))` and this screen brings its own, so the canvas
// really does render two — an unavoidable consequence of previewing a screen
// through a host built for widgets. It costs a second [SafeArea] inset on a
// notched canvas and nothing else; the app bar, map and CTA lay out exactly as
// they do in the app. The annotation sizes are real devices (390×844,
// 320×568) rather than the harness default so what is on screen is what a user
// would see.
//
// **About the captions.** Three of the six states below render identical
// product copy — the screen's own text is an app-bar title and a CTA label,
// neither of which varies — so each state is captioned with the scenario it
// stands for, and the render test addresses those states by their caption. The
// captions are deliberately unlocalized: they name the *state*, not the
// product, and English in the AR rendering is expected. The caption strip also
// carries a live tally of confirmed pins, which is what lets the canvas (and
// the test) tell a CTA that fires from one that only looks like it does.
//
// What these previews put on screen, all of it in the screen rather than in the
// previews:
//
//  * "Pin Location" is enabled whenever [CaptureLocationScreen.isConfirming] is
//    false, and nothing else can disable it — so the state that ships today,
//    [captureLocationScreenPlaceholderMap], offers a live primary CTA over a
//    placeholder that cannot pan and has no coordinate to give
//    (`CaptureLocationRoute` pops without one, JEBV4-176);
//  * the screen has no denied / failed / out-of-area state, so a host can only
//    reach one through `mapBuilder` — and the fixed centre pin then floats over
//    the error copy with a live CTA underneath, which is exactly what
//    [captureLocationScreenPermissionDenied] and
//    [captureLocationScreenOutsideServiceArea] show;
//  * [CaptureLocationScreen.isConfirming] documents "a busy state", but it only
//    flips `isEnabled`: no spinner, no copy change, and the map, the pin and
//    the back button all stay live — [captureLocationScreenConfirming].

/// The canvas box for a phone: the device the screen is designed against
/// (Figma 56546:2303).
const Size _captureLocationScreenPhoneBox = Size(390, 844);

/// The narrowest device the app still supports.
const Size _captureLocationScreenCompactBox = Size(320, 568);

/// The scenario label, plus a live tally of confirmed pins.
///
/// Pinned to [TextScaler.noScaling]: this is preview chrome, and if it grew
/// with the text scaler it would take room from the screen in the
/// `EN 200% text` rendering and take the blame for whatever broke there.
class _CaptureLocationScreenCaption extends StatelessWidget {
  const _CaptureLocationScreenCaption({
    required this.scenario,
    required this.pinned,
  });

  final String scenario;
  final int pinned;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return MediaQuery.withNoTextScaling(
      child: ColoredBox(
        color: theme.colorScheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.small,
            vertical: Spacing.twoXSmall,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  scenario,
                  style: style,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'pins confirmed $pinned',
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One state: the whole screen under a caption strip.
///
/// [onPinned] is always supplied, because the alternative teaches nothing: with
/// it null the CTA falls back to `Navigator.maybePop()`, and in the canvas
/// there is nothing to pop. The tally is the honest stand-in for what the real
/// hosts do — and it is a stand-in precisely because [CaptureLocationScreen]
/// cannot say WHAT was pinned: `onPinned` is a bare [VoidCallback], so every
/// host has to keep the coordinate on a side channel (`MapCaptureController`),
/// and the one that has no such channel pops nothing at all.
///
/// Stateful only for that tally — no controller, no ticker, nothing to settle.
class _CaptureLocationScreenSlot extends StatefulWidget {
  const _CaptureLocationScreenSlot({
    required this.scenario,
    this.mapBuilder,
    this.isConfirming = false,
    this.width,
  });

  final String scenario;

  /// Passed straight through to [CaptureLocationScreen.mapBuilder]; null is the
  /// placeholder path that ships today.
  final WidgetBuilder? mapBuilder;

  final bool isConfirming;

  /// Baked device width, when the state is about a narrow device rather than
  /// about content.
  final double? width;

  @override
  State<_CaptureLocationScreenSlot> createState() =>
      _CaptureLocationScreenSlotState();
}

class _CaptureLocationScreenSlotState
    extends State<_CaptureLocationScreenSlot> {
  int _pinned = 0;

  @override
  Widget build(BuildContext context) {
    final Widget frame = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _CaptureLocationScreenCaption(
          scenario: widget.scenario,
          pinned: _pinned,
        ),
        Expanded(
          child: CaptureLocationScreen(
            mapBuilder: widget.mapBuilder,
            isConfirming: widget.isConfirming,
            onPinned: () => setState(() => _pinned++),
          ),
        ),
      ],
    );

    final double? width = widget.width;
    if (width == null) return frame;
    // `height: double.infinity` against the loose constraints [Center] passes
    // down keeps the slot bounded, which the [Expanded] above requires.
    return Center(
      child: SizedBox(width: width, height: double.infinity, child: frame),
    );
  }
}

/// What `/capture-location` renders today: no `mapBuilder`, so the neutral
/// [CaptureMapViewport] placeholder stands in for the map.
///
/// The state to look at hardest, because it is the shipping one and it is a
/// trap. The placeholder cannot pan, `CaptureLocationRoute` deliberately pops
/// **without a coordinate** (JEBV4-176 removed the fabricated Beirut default),
/// and yet the primary CTA under it is fully enabled, full width and in brand
/// colour: enablement is `!isConfirming` and nothing else. A user taps a
/// healthy-looking "Pin Location", the sheet closes, and the location-select
/// screen's Confirm stays disabled with nothing on screen explaining why.
/// Whatever the screen ends up doing about it — a disabled CTA, an empty state,
/// a banner — the check belongs here.
@JeebPreview(
  group: 'location',
  name: 'Placeholder map (ships today)',
  size: _captureLocationScreenPhoneBox,
)
Widget captureLocationScreenPlaceholderMap() =>
    const _CaptureLocationScreenSlot(
      scenario: 'Placeholder map · nothing to pin',
    );

/// The production composition: a live map under the fixed centre pin, with the
/// "centre on my location" affordance the real viewport draws when a GPS
/// gateway is injected.
///
/// The map is the shared stand-in, pannable and reporting its centre the way
/// `GoogleMapCaptureView` reports it to `MapCaptureController` on every
/// camera-idle. Drag it in the canvas and the readout moves; that is the state
/// the whole screen exists to produce.
///
/// This is one of the two matrix states. Everything directional on this screen
/// is on it at once — the app bar's back arrow, the readout chip pinned to the
/// start edge, the centre-on-me button pinned to the end edge, and the CTA's
/// [EdgeInsetsDirectional] — so the AR RTL rendering is where an
/// `EdgeInsets.only(left:)` or a `Positioned(right:)` would show up.
@JeebPreview(
  group: 'location',
  name: 'Live map (production shape)',
  size: _captureLocationScreenPhoneBox,
  matrix: true,
)
Widget captureLocationScreenLiveMap() => _CaptureLocationScreenSlot(
      scenario: 'Live map · pan to move the pin',
      mapBuilder: CaptureLocationScreenPreviewFixtures.liveMap(),
    );

/// `isConfirming: true` — the state the class doc calls "a busy state (reverse-
/// geocode / save in flight)".
///
/// Compare it against [captureLocationScreenLiveMap] and note how little
/// changed. `_PinCta` passes the flag to `OmdsPrimaryButton.isEnabled` and
/// stops there, so what a user gets is the standard disabled treatment — the
/// brand fill at 45% alpha, the same "Pin Location" label at 90% — with no
/// spinner, no progress copy and no change to the CTA's Semantics node. It
/// reads as a button that has decided to ignore you, not as work in progress.
///
/// Nothing else is gated either: the map still pans (drag it and the readout
/// moves), the pin still tracks it, and the app bar's back arrow still pops.
/// The screen shows a user who is still choosing a point while its host is
/// already committing the point it read at tap time.
///
/// No production caller sets this flag today — neither `CaptureLocationRoute`
/// nor `GoogleMapPickerLauncher` passes it — so this state is unreachable in
/// the app and only a preview can put it on screen.
@JeebPreview(
  group: 'location',
  name: 'Confirming (CTA disabled, nothing else is)',
  size: _captureLocationScreenPhoneBox,
)
Widget captureLocationScreenConfirming() => _CaptureLocationScreenSlot(
      scenario: 'Confirming · map and back still live',
      mapBuilder: CaptureLocationScreenPreviewFixtures.liveMap(),
      isConfirming: true,
    );

/// Location permission denied — the T-MOB-012 AC4 recovery case, reached the
/// only way this screen allows.
///
/// [CaptureLocationScreen] has no denied state. `GpsDeniedState` was written
/// for it and lives one directory away, but nothing on this screen renders it,
/// so a host can only get it on screen by handing it back from `mapBuilder` —
/// and then the screen layers its fixed centre pin **on top of the denial
/// copy** and leaves "Pin Location" live **underneath** it. The result is on
/// screen here: a red map pin floating in the middle of "Location access
/// required", above a primary CTA that will happily confirm a point the app has
/// just said it cannot determine.
///
/// The render test pins that composition, so if the screen grows a real denied
/// state this preview is where the change gets reviewed.
@JeebPreview(
  group: 'location',
  name: 'Permission denied (via the map seam)',
  size: _captureLocationScreenPhoneBox,
)
Widget captureLocationScreenPermissionDenied() => _CaptureLocationScreenSlot(
      scenario: 'Permission denied · pin still confirmable',
      mapBuilder: CaptureLocationScreenPreviewFixtures.permissionDenied(
        onOpenSettings: () {},
      ),
    );

/// The longest-content state: an out-of-service-area message where the map
/// should be.
///
/// `captureLocationOutsideServiceArea` ("Outside service area") ships in both
/// ARBs and no screen in the app renders it — this screen has nowhere to put
/// it. The body under it is fixture copy, and long on purpose: at the 200%
/// ceiling of the matrix it is the text that decides whether the map slot can
/// hold a message at all, and the slot has no scroll view of its own.
///
/// The second matrix state, for that reason: EN light says nothing is wrong,
/// EN 200% is where the message runs out of room, and the AR rendering is where
/// a right-aligned paragraph under a centred icon shows up.
@JeebPreview(
  group: 'location',
  name: 'Outside service area (longest copy)',
  size: _captureLocationScreenPhoneBox,
  matrix: true,
)
Widget captureLocationScreenOutsideServiceArea() => _CaptureLocationScreenSlot(
      scenario: 'Outside service area · longest copy',
      mapBuilder: CaptureLocationScreenPreviewFixtures.outsideServiceArea(),
    );

/// The narrowest supported device, 320 pt, with the live map on it.
///
/// Everything that competes for horizontal room is here at once: the app bar
/// title between a back arrow and the bar's trailing padding, the coordinate
/// readout chip on the start edge, the centre-on-me button on the end edge, and
/// a full-width CTA with 24 pt of padding a side. The width is baked into the
/// tree rather than only declared to the canvas, so this is genuinely 320 pt in
/// the render test too.
@JeebPreview(
  group: 'location',
  name: 'Compact 320pt phone',
  size: _captureLocationScreenCompactBox,
)
Widget captureLocationScreenCompactPhone() => _CaptureLocationScreenSlot(
      scenario: 'Compact 320 pt phone',
      mapBuilder: CaptureLocationScreenPreviewFixtures.liveMap(),
      width: 320,
    );
