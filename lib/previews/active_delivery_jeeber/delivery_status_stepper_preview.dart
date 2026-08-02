/// Widget previews for [DeliveryStatusStepper] — run with
/// `flutter widget-preview start`.
///
/// The stepper takes three inputs and reads nothing else: a
/// [JeeberDeliveryStatus], an `isTransitioning` flag, and an `onAdvance`
/// callback. No cubit, no repository, no gateway — every preview below is a
/// pure function of an enum value and a bool, which makes this file
/// network-free by construction rather than by the guard in [jeebPreviewHost].
///
/// The states that matter are therefore the STATUS the jeeber's delivery is
/// parked on, because the widget changes shape three separate ways along that
/// axis:
///
///   * `ordered` / `picked` — stepper **plus** an inline advance CTA.
///   * `inTransit` / `atDoor` — stepper only. JM-051 moved the journey to Done
///     into `MarkDeliveredPanel` (it needs the proof photo), so the stepper
///     suppresses its own button for the whole delivering phase.
///   * `cancelled` / `expired` / `disputed` — nothing at all
///     (`SizedBox.shrink`).
///
/// Production placement is `active_delivery_jeeber_screen.dart` (`_ReadyView`):
/// the stepper is the `content` of an `OMDSSectionCard(showDivider: false)`
/// titled `activeDeliveryProgressTitle`, inside a `ListView` padded
/// `Spacing.medium` on every side. Every preview rebuilds that exact frame, so
/// the canvas shows the width the stepper really gets — 310 dp on a 390 dp
/// phone, not the full canvas — and so the five stage labels are reviewed at
/// the 62 dp per column they actually have to fit in. `pumpPreview` renders at
/// the default 800x600 test viewport and ignores [JeebPreview.size], so a
/// preview that wants to say anything about phone-width layout has to clamp
/// itself; [_hosted] does.
///
/// Fixture data is the enum itself — the same five stages
/// `test/features/active_delivery_jeeber/delivery_status_stepper_test.dart`
/// walks, plus the two unsuccessful terminals it asserts render nothing.
library;

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import '../../features/active_delivery_jeeber/presentation/widgets/delivery_status_stepper.dart';
import '../../l10n/app_localizations.dart';
import '../harness/jeeb_preview.dart';

/// A stepper card with the inline advance CTA (`ordered`, `picked`): title +
/// stepper + labels + a 48 dp button.
///
/// Measured with the frame below: 220 dp tall in EN, 236 in AR, and 420 at the
/// 200% rendering — that last one does not fit this box, deliberately. Every
/// dimension in this file comes from the render test, which runs on the test
/// fallback font; its glyphs are wider than the bundled Inter, so these are
/// upper bounds, not promises about the shipped font.
const Size _withCtaBox = Size(390, 240);

/// A stepper card with no CTA (`inTransit`, `atDoor`, `done`): 172 dp in EN,
/// 188 in AR, 372 at 200%.
const Size _stepperOnlyBox = Size(390, 200);

/// The unsuccessful terminals, where the stepper paints nothing and only the
/// section title is left — 68 dp, all of it chrome. Deliberately short so an
/// accidental re-appearance of the stepper is obvious as an overflow rather
/// than as extra whitespace.
const Size _collapsedBox = Size(390, 100);

/// Rebuilds the stepper's production frame from `_ReadyView`: a phone-width
/// box, the `ListView`'s `Spacing.medium` padding, and the `OMDSSectionCard`
/// that supplies both the title and the `OMDSSpacing.xl` side padding.
///
/// 390 − 2×16 (list) − 2×24 (card) = 310 dp of content, i.e. 62 dp per stage
/// column. That number is the whole reason this helper exists: reviewed at the
/// canvas's full width the labels never wrap and every state looks fine.
Widget _hosted(
  JeeberDeliveryStatus status, {
  bool isTransitioning = false,
  double deviceWidth = 390,
}) {
  return Align(
    alignment: AlignmentDirectional.topStart,
    child: SizedBox(
      width: deviceWidth,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.medium),
        child: Builder(
          builder: (BuildContext context) => OMDSSectionCard(
            title: AppLocalizations.of(context).activeDeliveryProgressTitle,
            showDivider: false,
            content: DeliveryStatusStepper(
              currentStatus: status,
              isTransitioning: isTransitioning,
              // Inert: the real callback POSTs a status transition. Tapping in
              // the canvas must do nothing at all.
              onAdvance: () {},
            ),
          ),
        ),
      ),
    ),
  );
}

/// Step 1 of 5 — the state a jeeber lands on the instant an offer is accepted.
///
/// The only stage where nothing is behind you: one accent circle, four pending
/// ones, and the CTA reading "Mark as Picked" (the label names the NEXT status,
/// not the current one — `_AdvanceButton` is handed `currentStatus.next`).
///
/// This is also the leftmost/rightmost-circle case for RTL: in Arabic the whole
/// stepper mirrors, so the active circle must sit on the RIGHT with the four
/// pending stages running away to the left. If the AR rendering shows the
/// accent on the left, the icon overlay [Row] and the [OmdsStepIndicator]
/// underneath it have stopped mirroring together and every icon is now sitting
/// on the wrong circle. Measured: the `ordered` icon's centre is 60 dp from the
/// LEADING edge in both directions, so today they mirror together — the render
/// test pins that equality.
@JeebPreview(group: 'active_delivery_jeeber', name: 'Ordered · step 1 + CTA', size: _withCtaBox)
Widget deliveryStatusStepperOrdered() =>
    _hosted(JeeberDeliveryStatus.ordered);

/// Step 2 of 5 — parcel in hand, carrying the LONGEST CTA in the set.
///
/// "Mark as In Transit" (18 chars) / "تحديد كـ: تم الاستلام" is the widest
/// label `_buttonLabel` can produce, so this is the card that decides whether
/// the button fits at the 200% rendering. It does not: `OmdsLoadingButton`
/// hard-codes `height: Sizes.fourXLarge` (48 dp) around a plain `Text`, so at
/// 200% the label wraps to two lines inside a box that is still 48 dp tall and
/// the second line is CLIPPED — no ellipsis, no growth, no overflow stripe to
/// warn you. Pinned by the render test; at 1x it fits on one line with room to
/// spare, which is why only the third rendering of the matrix shows it.
///
/// It also shows the first completed connector, which is the only place
/// `completedColor` (primary) and `activeColor` (tertiary #D73B00) are visible
/// side by side — the tone pair the widget's own comment warns about.
@JeebPreview(group: 'active_delivery_jeeber', name: 'Picked · longest CTA', size: _withCtaBox)
Widget deliveryStatusStepperPicked() => _hosted(JeeberDeliveryStatus.picked);

/// The in-flight state: `isTransitioning`, i.e. the transition POST is on the
/// wire and has not come back.
///
/// `OmdsLoadingButton` swaps the label for an indeterminate spinner, so the CTA
/// loses its text entirely — compare against the card above, which is the same
/// status one frame earlier. Two things to check here: the button keeps its
/// full 48 dp height (a collapsing button makes the card jump), and the stepper
/// above it does NOT advance — the circles still say `picked`, because the
/// optimistic advance is the server's to confirm.
///
/// The CTA also goes INERT here — `OmdsLoadingButton` drops its `onTap`
/// (`canTap = isEnabled && !isLoading`) and the merged
/// `mark_delivered_advance_cta` node loses its tap action, so a second
/// `POST /v1/delivery/status/transition` cannot be fired for the same step by
/// double-tapping. Pinned by the render test, with the idle card as the
/// control. What survives is `isButton: true` on a node with nothing to do: a
/// screen reader still announces "button" for the duration of the request.
@JeebPreview(group: 'active_delivery_jeeber', name: 'Picked · transitioning', size: _withCtaBox)
Widget deliveryStatusStepperPickedTransitioning() =>
    _hosted(JeeberDeliveryStatus.picked, isTransitioning: true);

/// JM-051 regression guard, made visible: `inTransit` renders **no CTA**.
///
/// This is the status the jeeber seam seeds and the status the delivering-phase
/// flow asserts on first frame, so it is the single most-viewed state of this
/// widget. From here the journey to Done belongs to `MarkDeliveredPanel`
/// (`mark_delivered_cta`), which owns the proof photo and the done→rating
/// chain; a button re-appearing in this card means the two panels are now
/// offering two different ways to finish a delivery, and only one of them
/// attaches proof.
///
/// The card should read: two completed stages behind, the truck accent, two
/// pending ahead, and nothing below the labels.
///
/// It is also the cleanest card for the OTHER text ceiling: each stage label
/// gets a bare `Expanded`, i.e. 310 / 5 = 62 dp, with no `maxLines`, no
/// ellipsis and no `FittedBox`. "In Transit" needs more than that for a single
/// word at 200%, so the label breaks MID-WORD and the label row grows from 32
/// to 160 dp. Arabic hits the same wall one step earlier — "تم الاستلام" is
/// already on three lines at 1x in the render test's font.
@JeebPreview(group: 'active_delivery_jeeber', name: 'In transit · no CTA (JM-051)', size: _stepperOnlyBox)
Widget deliveryStatusStepperInTransit() =>
    _hosted(JeeberDeliveryStatus.inTransit);

/// `atDoor` — the last stage before completion, and the one with a landmine
/// under it.
///
/// P6/B2: `atDoor.next` is `null` on purpose — `AtDoor → Done` is not an edge
/// on the plain status-patch path, it runs through the door OTP. The stepper's
/// `showAdvance` happens to exclude `atDoor` for a DIFFERENT reason (JM-051's
/// proof-photo hand-off), and those two guards are the only things standing
/// between this state and the `currentStatus.next!` null-assert inside
/// `_AdvanceButton`. Anyone "restoring" the inline button for the delivering
/// phase will find `ordered`, `picked` and `inTransit` all fine and this card
/// throwing — which is exactly why it gets its own preview instead of being
/// folded into the one above.
@JeebPreview(group: 'active_delivery_jeeber', name: 'At door · next is null', size: _stepperOnlyBox)
Widget deliveryStatusStepperAtDoor() => _hosted(JeeberDeliveryStatus.atDoor);

/// The successful terminal, and the state that reads wrong.
///
/// `done` is `isTerminal`, so the CTA is gone — correct. But `_stateAt` maps
/// `index == currentIndex` to `current`, and `done` IS the current index, so
/// the final stage renders in the ACTIVE styling (tertiary accent, `onSurface`
/// bold label) rather than the completed one. Combined with
/// `showCheckmark: false`, a finished delivery never shows a fully-completed
/// stepper: it shows four completed stages and a fifth that still looks like
/// work in progress. Read this card next to the `atDoor` one above — the only
/// difference is which circle is accented, not "in progress" versus "done".
@JeebPreview(group: 'active_delivery_jeeber', name: 'Done · last step still accented', size: _stepperOnlyBox)
Widget deliveryStatusStepperDone() => _hosted(JeeberDeliveryStatus.done);

/// The unsuccessful terminal: `cancelled` must paint NOTHING.
///
/// This is defence in depth rather than a reachable screen — `_ReadyView`
/// early-returns `_UnsuccessfulTerminalContent` before it ever builds this
/// section — and the guard is load-bearing: the private `stepIcon` and
/// `statusLabel` extensions both `throw StateError` for cancelled / expired /
/// disputed, so without the `isUnsuccessfulTerminal` shrink at the top of
/// `build` this state would not render badly, it would CRASH the jeeber's
/// active-delivery screen.
///
/// What the card should show is the section title and a 310 x 0 dp hole under
/// it. Anything else — a stage circle, a stray gap, a red overflow stripe —
/// means the shrink has been lost. (The empty titled card is what a future
/// caller that forgets the early return would ship; that is a screen-level
/// question, not this widget's.)
@JeebPreview(group: 'active_delivery_jeeber', name: 'Cancelled · paints nothing', size: _collapsedBox)
Widget deliveryStatusStepperCancelled() =>
    _hosted(JeeberDeliveryStatus.cancelled);
