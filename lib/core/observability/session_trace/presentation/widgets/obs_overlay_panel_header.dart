import 'package:flutter/material.dart';

import '../obs_overlay_controller.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import 'package:omds/omds.dart';
import '../../../../previews/jeeb_preview.dart';

/// Title row for the expanded panel: name on the left, a close button (back
/// to the collapsed bubble) on the right.
class ObsOverlayPanelHeader extends StatelessWidget {
  const ObsOverlayPanelHeader({super.key, required this.controller});

  final ObsOverlayController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            'Session Trace',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          key: const Key('obs-overlay-close'),
          tooltip: 'Close',
          icon: Icon(Icons.close, color: theme.colorScheme.onSurfaceVariant),
          onPressed: controller.toggleExpanded,
        ),
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
// Render tests: test/previews/core/obs_overlay_panel_header_preview_test.dart
// ===========================================================================
//
// Widget previews for [ObsOverlayPanelHeader] — run with
// `flutter widget-preview start`.
//
// The header is the title row of the devtool session-trace panel: a hardcoded
// "Session Trace" label in an [Expanded], and the close button that is the
// ONLY way back to the collapsed bubble. Its single parameter is an
// [ObsOverlayController], and it reads exactly one member of it —
// `toggleExpanded`, as the close button's `onPressed`. Nothing it draws is a
// function of controller state.
//
// So its "states" are HOST states, the same way
// `delivery_confirm_illustration_preview.dart`'s are: the width its parent
// hands it, whether that parent bounds its height, and whether a [Overlay]
// ancestor exists for the close button's `Tooltip` to resolve against. Each
// preview below pins one of those — the geometry that ships, the narrowest
// supported device, the width at which the title starts wrapping, a
// full-width host a second caller would reach for, and a fixed-height slot
// that silently shrinks the exit button below the 48pt tap-target floor.
//
// **Network-free by construction.** [ObsOverlayController] is a plain
// [ChangeNotifier] until `attach()` or `start()` is called — those are what
// wrap `Observability.instance.sink` and start the 1s ticker. No preview here
// calls either, so the shared instance below holds an empty buffer, feeds no
// listener, and touches no file, plugin or socket.
//
// **About the captions.** The header's own text is the constant string
// "Session Trace" in every state, so `find.text` on widget output cannot tell
// two previews apart and a render suite keyed on it would pass even if all
// five drew the same box. Each preview therefore carries a one-line caption
// naming the host under review — useful in the canvas, and used by the test
// only to ADDRESS a state. The assertion that proves the states differ is the
// measured geometry in
// `test/previews/core/obs_overlay_panel_header_preview_test.dart`.
//
// Three things these previews surface in the widget rather than in
// themselves: the hardcoded English (see [obsOverlayPanelHeaderInPanel]), the
// shrinking tap target (see [obsOverlayPanelHeaderFixedHeightSlot]), and the
// unlocalized `Tooltip` that once took the whole overlay down (see
// [obsOverlayPanelHeaderInPanel] again).

/// The panel's own max width, restated from `_kMaxWidth` in
/// `obs_overlay_panel.dart`.
const double _obsOverlayPanelHeaderPanelMaxWidth = 340;

/// The phone width the overlay is normally reviewed on.
const double _obsOverlayPanelHeaderPhoneWidth = 390;

/// The narrowest device the app still supports.
const double _obsOverlayPanelHeaderCompactPhoneWidth = 320;

/// A panel narrow enough that the title can no longer sit on one line beside
/// the close button. Not a phone width — it is the wrap threshold, reached on
/// a real device as soon as the text scale is raised (see the `EN 200% text`
/// rendering of [obsOverlayPanelHeaderCompactDevice]).
const double _obsOverlayPanelHeaderWrappingPanelWidth = 160;

/// Height of a fixed slot a future caller might drop the header into — just
/// under the 48pt Material tap-target floor.
const double _obsOverlayPanelHeaderFixedSlotHeight = 40;

/// Canvas boxes. The header is one row, so every box is short and wide, with
/// enough slack under it for the caption plus the extra lines the title takes
/// in the `EN 200% text` rendering.
const Size _obsOverlayPanelHeaderHeaderBox = Size(390, 160);
const Size _obsOverlayPanelHeaderWrappingBox = Size(390, 200);

/// Height of the private-[Overlay] box in [obsOverlayPanelHeaderInPanel].
/// Roomy enough that the 200%-text rendering's two-line title still fits
/// inside it rather than being clipped by the overlay's own bounds.
const double _obsOverlayPanelHeaderOverlayBoxHeight = 96;

/// The controller every preview here is wired to.
///
/// Deliberately a single shared, INERT instance rather than one per preview:
/// the header reads no controller state, so a fresh controller per preview
/// would buy nothing, and exposing one lets the render test prove the close
/// button is really bound to `toggleExpanded` instead of assuming it.
final ObsOverlayController obsOverlayPanelHeaderPreviewController =
    ObsOverlayController();

/// The panel's own width rule, copied from `_PanelShell._widthFor` in
/// `obs_overlay_panel.dart` rather than imported, so these stay previews of
/// the HEADER and not of the panel. If the panel's rule changes, the width
/// assertions in the render test are what say so.
double _obsOverlayPanelHeaderPanelWidth(double screenWidth) {
  final double maxAvailable = screenWidth - Spacing.xLarge;
  return _obsOverlayPanelHeaderPanelMaxWidth < maxAvailable ? _obsOverlayPanelHeaderPanelMaxWidth : maxAvailable;
}

/// Renders [framed] above a caption naming the host under review.
///
/// The caption is preview scaffolding — see the library doc. Kept tiny and
/// single-purpose so the 200%-text rendering still shows the header rather
/// than a wall of label.
Widget _obsOverlayPanelHeaderCaptioned(String caption, Widget framed) => Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          framed,
          const SizedBox(height: Spacing.xSmall),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );

/// The panel's content box: a [width]-wide card with the panel's own
/// `Spacing.medium` padding, i.e. the constraints `_PanelBody`'s [Column]
/// really hands the header.
Widget _obsOverlayPanelHeaderPanelContent(double width) => SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.medium),
        child: ObsOverlayPanelHeader(
          controller: obsOverlayPanelHeaderPreviewController,
        ),
      ),
    );

/// Mounts [child] under a private [Overlay], the way `_ObsOverlayLayer` does.
///
/// This is not decoration. The close button sets `tooltip: 'Close'`, and
/// `Tooltip` resolves an [Overlay] as part of building — so when the overlay
/// layer was a plain `Stack` sibling of the routed child (no `Overlay`
/// ancestor), expanding the panel threw "No Overlay widget found" and the
/// substituted `ErrorWidget` reported "BOTTOM OVERFLOWED BY 99778 PIXELS".
/// One root cause, two symptoms; the fix was the private `Overlay` reproduced
/// here. See the class doc on `_ObsOverlayLayer` in `obs_overlay.dart`.
Widget _obsOverlayPanelHeaderInPrivateOverlay(Widget child, {required double width}) => SizedBox(
      width: width,
      height: _obsOverlayPanelHeaderOverlayBoxHeight,
      child: Overlay(
        initialEntries: <OverlayEntry>[
          OverlayEntry(
            builder: (_) => Align(alignment: Alignment.topCenter, child: child),
          ),
        ],
      ),
    );

/// The only geometry that ships: the panel on a 390pt phone, capped at 340pt
/// by `_kMaxWidth`, with the panel's 16pt padding — 308pt of content — and
/// mounted under its own [Overlay] exactly as `_ObsOverlayLayer` mounts it.
///
/// This is the rendering a reviewer signs off, and it is also the regression
/// guard for the "No Overlay widget found" crash (see [_obsOverlayPanelHeaderInPrivateOverlay]):
/// if `Tooltip` ever stops finding an overlay here, this preview shows the
/// `ErrorWidget` instead of a header.
///
/// The rendering worth the most attention is **AR RTL dark**. The row itself
/// mirrors correctly — [Expanded] title to the right, close button to the
/// left, no hardcoded `EdgeInsets.only` anywhere — but both strings the
/// widget puts on screen are English literals, not `AppLocalizations` keys:
/// the "Session Trace" title and the close button's `Close` tooltip, which is
/// also its only screen-reader label. That is defensible for a devtool that
/// only exists in a `--dart-define JEEB_OBS_OVERLAY=true` build, and
/// indefensible the day anything here is reused outside one.
@JeebPreview(group: 'core', name: 'Panel (production, 390pt)', size: _obsOverlayPanelHeaderHeaderBox)
Widget obsOverlayPanelHeaderInPanel() => _obsOverlayPanelHeaderCaptioned(
      'Panel host: 340pt card on a 390pt phone',
      _obsOverlayPanelHeaderInPrivateOverlay(
        _obsOverlayPanelHeaderPanelContent(_obsOverlayPanelHeaderPanelWidth(_obsOverlayPanelHeaderPhoneWidth)),
        width: _obsOverlayPanelHeaderPanelWidth(_obsOverlayPanelHeaderPhoneWidth),
      ),
    );

/// The same panel on the narrowest supported device: `320 - 24 = 296`pt of
/// card, 264pt of content.
///
/// The title still fits on one line at 1.0, so the EN light rendering looks
/// identical to the production one. The rendering that earns this preview its
/// place is **EN 200% text**: the close button is an [Icon], whose 24pt size
/// does NOT follow the text scaler, while the title does — so at 200% the
/// label wraps beside a button that has not grown by a pixel, and the row
/// goes from 48pt to 144pt (measured in the render test) inside a panel that
/// is only `0.62` of the screen tall.
@JeebPreview(group: 'core', name: 'Compact device (320pt)', size: _obsOverlayPanelHeaderHeaderBox)
Widget obsOverlayPanelHeaderCompactDevice() => _obsOverlayPanelHeaderCaptioned(
      'Compact host: 296pt card on a 320pt phone',
      _obsOverlayPanelHeaderPanelContent(_obsOverlayPanelHeaderPanelWidth(_obsOverlayPanelHeaderCompactPhoneWidth)),
    );

/// The wrap threshold, at 1.0 text scale: a 160pt host leaves the [Expanded]
/// title 80pt beside the 48pt button, and "Session Trace" no longer fits on
/// one line. (How many lines it takes is a property of the font, so the
/// render test asserts that it grows, not that it grows to two.)
///
/// This is the good news state, and it is worth a picture precisely because
/// nothing enforces it: the title [Text] sets no `maxLines` and no
/// `overflow`, so it degrades by wrapping rather than by an ellipsis or a
/// yellow overflow stripe. Everything narrower than this — including every
/// real device once the text scale is raised — renders like this rather than
/// clipping the title or pushing the close button off the trailing edge.
@JeebPreview(group: 'core', name: 'Wrapping title (160pt)', size: _obsOverlayPanelHeaderWrappingBox)
Widget obsOverlayPanelHeaderWrappingTitle() => _obsOverlayPanelHeaderCaptioned(
      'Wrap threshold: 160pt host',
      _obsOverlayPanelHeaderPanelContent(_obsOverlayPanelHeaderWrappingPanelWidth),
    );

/// The header given a whole 390pt phone width with no card and no padding —
/// the shape a second caller gets by dropping it into a page rather than into
/// the panel.
///
/// The [Expanded] eats all of it, so the title and its close button end up at
/// opposite edges of the screen with ~330pt of nothing between them. Nothing
/// breaks; it just stops reading as one control. Included because it is the
/// obvious next call site and the header offers no way to cap its own width.
@JeebPreview(group: 'core', name: 'Bare full-width host', size: _obsOverlayPanelHeaderHeaderBox)
Widget obsOverlayPanelHeaderFullWidthHost() => _obsOverlayPanelHeaderCaptioned(
      'Bare host: full 390pt width, no padding',
      SizedBox(
        width: _obsOverlayPanelHeaderPhoneWidth,
        child: ObsOverlayPanelHeader(
          controller: obsOverlayPanelHeaderPreviewController,
        ),
      ),
    );

/// The state that breaks: a host that bounds the header's HEIGHT.
///
/// `IconButton` asks for a 48pt tap target (`kMinInteractiveDimension`, via
/// the padded tap-target box), but a tight 40pt slot simply constrains it —
/// no assertion, no overflow stripe, no exception. The only control that
/// closes the panel quietly drops below the Material minimum touch size, and
/// the header looks fine while it does. Nothing ships this geometry today
/// (the panel's [Column] leaves the header's height free), which is exactly
/// why it is worth having a picture of before someone slots the header into a
/// fixed-height toolbar.
@JeebPreview(group: 'core', name: 'Fixed 40pt slot (tap target shrinks)', size: _obsOverlayPanelHeaderHeaderBox)
Widget obsOverlayPanelHeaderFixedHeightSlot() => _obsOverlayPanelHeaderCaptioned(
      'Fixed slot: 40pt tall, tap target clipped',
      SizedBox(
        // The panel's CONTENT width (340 card − 2×16 padding), so this state
        // differs from the production one in height alone.
        width: _obsOverlayPanelHeaderPanelWidth(_obsOverlayPanelHeaderPhoneWidth) - 2 * Spacing.medium,
        height: _obsOverlayPanelHeaderFixedSlotHeight,
        child: ObsOverlayPanelHeader(
          controller: obsOverlayPanelHeaderPreviewController,
        ),
      ),
    );
