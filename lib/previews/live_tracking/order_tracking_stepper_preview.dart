/// Widget previews for [OrderTrackingStepper] — run with
/// `flutter widget-preview start`.
///
/// The widget takes no cubit and no repository. Its whole input is two scalars
/// — `currentStep` (0…3) and the `atDoor` relabel flag — so these previews are
/// network-free because there is nothing to fetch, not merely because
/// [jeebPreviewHost] guards the wire.
///
/// Every state below is a state a real delivery row produces. The production
/// call site (`live_tracking_screen.dart`) feeds the widget from
/// `DeliveryTrackingInfo.trackingStepIndex4` and
/// `currentStage == TrackingStage.atDoor`, and that mapping can emit exactly
/// four step indices plus the at-door relabel (P6/A5) — which is exactly the
/// set previewed here, plus the narrowest phone the app supports.
///
/// **About the captions.** The stepper renders the SAME four labels in every
/// step state — only the third one changes, and only at the door. So
/// `find.text` on the widget's own output cannot tell "Ordered" from
/// "Delivered", and a render test bound to it would pass on six copies of one
/// state. Each preview therefore carries a one-line caption naming the state:
/// useful in the canvas, where six near-identical rows are hard to tell apart,
/// and used by the test only to ADDRESS a state. The assertions that prove the
/// states differ — the progress fraction, the icon census, the active node —
/// live in `test/previews/live_tracking/order_tracking_stepper_preview_test.dart`.
/// The captions are deliberately unlocalized: they name the state, not the
/// product, so English in the AR RTL rendering is expected.
///
/// Three things these previews surface, all in the widget (or the OMDS bar it
/// draws with) rather than in the previews themselves — see
/// [orderTrackingStepperPicked] for the RTL fill, [orderTrackingStepperDelivered]
/// for the step that never completes, and [orderTrackingStepperCompactPhone]
/// for the 200% ceiling.
library;

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../features/live_tracking/presentation/widgets/order_tracking_stepper.dart';
import '../harness/jeeb_preview.dart';

/// The phone width the tracking screen is designed against.
const double _phoneWidth = 390;

/// The narrowest device the app still supports.
const double _compactPhoneWidth = 320;

/// Canvas box for a phone-width rendering: 4pt bar + 16pt gap + a 20pt icon
/// over one or two lines of label, plus the caption. Deliberately NOT tall
/// enough to absorb the 200%-text rendering — the growth is what to look at.
const Size _stepperBox = Size(390, 170);

/// Same, on the compact phone: the columns are 80pt wide there, so the labels
/// take a second line sooner and the block is taller.
const Size _compactBox = Size(320, 190);

/// Renders the stepper at [width] above a caption naming the state.
///
/// [width] is fixed rather than left to the canvas so the four step columns are
/// exactly `width / 4` in every rendering — the crowding a reviewer judges is a
/// property of the device width, and a canvas that quietly resized would hide
/// it.
Widget _hosted(
  String caption, {
  required int currentStep,
  bool atDoor = false,
  double width = _phoneWidth,
}) =>
    Center(
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            OrderTrackingStepper(currentStep: currentStep, atDoor: atDoor),
            const SizedBox(height: Spacing.xSmall),
            Text(
              caption,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );

/// Cold start: the order exists and nothing else has happened yet.
///
/// Worth its own preview because of what the bar already says. The widget
/// passes `completedSteps: currentStep + 1`, so the CURRENT step counts as
/// complete and the bar is a quarter full before the jeeber has touched the
/// parcel. That is the convention the whole component is built on — see it once
/// here and the other five states read correctly.
@JeebPreview(group: 'live_tracking', name: 'Ordered', size: _stepperBox)
Widget orderTrackingStepperOrdered() =>
    _hosted('Ordered · step 1 of 4', currentStep: 0);

/// The jeeber has the parcel. One step done, one active, two pending — the only
/// state where all three step icons are on screen at once, which makes it the
/// state to check the done/active/pending colour ladder in.
///
/// **This is the RTL state to look at.** The OMDS progress bar paints with raw
/// canvas coordinates (`drawLine(Offset(0, …) → Offset(width * progress, …))`,
/// `omds_stepper_progress.dart`) and never reads [Directionality], while the
/// step row above it is a [Row] and mirrors normally. So in the AR rendering
/// the labels run right-to-left but the fill still grows left-to-right: the
/// filled half of the bar sits under "قيد التوصيل / تم التسليم" — the two steps
/// that have NOT happened — and the two that have are over bare track. Pinned
/// in the render test.
@JeebPreview(group: 'live_tracking', name: 'Picked', size: _stepperBox)
Widget orderTrackingStepperPicked() =>
    _hosted('Picked · step 2 of 4', currentStep: 1);

/// En route. The steady state of a live delivery and the one a customer stares
/// at longest.
@JeebPreview(group: 'live_tracking', name: 'In transit', size: _stepperBox)
Widget orderTrackingStepperInTransit() =>
    _hosted('In transit · step 3 of 4', currentStep: 2);

/// P6/A5, made visible: at the door the THIRD step relabels to "At Door" while
/// its Semantics identifier stays `tracking_step_in_transit`.
///
/// There is deliberately no fifth step — the customer keeps the 4-step
/// blueprint (D70) — so this is the one state where the widget's text output
/// differs from its neighbours at the same step index. It is also the only
/// place a reviewer can see that the relabel does not shift the bar: at-door
/// and in-transit both fill to 3/4.
///
/// The regression this guards is asserted from the screen in
/// `test/features/live_tracking/tracking_lifecycle_bodies_test.dart` (case d);
/// this is the same contract with a picture attached.
@JeebPreview(group: 'live_tracking', name: 'At Door', size: _stepperBox)
Widget orderTrackingStepperAtDoor() =>
    _hosted('At Door · step 3 of 4, relabelled', currentStep: 2, atDoor: true);

/// Terminal: the parcel is delivered.
///
/// The state that reads wrong, and the reason this preview exists. `isDone` is
/// `i < currentStep`, so the final step is only ever `isActive` — a completed
/// delivery renders three ticks and one `radio_button_checked` ring, and the
/// stepper never shows itself as finished even though the progress bar
/// underneath is 100% full. Compare this rendering with [orderTrackingStepperInTransit]
/// side by side in the canvas: the last column looks the same in both.
@JeebPreview(group: 'live_tracking', name: 'Delivered', size: _stepperBox)
Widget orderTrackingStepperDelivered() =>
    _hosted('Delivered · step 4 of 4', currentStep: 3);

/// The layout ceiling: the terminal state on the narrowest supported device.
///
/// 320pt over four [Expanded] columns is 80pt per label — and the 200%-text
/// rendering of the matrix is where that runs out. "Ordered" and "Delivered"
/// are single unbreakable words, so `maxLines: 2` cannot rescue them; they are
/// ellipsized, silently, with no overflow stripe to notice it by. The same
/// thing happens one notch less severely at 390pt, where the columns are 97.5pt
/// and every label still overflows — this preview is the narrow end of a
/// problem the phone-width states share, not a device-specific curiosity.
@JeebPreview(group: 'live_tracking', name: 'Delivered on 320pt', size: _compactBox)
Widget orderTrackingStepperCompactPhone() => _hosted(
      'Delivered · step 4 of 4 on a 320pt phone',
      currentStep: 3,
      width: _compactPhoneWidth,
    );
