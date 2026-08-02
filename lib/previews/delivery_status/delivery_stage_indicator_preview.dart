/// Widget previews for [DeliveryStageIndicator] — run with
/// `flutter widget-preview start`.
///
/// The indicator is pure-props: it reads exactly three fields off the
/// [DeliverySnapshot] it is handed — `stage`, `lifecycle` and `stageTimestamps`
/// — and paints an OMDS labelled stepper plus four milestone rows. No cubit, no
/// gateway, no DI graph, so these previews are network-free by construction
/// rather than by the guard in [jeebPreviewHost]. [_snapshot] pins the six
/// fields the widget cannot see (`pickup`, `dropoff`, `tier`, `jeeber`,
/// `etaMinutes`, `id`) to the same inert Hamra → Verdun / scooter fixture
/// `test/delivery_status_screen_test.dart` uses, so the states below vary only
/// what the widget can actually read.
///
/// That screen test is the only existing coverage, and it asserts one thing
/// about this widget: that [DeliveryStageIndicator.listKey] is *present*. It
/// never asserts a label, a colour, a timestamp or a stage ordering. These
/// previews are the other half of the contract — the half where four stacked
/// dot+two-line rows and a four-label stepper meet RTL mirroring and the
/// 200%-text ceiling.
///
/// ## Why the tickers are frozen
///
/// The active milestone's dot pulses via `AnimationController.repeat(reverse:
/// true)` — an animation that never ends. `test/previews/preview_test_harness.dart`
/// pumps every preview with `pumpAndSettle`, which by definition waits for
/// frames to STOP being scheduled, so a live repeating ticker makes it spin
/// until its 10-minute fake-time budget and throw. The screen test hits the same
/// wall and works around it by pumping a single frame ("the active-stage pulsing
/// dot uses a repeating AnimationController, so pumpAndSettle never returns").
///
/// [_hosted] therefore wraps every preview in `TickerMode(enabled: false)`.
/// Muting a ticker does not cancel it: `initState` still calls `repeat()`, the
/// controller still reports `isAnimating`, it simply never advances. The dot
/// paints its `t = 0` frame — halo at `Sizes.medium` (16 dp) and `alpha 0.18`,
/// which is the pulse at its *most* visible — so the canvas still shows which
/// milestone is live, deterministically, and the render tests settle. What you
/// lose is the motion itself; what you gain is that these cards mean the same
/// thing every time you look at them.
library;

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../features/delivery_status/domain/delivery_address.dart';
import '../../features/delivery_status/domain/delivery_snapshot.dart';
import '../../features/delivery_status/domain/delivery_stage.dart';
import '../../features/delivery_status/domain/delivery_tier.dart';
import '../../features/delivery_status/presentation/widgets/delivery_stage_indicator.dart';
import '../harness/jeeb_preview.dart';

// Canvas boxes. The heights are measured at 390 dp wide, not guessed — the
// render suite re-measures the 1x figure and fails if the widget grows.
//
//   rendering            height at 390 dp
//   EN 1x                     280
//   AR 1x                     280
//   EN 200%                   504
//   (AR 200%)                 600   — not previewed; see below
//
// Unusually for this folder, the height does NOT vary by state: all four rows
// always render, the labels are ARB constants, and the caption is one line
// whether it says `at 10:21` or `Waiting…`. So one box fits every 1x card and
// a second box covers the two matrix states' 200% column.
//
// AR 200% (600 dp) is not one of the three renderings JeebPreview expands to,
// but it is the real-world worst case — an Arabic user who also raised system
// text size — and it is the tallest column here, because the Arabic stage
// labels wrap where the English ones do not.

/// Every state renders the same four rows, so one box fits them all at 1x.
const Size _indicatorBox = Size(390, 300);

/// The 200%-text box. Used only by the two `matrix: true` states, whose third
/// rendering is the one that needs the room (504 dp measured, 540 declared).
const Size _tallIndicatorBox = Size(390, 540);

/// Applies the screen's own horizontal padding (`_ReadyView`'s
/// `EdgeInsets.fromLTRB` with `Spacing.large` on both sides) so the indicator
/// gets 350 dp inside the declared 390 dp canvas box, exactly as it does on a
/// phone.
///
/// Width is deliberately NOT clamped with a `SizedBox`. The canvas box already
/// supplies it, and the render suite runs on the default 800x600 viewport where
/// a hard clamp would fire the stepper's overflow (see
/// [deliveryStageIndicatorInTransit]) on every one of the twelve render
/// assertions instead of on the one test that is about it.
Widget _hosted(DeliverySnapshot snapshot) {
  return TickerMode(
    // See the library doc: the active dot's repeating controller is muted so
    // the canvas paints a deterministic frame and `pumpAndSettle` terminates.
    enabled: false,
    child: Align(
      alignment: AlignmentDirectional.topStart,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.large),
        child: DeliveryStageIndicator(snapshot: snapshot),
      ),
    ),
  );
}

/// A snapshot whose only meaningful fields are the three the indicator reads.
///
/// The rest are fixed and invisible here. Worth remembering when a bug report
/// says "the stepper showed the wrong thing after the courier changed": this
/// widget cannot see the jeeber, the tier or the ETA at all.
DeliverySnapshot _snapshot({
  required DeliveryStage stage,
  required DeliveryLifecycle lifecycle,
  required Map<DeliveryStage, DateTime> stageTimestamps,
}) {
  return DeliverySnapshot(
    id: 'd-1',
    stage: stage,
    lifecycle: lifecycle,
    stageTimestamps: stageTimestamps,
    pickup: const DeliveryAddress(label: 'Hamra'),
    dropoff: const DeliveryAddress(label: 'Verdun'),
    tier: DeliveryTier.scooter,
  );
}

/// The first milestone a customer ever lands on: a Jeeber has just been
/// assigned and nothing else has happened yet.
///
/// This is the widget at its emptiest, and the emptiness is the point — three
/// of the four rows render the identical `Waiting…` caption stacked under three
/// grey dots, and the stepper is 1/4 filled. Check that the ONE reached row is
/// legible as different: it carries `primary` ink, `w700` weight and the
/// (frozen) pulse halo, against three rows of `onSurfaceVariant`.
///
/// Colour is doing ALL of that work, because the dots are the same shape.
/// `_StageDot` looks like it draws a filled disc for reached and a hollow ring
/// for pending — `border: filled ? null : Border.all(...)` — but the same
/// `Container` sets `color: color` unconditionally, so the "ring" is a solid
/// disc with a same-coloured 1.5 dp border painted over it. The pending dot is
/// a filled `outlineVariant` circle, not an outline. That makes
/// primary-vs-onSurfaceVariant the only signal separating "done" from "not
/// yet", which is worth looking at hard in the dark rendering.
@JeebPreview(group: 'delivery_status', name: 'Matched · active', size: _indicatorBox)
Widget deliveryStageIndicatorMatched() => _hosted(
      _snapshot(
        stage: DeliveryStage.matched,
        lifecycle: DeliveryLifecycle.active,
        stageTimestamps: <DeliveryStage, DateTime>{
          DeliveryStage.matched: DateTime(2026, 5, 17, 10, 0),
        },
      ),
    );

/// Mid-flight: the courier has the parcel and is riding. The canonical state,
/// and the one the whole matrix is for.
///
/// Two rows are reached-and-quiet, one is reached-and-ACTIVE (bold + halo), one
/// is still pending — every visual mode this widget has, in one card. Three
/// things to look at across the three renderings:
///
///   * **AR RTL** — the row is `Row[dot, gap, Expanded(Column)]` with
///     `CrossAxisAlignment.start` and a `SizedBox(width:)` gap, all
///     direction-aware, so the dots must sit on the RIGHT and the labels must
///     be right-aligned. The `Column` inside uses
///     `crossAxisAlignment: start`, which is `end` visually under RTL — if a
///     label ever hugs the wrong edge, this is the card that shows it.
///   * **AR RTL** again, for the caption — `at {time}` becomes
///     `الساعة {time}`, and the digits stay Latin (`الساعة 10:21`). That is
///     what `_formatTime`'s comment promises, but it holds only because the
///     `ar` date symbols `flutter_localizations` registers omit the
///     Arabic-Indic ZERODIGIT that intl's own `ar` data carries. The render
///     suite pins it so the day someone calls
///     `initializeDateFormatting()` earlier in the boot order, these captions
///     do not silently become `١٠:٢١`.
///   * **EN 200%** — the four stepper labels ("Matched", "Picked up",
///     "In transit", "Delivered") are plain `Text` in a `spaceBetween` `Row`
///     with no `Expanded`, no `Flexible` and no `maxLines`
///     (`OMDSLabeledStepperProgress`), so their natural width decides
///     everything. Against 350 dp of track the render suite measures 84 dp of
///     overflow — the yellow-and-black stripe — under the test's fallback
///     font, whose glyphs are wider than the bundled Inter, so treat that as
///     an upper bound at 1x. Double every glyph for the 200% rendering and no
///     font saves it. The defect is OMDS's; this is the app screen that trips
///     it, and the 200% column is where a reviewer sees it.
@JeebPreview(
  group: 'delivery_status',
  name: 'In transit · active',
  size: _tallIndicatorBox,
  matrix: true,
)
Widget deliveryStageIndicatorInTransit() => _hosted(
      _snapshot(
        stage: DeliveryStage.inTransit,
        lifecycle: DeliveryLifecycle.active,
        stageTimestamps: <DeliveryStage, DateTime>{
          DeliveryStage.matched: DateTime(2026, 5, 17, 10, 0),
          DeliveryStage.pickedUp: DateTime(2026, 5, 17, 10, 6),
          DeliveryStage.inTransit: DateTime(2026, 5, 17, 10, 21),
        },
      ),
    );

/// The success terminal: delivered, `lifecycle == completed`, all four
/// timestamps present.
///
/// Every row is reached, so every dot and label is `primary` — and NO row is
/// active, because `_isActive` is gated on `lifecycle == active`. The card
/// should read as four equal, finished rows with no bold row and no halo. If a
/// halo survives here, the `didUpdateWidget` stop/reset path has broken and a
/// finished delivery keeps pulsing at the user.
///
/// It is also the maximum-content state (four captions carrying a time rather
/// than the shorter `Waiting…`), which is why it carries the matrix: the
/// 200% rendering here is the tallest this widget ever gets on a phone.
@JeebPreview(
  group: 'delivery_status',
  name: 'Delivered · completed',
  size: _tallIndicatorBox,
  matrix: true,
)
Widget deliveryStageIndicatorDelivered() => _hosted(
      _snapshot(
        stage: DeliveryStage.delivered,
        lifecycle: DeliveryLifecycle.completed,
        stageTimestamps: <DeliveryStage, DateTime>{
          DeliveryStage.matched: DateTime(2026, 5, 17, 10, 0),
          DeliveryStage.pickedUp: DateTime(2026, 5, 17, 10, 6),
          DeliveryStage.inTransit: DateTime(2026, 5, 17, 10, 21),
          DeliveryStage.delivered: DateTime(2026, 5, 17, 11, 4),
        },
      ),
    );

/// The side-state, and the one worth arguing about: cancelled after the courier
/// had already picked the parcel up.
///
/// `cancelled` is handled by *erasure*. `completedSteps` is forced to 0, so the
/// stepper track empties; `_isReached` returns false for every stage, so all
/// four dots go `outlineVariant` and all four labels go `onSurfaceVariant`. But
/// `stageTimestamps` is untouched, so rows one and two still say
/// **`at 09:12` / `at 09:31`** under a dot that claims the milestone was never
/// reached. The card simultaneously asserts "this never happened" and "this
/// happened at 09:31".
///
/// There is also no *word* for it anywhere on the card. The ARB carries
/// `deliveryStageCancelled` ("Cancelled" / "تم الإلغاء") and this widget never
/// references it — cancellation is communicated only by four dots going grey,
/// which is meaning-by-colour-alone and invisible to anyone who did not see the
/// card a moment earlier. In production `DeliveryLifecycleBanner` carries the
/// sentence, several rows above; in isolation, this widget says nothing.
@JeebPreview(group: 'delivery_status', name: 'Cancelled after pickup', size: _indicatorBox)
Widget deliveryStageIndicatorCancelled() => _hosted(
      _snapshot(
        stage: DeliveryStage.pickedUp,
        lifecycle: DeliveryLifecycle.cancelled,
        stageTimestamps: <DeliveryStage, DateTime>{
          DeliveryStage.matched: DateTime(2026, 5, 17, 9, 12),
          DeliveryStage.pickedUp: DateTime(2026, 5, 17, 9, 31),
        },
      ),
    );

/// Degraded data: the delivery completed, but the gateway only ever emitted the
/// terminal timestamp — the intermediate milestones were never backfilled.
///
/// `stageTimestamps` is documented as "stages that haven't been hit yet are
/// absent from the map", so the widget reads absence as *not yet reached* and
/// prints `Waiting…`. Here that inference is wrong twice over: the first three
/// rows are drawn as REACHED (primary dot, primary label — `_isReached` comes
/// from the stage ordering, not from the map) while their captions read
/// `Waiting…`. A finished delivery therefore shows three rows that are
/// simultaneously done and waiting.
///
/// This is not hypothetical: any path that jumps a delivery straight to
/// `delivered` — a jeeber marking completion offline and syncing once, an
/// admin-forced transition — produces exactly this map. Worth deciding whether
/// the pending caption should be suppressed on a reached row.
@JeebPreview(group: 'delivery_status', name: 'Timestamps not backfilled', size: _indicatorBox)
Widget deliveryStageIndicatorMissingTimestamps() => _hosted(
      _snapshot(
        stage: DeliveryStage.delivered,
        lifecycle: DeliveryLifecycle.completed,
        stageTimestamps: <DeliveryStage, DateTime>{
          DeliveryStage.delivered: DateTime(2026, 5, 18, 0, 4),
        },
      ),
    );

/// A delivery that crosses midnight — the late-night Beirut order, which is a
/// large share of the traffic this app carries.
///
/// `_formatTime` is `DateFormat.Hm`, time-of-day only, no date component at
/// all. So this card reads, top to bottom: **23:47, 23:58, 00:12, 00:35**. Four
/// milestones in correct chronological order, rendered as a list that appears
/// to jump backwards by 23 hours halfway down. Nothing on the card says the
/// delivery spanned two days.
///
/// Same defect, worse consequence, for a delivery that is simply old: a parcel
/// matched yesterday at 10:00 and delivered today at 10:05 renders identically
/// to one that took five minutes. Time-of-day-only captions are only honest for
/// deliveries that start and finish inside one day.
@JeebPreview(group: 'delivery_status', name: 'Across midnight', size: _indicatorBox)
Widget deliveryStageIndicatorAcrossMidnight() => _hosted(
      _snapshot(
        stage: DeliveryStage.delivered,
        lifecycle: DeliveryLifecycle.completed,
        stageTimestamps: <DeliveryStage, DateTime>{
          DeliveryStage.matched: DateTime(2026, 5, 17, 23, 47),
          DeliveryStage.pickedUp: DateTime(2026, 5, 17, 23, 58),
          DeliveryStage.inTransit: DateTime(2026, 5, 18, 0, 12),
          DeliveryStage.delivered: DateTime(2026, 5, 18, 0, 35),
        },
      ),
    );
