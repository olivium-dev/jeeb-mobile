/// Widget previews for [DeliveryTrackingPanel] — run with
/// `flutter widget-preview start`.
///
/// The panel is a pure function of one value object: it reads
/// [DeliveryTrackingInfo.trackingStepIndex], [DeliveryTrackingInfo.distanceLabel],
/// [DeliveryTrackingInfo.etaMinutes] and [DeliveryTrackingInfo.deadline] and
/// renders nothing else. So every state below is just a hand-built
/// [DeliveryTrackingInfo] — no cubit, no repository, network-free by
/// construction rather than merely by the guard in `jeebPreviewHost`.
///
/// The fixture values are the ones the existing suites already use, so a
/// reviewer is looking at the same rows the tests assert on:
/// `3 km` / `20 min` from `test/order_tracking_screen_test.dart`, `0.0 km` /
/// `0 min` from the Screen Catalog's at-door entry
/// (`lib/devtool/catalog/entries/batch_06_entries.dart`), and the 15:45 locked
/// deadline from `test/features/live_tracking/tracking_deadline_and_straightline_test.dart`.
///
/// Three things these previews surface, all in the widget rather than in the
/// previews — see the notes on the individual states, and the measurements in
/// `test/previews/live_tracking/delivery_tracking_panel_preview_test.dart`:
///
///  * **the stepper labels are clipped at 200% text.**
///    `OMDSLabeledStepperProgress` lays them out in a bare
///    `Row(mainAxisAlignment: spaceBetween)` with no `Flexible` and no
///    ellipsis, so inside the 304pt this panel gets on a 390pt phone the three
///    labels overflow by 257pt and "In transit" is pushed off the edge
///    entirely. Nothing throws at the 800pt default test surface, which is why
///    no existing test sees it.
///  * **the distance unit is never translated.** `distanceLabel` arrives
///    pre-formatted from the gateway and is pasted into the localized frame, so
///    the Arabic line reads `يبعد عنك 128.6 km` — an English unit inside an
///    Arabic sentence. Only the frame is localizable today.
///  * **the fourth line costs 128pt at 200% text.** The three-line block wants
///    276pt and the four-line one 404pt, and the `Column` has no scroll or
///    clip of its own — hence two canvas boxes below rather than one.
library;

import 'package:flutter/material.dart';

import '../../features/live_tracking/domain/delivery_tracking_info.dart';
import '../../features/live_tracking/presentation/widgets/delivery_tracking_panel.dart';
import '../harness/jeeb_preview.dart';

/// The canvas box for the three-line panel: phone width, and tall enough that
/// the 200% rendering is reviewed on its own merits rather than against a box
/// that clips it (the three-line block needs 276pt there).
///
/// Width matters more than usual here: the panel is a `FractionallySizedBox`
/// at 0.78, so it measures 304pt inside this 390pt frame — the same 304pt it
/// gets on a real phone, and the width at which the stepper row breaks. A
/// preview reviewed at the 800pt default test surface would look fine.
///
/// Public, like [deliveryTrackingPanelTallBox], because the render test
/// measures the block against these exact boxes: a preview whose canvas clips
/// its own content shows the reviewer a layout bug that is not there.
const Size deliveryTrackingPanelBox = Size(390, 280);

/// A taller box for the states that mount the fourth (deadline) line, which
/// need 404pt at 200% text.
const Size deliveryTrackingPanelTallBox = Size(390, 420);

/// The LOCKED absolute deadline behind [deliveryTrackingPanelDeadlineLine] and
/// [deliveryTrackingPanelLongHaul].
///
/// Deliberately a **local** `DateTime`, not the `DateTime.utc(...)` the domain
/// parses off the wire: `_TrackingDeadlineLine` renders `deadline.toLocal()`,
/// so a UTC instant would show a different wall clock to every reviewer (and to
/// every CI runner) and the state would not be a fixed state at all. The
/// conversion itself is covered by
/// `test/features/live_tracking/tracking_deadline_and_straightline_test.dart`;
/// what this preview is for is the LINE — that it mounts, where it sits, and
/// what it does to the block in Arabic and at 200% text.
///
/// Exported so the render test formats the expected label through the same
/// `DateFormat.jm` the widget uses, instead of hardcoding a separator character
/// CLDR is free to change.
final DateTime deliveryTrackingPanelLockedDeadline = DateTime(2026, 7, 12, 15, 45);

Widget _hosted({
  TrackingStage stage = TrackingStage.inTransit,
  String? distanceLabel,
  int? etaMinutes,
  DateTime? deadline,
}) =>
    DeliveryTrackingPanel(
      info: DeliveryTrackingInfo(
        deliveryId: 'd-1',
        currentStage: stage,
        stageTimestamps: const <TrackingStage, DateTime>{},
        distanceLabel: distanceLabel,
        etaMinutes: etaMinutes,
        deadline: deadline,
      ),
    );

/// The happy path: a courier in transit with a live GPS fix behind it.
///
/// Third step lit, a real distance and a real ETA. This is the state the panel
/// spends most of a delivery in, and the baseline the four below are read
/// against.
@JeebPreview(group: 'live_tracking', name: 'In transit · live fix', size: deliveryTrackingPanelBox)
Widget deliveryTrackingPanelInTransit() => _hosted(
      distanceLabel: '3 km',
      etaMinutes: 20,
    );

/// Cold start: the delivery exists but no GPS fix has arrived yet.
///
/// The widget's own doc comment names this as the reason the placeholders
/// exist — "Distance + ETA fall back to placeholders while no GPS fix has
/// arrived, rather than showing a stale '0 km'". Both fields are null on the
/// first read of a freshly-accepted delivery, so this is what the customer sees
/// for the seconds between accept and the courier's first upload.
///
/// It is also the state that proves the placeholders are ARB strings: the em
/// dash in "Estimated time: —" survives into Arabic, where the whole line
/// mirrors to `الوقت المقدّر: —`.
@JeebPreview(group: 'live_tracking', name: 'Ordered · awaiting first fix', size: deliveryTrackingPanelBox)
Widget deliveryTrackingPanelAwaitingFix() => _hosted(
      stage: TrackingStage.ordered,
    );

/// Q-061 / D18: the row carries a LOCKED absolute deadline, so the fourth line
/// mounts.
///
/// The conditional `if (info.deadline != null)` means most previews of this
/// widget never see this line at all — pre-fix rows render three lines and this
/// one renders four, and the extra line is 128pt of the block's height at 200%
/// text. Worth its own state for the second reason too: it is the only string
/// in the panel produced by `DateFormat` rather than by the ARB, so it is the
/// only one that can localize *differently* from its neighbours. In Arabic it
/// translates the meridiem (`3:45 PM` → `3:45 م`) and keeps Western digits,
/// which is what makes it agree with the ETA line above it — the render test
/// pins that, because it is a property of intl's `ar` symbols rather than of
/// anything in this repo.
@JeebPreview(group: 'live_tracking', name: 'Locked deadline (Q-061/D18)', size: deliveryTrackingPanelTallBox)
Widget deliveryTrackingPanelDeadlineLine() => _hosted(
      distanceLabel: '2 km',
      etaMinutes: 12,
      deadline: deliveryTrackingPanelLockedDeadline,
    );

/// The courier is at the door: distance has collapsed to `0.0 km` and the ETA
/// to `0 min`.
///
/// Two things to look at, and neither is visible from the happy path:
///
///  * the numeric floor. `0.0 km` and `0 min` are real values, not missing
///    ones, so the panel must NOT fall back to "Distance updating…" here — the
///    null checks in `_TrackingDistanceLine` / `_TrackingEtaLine` are what keep
///    a zero distinct from an absent value.
///  * the stepper does not move. `trackingStepIndex` collapses `atDoor` onto
///    step 2, so a courier standing at the door still reads "In transit" —
///    a recorded product decision (P6/A5), and one that only looks deliberate
///    when you can see it.
@JeebPreview(group: 'live_tracking', name: 'At the door · 0.0 km', size: deliveryTrackingPanelBox)
Widget deliveryTrackingPanelAtDoor() => _hosted(
      stage: TrackingStage.atDoor,
      distanceLabel: '0.0 km',
      etaMinutes: 0,
    );

/// The layout ceiling: an inter-city delivery, every line at its longest and
/// the deadline line mounted on top.
///
/// A three-digit distance, a three-digit ETA and the fourth line together give
/// the widest and tallest block a real delivery can produce inside a 304pt
/// panel. This is the state the **AR RTL** and **EN 200% text** renderings are
/// really for: at 1x English it is unremarkable, at 2x the ETA and distance
/// lines wrap and the stepper's label row runs past the panel edge.
@JeebPreview(group: 'live_tracking', name: 'Long haul · widest lines', size: deliveryTrackingPanelTallBox)
Widget deliveryTrackingPanelLongHaul() => _hosted(
      distanceLabel: '128.6 km',
      etaMinutes: 195,
      deadline: deliveryTrackingPanelLockedDeadline,
    );
