/// Widget previews for [OtpAtDoorCard] — run with
/// `flutter widget-preview start`.
///
/// The card is the customer's hand-off surface: it slides over the tracking map
/// when the delivery reaches `AtDoor`, and it is the moment the jeeber asks for
/// the four-digit code. It takes exactly two inputs — a `deliveryId` that is
/// never rendered (it only builds the `/orders/{id}/otp` route) and a nullable
/// `handoverCode` — so there is no repository, cubit or image to fake here.
/// These previews are network-free because the widget has nothing to fetch, not
/// merely because [jeebPreviewHost] guards it. The CTA's `context.push` is
/// never fired: previews are for looking at the card, and a preview has no
/// router to push onto.
///
/// **The one axis that matters is `handoverCode == null`.** Everything else on
/// the card is fixed localized copy. Non-null swaps the body line
/// (`trackingAtDoorShareCode`) and adds the inline [HandoverCodeDisplay]; null
/// falls back to the pre-G4 copy (`trackingAtDoorBody`) with the CTA as the only
/// route to the code. That null branch is not hypothetical — on 2026-07-31 it
/// was half of the P0 that dead-ended live deliveries (accept parser dropped
/// the code AND the AtDoor push never landed), so it gets its own preview.
///
/// Fixtures follow `test/live_tracking_handover_code_test.dart`: delivery
/// `DLV-770001`, code `1234`. The other codes below are deliberately distinct
/// per state so the render test can prove each preview built ITS OWN state.
///
/// **Measured heights** (widget test, 390 pt wide, EN):
///
/// | text scale | with code | without code |
/// |---|---|---|
/// | 1.0 | 320 pt | 236 pt |
/// | 2.0 | 724 pt | 560 pt |
///
/// Those numbers come from `flutter test`, which substitutes a monospaced test
/// font whose glyphs are all one em wide, so every line count in them is a
/// worst case and the canvas (real Inter) reads shorter. Arabic is shorter
/// again at both scales (276 / 588) — EN is the binding case for this card, not
/// AR.
///
/// **Two things the matrix exposes that no widget test asserts.**
///
/// 1. **The card has no scroll fallback and no height ceiling.** `_CardContent`
///    is a plain [Column] (`mainAxisSize.min`) inside a fixed-height slot of the
///    tracking screen's own Column. At 200% text with a code it wants ~2.3× the
///    height it wants at 1.0, and when the slot is shorter than that it paints
///    overflow stripes rather than scrolling — reproducible here by shrinking
///    the canvas box, and reproduced by CI at 320 pt (see
///    [otpAtDoorCardNarrowPhone]).
/// 2. **The CTA does not grow with text.** `OmdsLoadingButton` hard-codes
///    `height: Sizes.fourXLarge` (48 pt). At 200% the label box measures 40 pt
///    inside those 48 — 4 pt of clearance top and bottom — in both locales. It
///    does not clip today; it has no room left for a longer translation.
///
/// What the matrix confirms is *fine*: the digits never bidi-reorder. The code
/// is pinned to [TextDirection.ltr] inside [HandoverCodeDisplay], so `0450`
/// reads 0-4-5-0 in the AR RTL rendering too — [otpAtDoorCardLeadingZeroCode]
/// exists to keep that guard visible if anyone deletes it.
///
/// Not visible in any rendering, and worth knowing before reviewing them: the
/// [AnimatedSlide] in [OtpAtDoorCard.build] is fed a `const Offset.zero` that
/// never changes, and an implicit animation only runs on a value *change*, so
/// the "slides in" behaviour its doc comment claims (T-MOB-017 AC4) does not
/// happen — the card appears in place. Every preview below therefore shows the
/// card exactly as production shows it.
library;

import 'package:flutter/material.dart';

import '../harness/jeeb_preview.dart';
import '../../features/live_tracking/presentation/widgets/otp_at_door_card.dart';
import '../../features/otp_handover/presentation/widgets/handover_code_display.dart';

/// The delivery every fixture belongs to — the id from
/// `test/live_tracking_handover_code_test.dart`. It is never rendered; it only
/// feeds the `/orders/DLV-770001/otp` route behind the CTA.
const String _deliveryId = 'DLV-770001';

/// Phone width, and tall enough that the two 1.0 renderings sit clear of the
/// box edge with the EN 200% rendering mostly in frame.
///
/// It is deliberately NOT tall enough for the 724 pt the EN 200% + code
/// rendering wants under the test font. If that rendering paints overflow
/// stripes in the canvas, they belong to the widget — the card has no scroll
/// fallback — not to this box.
const Size _cardBox = Size(390, 480);

/// The card as the tracking screen builds it.
Widget _card({String? handoverCode}) => OtpAtDoorCard(
      deliveryId: _deliveryId,
      handoverCode: handoverCode,
    );

/// G4, the hand-off moment: the device knows the code, so the code is ON SCREEN.
///
/// This is the state sprint-009 P0 §G4 bought — before it, the customer had to
/// tap through to a full screen while the jeeber stood at the door waiting. Two
/// things must both be true here and neither alone is enough: the digits are
/// rendered inline (`Key('tracking.atDoorCode')`), and "Show OTP" is still
/// present as the secondary route. Fixture `1234` is the same code
/// `test/live_tracking_handover_code_test.dart` pins.
@JeebPreview(group: 'live_tracking', name: 'Code known · 1234', size: _cardBox)
Widget otpAtDoorCardWithCode() => _card(handoverCode: '1234');

/// No code on this device — the branch that dead-ended live deliveries.
///
/// Reachable two ways: a reinstall (the code is persisted locally at accept
/// time and nothing re-fetches it), or the accept response never carrying it at
/// all — which is exactly what happened on 2026-07-31 (`ship-p0` run g5) while
/// the AtDoor push also failed to land, leaving the customer with no surface
/// showing the code the jeeber was asking for.
///
/// The card degrades honestly: the body reverts to the pre-G4 sentence, the
/// code panel is absent rather than blank, and the CTA becomes the only route
/// to the code — the OTP screen owns the SMS fallback from there. If this ever
/// renders an empty code pill, the `code != null` gate has been loosened to a
/// truthiness check.
@JeebPreview(group: 'live_tracking', name: 'Code unknown', size: Size(390, 400))
Widget otpAtDoorCardWithoutCode() => _card();

/// Bidi guard, made visible: a code whose reading is destroyed by reordering.
///
/// `0450` is chosen so a failure is unmistakable — a leading zero that must
/// stay leading, and a value that reads as a different code (`0540`) if the
/// digits mirror. The AR RTL rendering of the matrix is the whole point of this
/// preview: the surrounding card mirrors, the digits must not, and the only
/// thing stopping them is the [Directionality] pin inside
/// [HandoverCodeDisplay]. It is also the state that proves the code is treated
/// as an opaque string, not a number — a number would drop the leading zero.
@JeebPreview(group: 'live_tracking', name: 'Bidi guard · 0450', size: _cardBox)
Widget otpAtDoorCardLeadingZeroCode() => _card(handoverCode: '0450');

/// The narrowest phone the app supports (320 pt), pinned to that width by the
/// preview itself.
///
/// The pin is load-bearing: the render tests pump an 800 px viewport and ignore
/// [JeebPreview.size], so this is the only state whose width is guaranteed in
/// CI as well as in the canvas.
///
/// 320 pt is where this card stops being comfortable. Measured here at 200%
/// (test font, so read it as the worst case): the code panel fills the whole
/// 272 pt of available width, and the card wants 812 pt of height against the
/// ~568 pt such a phone actually has — the 200% rendering overflows in BOTH
/// locales at this width, where at 390 pt only EN does.
@JeebPreview(group: 'live_tracking', name: 'Narrow phone · 320 pt', size: Size(320, 520))
Widget otpAtDoorCardNarrowPhone() => Align(
      alignment: Alignment.topCenter,
      child: SizedBox(width: 320, child: _card(handoverCode: '9061')),
    );

/// The card as the customer actually meets it: anchored to the bottom of the
/// tracking screen, over the map.
///
/// Every preview above renders a shape production never ships — the card
/// top-aligned on an opaque surface — which hides the three decisions that only
/// read against something behind them: the top-only [BorderRadius.vertical]
/// corners, the shadow deliberately offset *upward* (`Offset(0, -2)`) so the
/// card reads as lifting off the map rather than sitting on it, and the opaque
/// `colorScheme.surface` fill that has to hold its own over map imagery.
///
/// The backdrop is a text-free stand-in for [TrackingMapSurface], so any string
/// the render test pins can only have come from the card.
@JeebPreview(group: 'live_tracking', name: 'Bottom-anchored over map', size: Size(390, 560))
Widget otpAtDoorCardOverMap() => Column(
      children: <Widget>[
        const Expanded(child: _MapBackdrop()),
        _card(handoverCode: '7788'),
      ],
    );

/// A neutral stand-in for the live map behind the card — enough shape to judge
/// the top corners and the upward shadow against, and deliberately text-free.
class _MapBackdrop extends StatelessWidget {
  const _MapBackdrop();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        // A couple of "roads", so the card's edge is judged against contrast
        // rather than against a flat fill.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            colors.surfaceContainerHighest,
            colors.surfaceContainer,
            colors.surfaceContainerHighest,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.navigation_rounded,
          size: 48,
          color: colors.primary,
        ),
      ),
    );
  }
}
