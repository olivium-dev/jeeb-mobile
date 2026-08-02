import 'package:flutter/material.dart';

import '../obs_overlay_controller.dart';

import 'package:omds/omds.dart';
import '../../../../previews/jeeb_preview.dart';

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

const double _obsOverlayPanelHeaderPanelMaxWidth = 340;

/// The phone width the overlay is normally reviewed on.
const double _obsOverlayPanelHeaderPhoneWidth = 390;

/// The narrowest device the app still supports.
const double _obsOverlayPanelHeaderCompactPhoneWidth = 320;

/// A panel narrow enough that the title can no longer sit on one line beside
/// the close button. Not a phone width — it is the wrap threshold, reached on
const double _obsOverlayPanelHeaderWrappingPanelWidth = 160;

/// Height of a fixed slot a future caller might drop the header into — just
/// under the 48pt Material tap-target floor.
const double _obsOverlayPanelHeaderFixedSlotHeight = 40;

/// Canvas boxes. The header is one row, so every box is short and wide, with
/// enough slack under it for the caption plus the extra lines the title takes
const Size _obsOverlayPanelHeaderHeaderBox = Size(390, 160);
const Size _obsOverlayPanelHeaderWrappingBox = Size(390, 200);

/// Height of the private-[Overlay] box in [obsOverlayPanelHeaderInPanel].
/// Roomy enough that the 200%-text rendering's two-line title still fits
const double _obsOverlayPanelHeaderOverlayBoxHeight = 96;

/// The controller every preview here is wired to.
/// Deliberately a single shared, INERT instance rather than one per preview:
final ObsOverlayController obsOverlayPanelHeaderPreviewController =
    ObsOverlayController();

/// The panel's own width rule, copied from `_PanelShell._widthFor` in
/// `obs_overlay_panel.dart` rather than imported, so these stay previews of
double _obsOverlayPanelHeaderPanelWidth(double screenWidth) {
  final double maxAvailable = screenWidth - Spacing.xLarge;
  return _obsOverlayPanelHeaderPanelMaxWidth < maxAvailable ? _obsOverlayPanelHeaderPanelMaxWidth : maxAvailable;
}

/// Renders [framed] above a caption naming the host under review.
/// The caption is preview scaffolding — see the library doc. Kept tiny and
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
/// This is not decoration. The close button sets `tooltip: 'Close'`, and
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
@JeebPreview(group: 'core', name: 'Compact device (320pt)', size: _obsOverlayPanelHeaderHeaderBox)
Widget obsOverlayPanelHeaderCompactDevice() => _obsOverlayPanelHeaderCaptioned(
      'Compact host: 296pt card on a 320pt phone',
      _obsOverlayPanelHeaderPanelContent(_obsOverlayPanelHeaderPanelWidth(_obsOverlayPanelHeaderCompactPhoneWidth)),
    );

/// The wrap threshold, at 1.0 text scale: a 160pt host leaves the [Expanded]
/// title 80pt beside the 48pt button, and "Session Trace" no longer fits on
@JeebPreview(group: 'core', name: 'Wrapping title (160pt)', size: _obsOverlayPanelHeaderWrappingBox)
Widget obsOverlayPanelHeaderWrappingTitle() => _obsOverlayPanelHeaderCaptioned(
      'Wrap threshold: 160pt host',
      _obsOverlayPanelHeaderPanelContent(_obsOverlayPanelHeaderWrappingPanelWidth),
    );

/// The header given a whole 390pt phone width with no card and no padding —
/// the shape a second caller gets by dropping it into a page rather than into
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
/// `IconButton` asks for a 48pt tap target (`kMinInteractiveDimension`, via
@JeebPreview(group: 'core', name: 'Fixed 40pt slot (tap target shrinks)', size: _obsOverlayPanelHeaderHeaderBox)
Widget obsOverlayPanelHeaderFixedHeightSlot() => _obsOverlayPanelHeaderCaptioned(
      'Fixed slot: 40pt tall, tap target clipped',
      SizedBox(
        // The panel's CONTENT width (340 card − 2×16 padding), so this state
        width: _obsOverlayPanelHeaderPanelWidth(_obsOverlayPanelHeaderPhoneWidth) - 2 * Spacing.medium,
        height: _obsOverlayPanelHeaderFixedSlotHeight,
        child: ObsOverlayPanelHeader(
          controller: obsOverlayPanelHeaderPreviewController,
        ),
      ),
    );
