/// Widget previews for [GpsDeniedState] — run with
/// `flutter widget-preview start`.
///
/// [GpsDeniedState] is the T-MOB-012 AC4 recovery surface: location permission
/// was denied, so the map cannot be pinned and the only way forward is the OS
/// settings page. Its entire input surface is ONE optional callback
/// (`onOpenSettings`); all three strings come from the ARB. There is no cubit,
/// no repository and nothing to fetch, so these previews are network-free
/// because there is nothing to fetch, not merely because [jeebPreviewHost]
/// guards them.
///
/// That shape decides what a "state" is here. Copy cannot vary, so what varies
/// is **whether the CTA is wired** and **the box the host hands the widget** —
/// and the box is the interesting half, because the widget is
/// `Center > Padding > Column` with NO scroll view. It has no way to absorb a
/// slot that is shorter than its content: it overflows. Every state below is
/// therefore a real host geometry, and two of them are hosts it does not fit.
///
/// Geometry comes from the annotation `size` (the canvas box) for HEIGHT and
/// from [_Slot]'s `width` for WIDTH. Height is left to the canvas deliberately:
/// baking a short height into the tree would make the render suite throw on
/// every run instead of on the case under review. The width is baked because a
/// 320 pt phone is a real device, and a state that only looks compact in the
/// canvas is not a state.
///
/// Every preview is captioned with its scenario, unlocalized on purpose — the
/// caption names the *state*, not the product, and seeing English there in the
/// AR RTL rendering is expected. The caption is also pinned by the render test:
/// the widget itself renders identical copy in all five states, so without it
/// the suite could not tell one preview from another. The caption chrome does
/// not follow the text scaler (see [_Caption]) so that the `EN 200% text`
/// rendering measures the widget and not the label above it.
library;

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../features/location/presentation/widgets/gps_denied_state.dart';
import '../harness/jeeb_preview.dart';

/// The slot the capture-location screen would give it: phone width, full body
/// height minus the app bar and the "Pin Location" CTA.
const Size _phoneSlot = Size(390, 560);

/// The narrowest device the app still supports, same body height.
const Size _compactSlot = Size(320, 560);

/// A fixed-height map card — the shape an inline map preview or a bottom sheet
/// hands its child. Short on purpose: this is the box the widget does not fit.
const Size _cardSlot = Size(390, 200);

/// A phone in landscape: wide, and only ~360 pt tall once the chrome is gone.
const Size _landscapeSlot = Size(740, 360);

/// One state: the widget in a bounded slot, with the scenario named above it.
///
/// [wired] decides whether `onOpenSettings` is supplied. It is the widget's
/// only input and the difference is not cosmetic — an unwired CTA is disabled,
/// so the preview must be able to show both.
Widget _hosted(String scenario, {bool wired = true, double? width}) =>
    _Slot(scenario: scenario, wired: wired, width: width);

/// The intended state: permission denied on the capture-location screen, with
/// the CTA wired the way a production host wires it.
///
/// The widget's own class doc says production passes
/// `() => AppSettings.openAppSettings()`; this passes a counter so the canvas
/// can prove the tap is really landing. Tap "Open Settings" and the tally above
/// the slot moves.
///
/// Worth comparing against [gpsDeniedStateNoCallback]: on this phone-height
/// slot the two look nearly identical, and the difference — a dead CTA — is a
/// 45% fill you have to be looking for.
@JeebPreview(name: 'Full phone slot · CTA wired', size: _phoneSlot)
Widget gpsDeniedStateWiredCta() => _hosted('Full phone slot · CTA wired');

/// What `const GpsDeniedState()` ships today — literally the default
/// constructor, no arguments.
///
/// `onOpenSettings` is optional, and the CTA passes
/// `isEnabled: onOpenSettings != null`, so a host that forgets the callback
/// gets a dead-end screen: the copy says to grant permission, the only control
/// offered cannot be tapped, and nothing on the surface says why. The disabled
/// treatment is `OmdsPrimaryButton`'s tinted 45%-alpha fill with the label at
/// 90% alpha (P0-X01), which is deliberately still legible — so it reads as an
/// enabled button that ignores taps rather than as a disabled one.
///
/// This is not a hypothetical: `CaptureLocationScreen` does not render this
/// widget at all yet, so the first host to wire it up is the one that decides
/// whether AC4 works.
@JeebPreview(name: 'Default constructor · CTA dead', size: _phoneSlot)
Widget gpsDeniedStateNoCallback() =>
    _hosted('Default constructor · CTA dead', wired: false);

/// The narrowest supported device, 320 pt — and the state whose `EN 200% text`
/// rendering is the most damning of the three overflows in this file.
///
/// Both strings are centred and neither sets `maxLines`, so the title and the
/// body simply take more lines as the content box narrows (24 pt of horizontal
/// padding a side leaves 272 pt here). At default text size nothing clips.
/// Double the type and the column outgrows **the entire body of the phone** —
/// not a card, not a sheet, the whole screen — and since there is no scroll
/// view the CTA is what goes over the bottom edge.
///
/// The 320 pt width is baked into the tree, not just declared to the canvas, so
/// the state is genuinely compact in the render test too.
@JeebPreview(name: 'Compact 320pt phone', size: _compactSlot)
Widget gpsDeniedStateCompactPhone() =>
    _hosted('Compact 320pt phone', width: 320);

/// **The state that breaks**: the same widget in a 200 pt map card.
///
/// [GpsDeniedState] is `Center > Padding > Column(mainAxisSize: min)` with no
/// [SingleChildScrollView] anywhere. Its content is a fixed 56 pt icon plus two
/// wrapping paragraphs plus a fixed 48 pt CTA — call it ~210 pt at default text
/// size — and a [Column] that cannot fit its children does not shrink them or
/// scroll them: it paints the overflow stripe and clips, silently, in release.
///
/// A 200 pt slot is not a strawman. Anything that embeds the map as a card, a
/// bottom sheet, or a landscape split view hands down about this much height,
/// and the first thing to disappear off the bottom is the "Open Settings" CTA —
/// the only control on the surface. The fix belongs to the widget (wrap the
/// column in a scroll view, or drop the icon under a height threshold), not to
/// its hosts.
@JeebPreview(name: 'Short map card (200pt)', size: _cardSlot)
Widget gpsDeniedStateShortCard() => _hosted('Short map card (200pt)');

/// A phone rotated to landscape: 740 pt wide, ~360 pt tall.
///
/// Two things to look at. The first is the width — the widget caps its content
/// with nothing but 24 pt of padding a side, so at 740 pt the body runs as one
/// very long centred line (~690 pt) instead of the comfortable 45–75 character
/// measure the phone layout gets for free. There is no `maxWidth`.
///
/// The second is the height, and it is why this state is here rather than in a
/// tablet file: the extra width buys back the lines the narrow phone spent, so
/// this fits at default text size — and then the `EN 200% text` rendering,
/// where the type doubles and the 56 pt icon does not, runs out of the 360 pt
/// it has. Same defect as [gpsDeniedStateShortCard], reached from the
/// accessibility side.
@JeebPreview(name: 'Landscape phone (740×360)', size: _landscapeSlot)
Widget gpsDeniedStateLandscape() =>
    _hosted('Landscape phone (740×360)', width: 740);

// ---------------------------------------------------------------------------
// Fixtures. Nothing below is production code.
// ---------------------------------------------------------------------------

/// The scenario label, and — when the CTA is wired — a live tally of taps.
///
/// Pinned to [TextScaler.noScaling]: this is preview chrome, and if it grew
/// with the text scaler it would eat the slot in the `EN 200% text` rendering
/// and take the credit for an overflow the widget caused on its own.
class _Caption extends StatelessWidget {
  const _Caption({required this.scenario, required this.opened});

  final String scenario;
  final int? opened;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return MediaQuery.withNoTextScaling(
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
            if (opened != null)
              Text(
                'settings opened $opened',
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}

/// A named, outlined box holding one [GpsDeniedState].
///
/// The outline is the point of the wrapper: [GpsDeniedState] centres itself in
/// whatever it is given and paints no background, so without a drawn boundary a
/// reviewer cannot tell a comfortable slot from one the content is spilling
/// out of. The box takes the remaining canvas height via [Expanded], which is
/// what lets the annotation `size` alone decide how much room each state gets.
///
/// Stateful only for the tap tally — no controller, no ticker, nothing to
/// settle.
class _Slot extends StatefulWidget {
  const _Slot({required this.scenario, required this.wired, this.width});

  final String scenario;
  final bool wired;

  /// Baked device width, when the state is about a device rather than a slot.
  final double? width;

  @override
  State<_Slot> createState() => _SlotState();
}

class _SlotState extends State<_Slot> {
  int _opened = 0;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    // The unwired state is built from the bare default constructor on purpose:
    // this is exactly what a host that forgets the callback gets.
    final Widget denied = widget.wired
        ? GpsDeniedState(onOpenSettings: () => setState(() => _opened++))
        : const GpsDeniedState();

    final Widget frame = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Caption(
          scenario: widget.scenario,
          opened: widget.wired ? _opened : null,
        ),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: denied,
          ),
        ),
      ],
    );

    final double? width = widget.width;
    if (width == null) return frame;
    // `height: double.infinity` against the loose constraints [Center] passes
    // down keeps the slot's height bounded, which [Expanded] above requires.
    return Center(
      child: SizedBox(width: width, height: double.infinity, child: frame),
    );
  }
}
