/// Widget previews for [AvailabilityStatusBlock] — run with
/// `flutter widget-preview start`.
///
/// The block is the supporting copy of the Jeeber dashboard's availability
/// control: a status headline, and — only while ONLINE — the active-deliveries
/// count and the auto-offline idle hint. Its entire input is one
/// [AvailabilityViewState] value object; there is no cubit, no gateway and no
/// callback, so these previews are network-free by construction rather than by
/// the guard in [jeebPreviewHost].
///
/// Two things about the host are load-bearing:
///
/// * **The width is a real widget, not just a canvas hint.** `size` on
///   [JeebPreview] sizes the canvas, but the render tests pump on the default
///   800x600 surface where three short lines never run out of room. [_hosted]
///   reproduces the slot `AvailabilityCard` actually gives the block — see
///   [availabilityStatusBlockSlotWidth] — so the canvas and the tests agree,
///   and the AR/200% renderings wrap where they wrap on a phone.
/// * **`loadPhase` is deliberately fixed at `ready`.** The block never reads
///   it; the shimmer and the retry belong to the screen above. Varying it here
///   would produce six identical previews and imply a contract that does not
///   exist.
///
/// What the states are chosen for: in production today `AvailabilityCard`
/// mounts this block from ONE place — `_AvailabilityProgress`, i.e. only while
/// `isToggleInFlight` — so [availabilityStatusBlockGoingOnline] and
/// [availabilityStatusBlockGoingOffline] are the two frames a Jeeber really
/// sees, and the settled states below them are the widget's own contract,
/// currently exercised only by `AvailabilityStatusBlock` itself. See
/// [availabilityStatusBlockAutoOfflineHoldingWork] for the state nobody has
/// looked at.
///
/// `test/jeeber_home_screen_test.dart` pins the screen-level contract (the
/// settled card must NOT render this block); these previews cover the half
/// that test cannot see — what each state looks like at its real width,
/// mirrored in Arabic, and at the 200% accessibility ceiling.
library;

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../features/jeeber_home/application/availability_state.dart';
import '../../features/jeeber_home/domain/entities/availability_status.dart';
import '../../features/jeeber_home/presentation/widgets/availability_status_block.dart';
import '../harness/jeeb_preview.dart';

/// Reference phone width, matching the rest of the preview folder.
const double _phoneWidth = 390;

/// The width `AvailabilityCard` really hands the block, derived from the
/// production composition on a 390pt phone:
///
/// ```
/// 390                       phone
///  - 2 * Spacing.medium      OMDSSectionCard(horizontalPadding: 16)
///  - Spacing.small           the gap in _AvailabilityProgress' Row
///  - Sizes.fiveXLarge        the fixed spinner box beside it
/// = 290
/// ```
///
/// Neither `JeeberNoRequestsView` nor `JeeberFeedTabView` adds gutters around
/// the card, so this is the whole budget. The render test pumps the REAL
/// `AvailabilityCard` at 390pt and asserts the block measures this, so a change
/// to the card's padding or spinner size fails here instead of silently making
/// every preview too wide.
const double availabilityStatusBlockSlotWidth = 290;

/// Breathing room so the canvas shows the block's leading edge rather than the
/// viewport's. Directional-neutral, so it does not mask an RTL defect.
const EdgeInsets _hostPadding = EdgeInsets.all(Spacing.medium);

/// One headline and nothing else: offline, auto-offline, and the in-flight
/// frame of going online.
///
/// Sized from the measurement in the render test, not by eye: the tallest of
/// those at 200% text is auto-offline at 120pt, plus [_hostPadding].
const Size _headlineBox = Size(_phoneWidth, 150);

/// Headline + active-deliveries + idle hint — the full three-line stack.
///
/// Also measured: 76pt at 1x, and 360pt at 200% text once
/// "You're online — receiving requests" wraps to three lines in 290pt. Plus
/// [_hostPadding] that is the whole 400.
const Size _fullStackBox = Size(_phoneWidth, 400);

/// Builds the view state the cubit would emit.
///
/// `loadPhase` is pinned to `ready` on purpose (see the library doc), and
/// `toggleError` is never set: `AvailabilityCubit.toggle` clears
/// `isToggleInFlight` on failure, so the block is unmounted by the time an
/// error is visible and there is no error state for it to render.
AvailabilityViewState _view(
  AvailabilityState state, {
  int activeDeliveryCount = 0,
  bool isToggleInFlight = false,
}) {
  return AvailabilityViewState(
    loadPhase: AvailabilityLoadPhase.ready,
    status: AvailabilityStatus(
      state: state,
      activeDeliveryCount: activeDeliveryCount,
    ),
    isToggleInFlight: isToggleInFlight,
  );
}

/// Drops the block into the slot `AvailabilityCard._AvailabilityProgress`
/// gives it: [availabilityStatusBlockSlotWidth] of content, pinned to the
/// leading edge at the top.
///
/// `topStart` rather than `topLeft` is the point — in the AR RTL rendering the
/// whole block must move to the right edge, and a hardcoded `topLeft` here
/// would hide it if the widget itself ever stopped mirroring.
Widget _hosted(AvailabilityViewState view) {
  return Align(
    alignment: AlignmentDirectional.topStart,
    child: Padding(
      padding: _hostPadding,
      child: SizedBox(
        width: availabilityStatusBlockSlotWidth,
        child: AvailabilityStatusBlock(view: view),
      ),
    ),
  );
}

/// Settled offline — the block collapses to a single line.
///
/// This is the shortest shape it renders, and the baseline every other preview
/// is taller than. Note what is NOT here: no idle hint, because the 8-hour
/// auto-offline rule only applies to an online Jeeber, and no delivery count.
@JeebPreview(name: 'Offline · headline only', size: _headlineBox)
Widget availabilityStatusBlockOffline() =>
    _hosted(_view(AvailabilityState.offline));

/// The system flipped the Jeeber offline (8 h idle / server kick) while TWO
/// deliveries were still assigned to them.
///
/// This state is reachable exactly as written: `AvailabilityCubit._onIdleTick`
/// emits `status.copyWith(state: autoOffline)`, which PRESERVES
/// `activeDeliveryCount`. But `AvailabilityStatusBlock.build` gates both
/// sub-lines on `view.status.isOnline`, so the count silently disappears at the
/// exact moment it matters most — the Jeeber has been taken off the matching
/// engine and still owes two pickups, and this block says only "Automatically
/// taken offline". Compare [availabilityStatusBlockOnlineTwo], which is the
/// same two deliveries and does show them.
///
/// The render test pins the current behaviour so a fix is a deliberate,
/// visible change rather than a silent one.
@JeebPreview(name: 'Auto-offline · 2 deliveries dropped', size: _headlineBox)
Widget availabilityStatusBlockAutoOfflineHoldingWork() =>
    _hosted(_view(AvailabilityState.autoOffline, activeDeliveryCount: 2));

/// Online with an empty queue — the full three-line stack at its shortest.
///
/// Worth its own preview because `availabilityActiveDeliveries(0)` is the one
/// count that is not a number at all: it resolves to the `…Zero` ARB form ("No
/// active deliveries" / "لا توجد توصيلات نشطة"), so a plural table that lost
/// its zero case shows "0 active deliveries" here and nowhere else.
@JeebPreview(name: 'Online · empty queue', size: _fullStackBox)
Widget availabilityStatusBlockOnlineEmpty() =>
    _hosted(_view(AvailabilityState.online));

/// The happy path: online, two deliveries in hand.
///
/// Two is the fixture `test/jeeber_home_screen_test.dart` drives the gateway
/// with, and in Arabic it is the DUAL — `availabilityActiveDeliveriesTwo`
/// ("توصيلتان نشطتان"), a form with no `{count}` placeholder at all. The AR RTL
/// rendering is the only place that distinction is visible.
@JeebPreview(name: 'Online · 2 deliveries', size: _fullStackBox)
Widget availabilityStatusBlockOnlineTwo() =>
    _hosted(_view(AvailabilityState.online, activeDeliveryCount: 2));

/// Toggling ON from offline: `isToggleInFlight` is true while the PUT is in
/// flight and `status` is still the OLD offline snapshot.
///
/// This is one of the only two frames production actually mounts the block in
/// (`AvailabilityCard._AvailabilityProgress`), and it is the asymmetric one —
/// the headline switches to "Updating…" but nothing else appears, so the block
/// is a single line beside a 56pt spinner box.
@JeebPreview(name: 'Going online · in flight', size: _headlineBox)
Widget availabilityStatusBlockGoingOnline() =>
    _hosted(_view(AvailabilityState.offline, isToggleInFlight: true));

/// Toggling OFF while online with three deliveries — the other production
/// frame, and the tallest thing this widget renders.
///
/// `_StatusHeadline` short-circuits to "Updating…" on `isToggleInFlight`, but
/// the `if (view.status.isOnline)` guard below it reads the STALE snapshot, so
/// the block simultaneously says a transition is under way and asserts the
/// pre-transition truth — including "Auto-offline after 8 h idle" for a Jeeber
/// who is in the middle of going offline by hand. Three is also the Arabic
/// `few` plural branch ("3 توصيلات نشطة"), which neither the zero, one nor two
/// forms exercise.
@JeebPreview(name: 'Going offline · in flight, 3 deliveries', size: _fullStackBox)
Widget availabilityStatusBlockGoingOffline() => _hosted(
      _view(
        AvailabilityState.online,
        activeDeliveryCount: 3,
        isToggleInFlight: true,
      ),
    );
