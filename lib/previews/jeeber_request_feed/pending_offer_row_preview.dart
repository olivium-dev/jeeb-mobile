/// Widget previews for [PendingOfferRow] — run with
/// `flutter widget-preview start`.
///
/// The row is pure: it takes an index, a [SubmittedOffer], a busy flag and a
/// callback, and reads nothing off a cubit or a repository. Every state below
/// is therefore network-free by construction — the guard in [jeebPreviewHost]
/// is a net, not the plan — and the only inputs that can change what it renders
/// are the offer's `status`, its `etaMinutes` and the width of the money string
/// [NumberFormat.simpleCurrency] produces for its `currency`.
///
/// That makes the states worth reviewing **lifecycle-shaped** (JM-047/048 open
/// offer versus the sprint-009 terminal badges) and **width-shaped**, which is
/// where a [Row] holding one [Expanded] price next to an inflexible ETA breaks.
///
/// The fixtures reuse the values the existing widget tests already treat as
/// realistic — `price: 12.5, currency: 'USD', etaMinutes: 25`, from
/// `test/features/jeeber_pending_offers/jeeber_pending_offers_screen_test.dart`
/// — so a preview and a failing test describe the same row.
///
/// Four things the canvas shows that no widget test currently asserts, all in
/// the widget and none of them fixed here. All numbers are measured off the
/// render tree at the 390 dp width these previews pin.
///
/// * **Dark mode erases the price.** `_PriceText` paints the money string in
///   `colorScheme.secondaryContainer` — a *container fill* role used as a
///   foreground. The light scheme hand-authors that role as `_jeebNavy`, so it
///   lands at #0B1351 on white and measures **17.13:1**, which is why nobody
///   has noticed. The dark scheme is `ColorScheme.fromSeed`, where the same
///   role is a mid-navy #444559 on a #131318 surface: **1.98:1**, under even
///   the 3:1 large-text floor. The M3 foreground for that fill,
///   `onSecondaryContainer`, measures 14.29:1. The row's most important datum
///   is the one element that disappears — visible in every **AR RTL dark**
///   rendering below.
/// * **At 200% text the price is the only thing that yields.** `_PriceEtaRow`
///   gives the price an [Expanded] and the ETA a bare [Text], so the ETA takes
///   its full intrinsic width first and the price ellipsizes into the
///   remainder. [pendingOfferRowLongContent] at 200%: the price wants 353.6 dp
///   and is given 150 dp in EN, wants 385.9 dp and is given **104 dp** in AR.
///   It is not only the extreme fixture — plain `$18.00`
///   ([pendingOfferRowWithdrawing]) wants 225.2 dp of the 153 dp it gets in AR
///   at 200%, because "دقيقة" is wider than "min".
/// * **200% text overruns both bottom controls.** `OmdsLoadingButton` pins its
///   height to `Sizes.fourXLarge` (48 dp) regardless of text scale, so
///   "Withdraw offer" — which wants 393.4 dp of the 358 dp available — wraps to
///   two ~40 dp lines inside a box that never grows, and the button swells from
///   an intrinsic 197 dp pill to the full 358 dp. The terminal badge fails the
///   other way: `_StatusBadge` sets `maxLines: 1` with no `overflow`, so
///   "Request declined" (wants 392 dp, given 334 dp) is cut mid-word with no
///   ellipsis to say so.
/// * **Two placeholder strings are user-visible.** The awaiting label renders
///   `jeeberFeedStatusPending` → "Pending", not "Awaiting customer decision";
///   a lost offer renders `requestFeedActionDeclinedSnack` → "Request
///   declined", a snackbar string about a jeeber declining a *request*, shown
///   to a jeeber whose *offer* the customer did not pick. Both are deliberate
///   per the widget's own comments (the Semantics id is the asserted contract,
///   the ARB keys are integrator-owned) — the previews are what make it visible
///   that they ship. In light mode the awaiting label also measures 3.76:1
///   (`onSecondaryContainer` on white), under the 4.5:1 AA floor for 12 sp.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omds/omds.dart';

import '../../features/jeeber_request_feed/domain/submitted_offer.dart';
import '../../features/jeeber_request_feed/presentation/pending_offer_row.dart';
import '../harness/jeeb_preview.dart';

/// The width the row actually lays out at on a phone. A widget test pumps an
/// 800 dp surface, where every truncation below disappears, so the previews pin
/// the real width rather than inheriting the canvas.
const double _phoneWidth = 390;

/// An OPEN offer: price + ETA + awaiting label + a 48 dp Withdraw button +
/// divider. Measures 141 dp at 1x and 181 dp at 200% text, so the box is tall
/// enough for the accessibility rendering of the matrix to be readable.
const Size _openRowBox = Size(390, 200);

/// A TERMINAL offer: no awaiting label and no Withdraw button, so the row drops
/// to 89 dp (129 dp at 200% text). A pending list mixing open and terminal
/// offers therefore has two row heights — worth seeing side by side.
const Size _terminalRowBox = Size(390, 140);

/// The row as the feed and the standalone screen build it, pinned to phone
/// width.
///
/// [isWithdrawing] freezes the ticker: `OmdsLoadingButton(isLoading: true)`
/// renders an indeterminate [CircularProgressIndicator], which never stops
/// scheduling frames, and the render tests' `pumpAndSettle` would hang on it.
/// Muting the ticker still paints the arc — it just stops it spinning, which is
/// what a static canvas wanted anyway.
Widget _hosted(
  SubmittedOffer offer, {
  int index = 0,
  bool isWithdrawing = false,
}) {
  final Widget row = PendingOfferRow(
    index: index,
    offer: offer,
    isWithdrawing: isWithdrawing,
    onWithdraw: () {},
  );
  return Align(
    alignment: AlignmentDirectional.topStart,
    child: SizedBox(
      width: _phoneWidth,
      // The row's own [Column] is `MainAxisSize.max`, so handed a bounded
      // height it stretches and parks its divider at the bottom of the canvas.
      // In the app it is a `ListView.builder` item — laid out with unbounded
      // height — so this shrink-wrapping [Column] is what reproduces the real
      // row instead of a canvas artefact.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (isWithdrawing) TickerMode(enabled: false, child: row) else row,
        ],
      ),
    ),
  );
}

/// The default reading, and the state JM-047 AC1/AC2 assert: an offer still
/// awaiting the customer's decision.
///
/// Everything the QA flow keys off is here at once — `pending_offer_0_price`,
/// `_eta`, the shared `pending_offer_awaiting_label` and `_withdraw_cta`. The
/// AR RTL rendering is the mirroring check: the price must move to the right
/// edge and the ETA to its left, because the row is built from
/// [EdgeInsetsDirectional] and [AlignmentDirectional] and nothing here should
/// stay pinned left.
@JeebPreview(name: 'Awaiting decision', size: _openRowBox)
Widget pendingOfferRowAwaiting() => _hosted(
      const SubmittedOffer(
        id: 'pending-offer-jeeber-001',
        requestId: 'req-pending-offer-jeeber-001',
        price: 12.5,
        currency: 'USD',
        etaMinutes: 25,
      ),
    );

/// `DELETE /offer-service/v1/offers/:id` is in flight (D15).
///
/// This is the state [OmdsLoadingButton] was chosen for over
/// `OmdsPrimaryButton`. The button swaps a 20 dp spinner in for its label
/// inside an [AnimatedSwitcher] and keeps its 48 dp box, so the row stays 141
/// dp — no jump against [pendingOfferRowAwaiting] — but it also collapses from
/// a 197 dp pill to a 20 dp disc, so the control moves a long way across the
/// trailing edge on both the way in and the way out.
///
/// What the state does NOT do is dim or disable anything else: the price, the
/// ETA and the awaiting label are untouched, so the only signal that a withdraw
/// is in flight is a 20 dp spinner at the bottom of one row. In a list of ten
/// that is easy to miss, and there is no other affordance to say which offer is
/// busy.
@JeebPreview(name: 'Withdraw in flight', size: _openRowBox)
Widget pendingOfferRowWithdrawing() => _hosted(
      const SubmittedOffer(
        id: 'pending-offer-jeeber-002',
        requestId: 'req-pending-offer-jeeber-002',
        price: 18,
        currency: 'USD',
        etaMinutes: 40,
      ),
      isWithdrawing: true,
    );

/// `etaMinutes` is nullable and the ETA slot disappears entirely when it is
/// null — a jeeber may quote a price without committing to a time.
///
/// The state exists because the ETA is the row's only trailing content: with it
/// gone the [Expanded] price owns the full 358 dp and the row's top line is a
/// lone money string. Worth confirming the price does not stretch or re-align
/// when its neighbour vanishes, in LTR and in RTL.
@JeebPreview(name: 'No ETA', size: _openRowBox)
Widget pendingOfferRowNoEta() => _hosted(
      const SubmittedOffer(
        id: 'pending-offer-jeeber-003',
        requestId: 'req-pending-offer-jeeber-003',
        price: 7.25,
        currency: 'USD',
      ),
    );

/// sprint-009 terminal state: the customer accepted THIS offer.
///
/// The branch that must never regress — a terminal offer shows an outcome badge
/// and **no** Withdraw control, because withdrawing an accepted offer would ask
/// the gateway to delete a bid that has already become a delivery. Compare its
/// height with [pendingOfferRowAwaiting]: 89 dp against 141 dp (129 against 181
/// at 200% text), so a list mixing open and terminal offers has two row
/// heights and a ragged vertical rhythm.
@JeebPreview(name: 'Accepted · terminal', size: _terminalRowBox)
Widget pendingOfferRowAccepted() => _hosted(
      const SubmittedOffer(
        id: 'accepted-1',
        requestId: 'r1',
        price: 9,
        currency: 'USD',
        etaMinutes: 15,
        status: OfferStatus.accepted,
      ),
    );

/// sprint-009 terminal state: the customer accepted somebody else's offer.
///
/// The badge's copy is borrowed: `requestFeedActionDeclinedSnack` ("Request
/// declined") is a snackbar string about a jeeber declining a *request*, so
/// this row currently tells a jeeber whose bid lost that they declined
/// something. Arabic reads the same way — "تم رفض الطلب" is "the request was
/// rejected", not "your offer was not selected".
///
/// The badge's own colours are fine (`onSurfaceVariant` on
/// `surfaceContainerHighest` measures 7.23:1 light / 7.26:1 dark, and the
/// accepted badge 4.55:1 / 7.23:1), which is what makes this state a useful
/// control: in the **AR RTL dark** rendering the deliberately-muted badge is
/// legible while the price above it, painted in a container fill role, is not.
///
/// It is also the state that clips first at 200% text: [Text] with
/// `maxLines: 1` and no `overflow`, so the 392 dp label is cut to the 334 dp
/// the pill allows with no ellipsis to mark the loss.
@JeebPreview(name: 'Not selected · terminal', size: _terminalRowBox)
Widget pendingOfferRowLost() => _hosted(
      const SubmittedOffer(
        id: 'lost-1',
        requestId: 'r2',
        price: 6.5,
        currency: 'USD',
        etaMinutes: 30,
        status: OfferStatus.lost,
      ),
    );

/// The width ceiling: the widest money string the app can produce, next to the
/// widest plausible ETA.
///
/// Lebanese pricing is the real case: LBP is a zero-decimal currency whose
/// everyday amounts run to seven digits, so [NumberFormat.simpleCurrency]
/// produces "L£2,750,000" — 177.6 dp at 1x, twice the width of "$12.50". Put
/// that beside a day-long ETA and the row's asymmetry shows: the ETA is a bare
/// [Text] with no [Flexible], so it takes its full intrinsic width first and
/// the [Expanded] price ellipsizes into whatever is left.
///
/// The English 1x reading fits comfortably (246 dp given, 177.6 wanted) and
/// hides the problem entirely. It is the other two renderings of the matrix
/// that show it: at 200% text the price wants 353.6 dp and is given 150 dp in
/// EN, and in AR — where "1440 دقيقة" costs 242 dp against "1440 min"'s 196 —
/// it wants 385.9 dp and is given **104 dp**. The jeeber ends up looking at
/// "L£2,7…".
@JeebPreview(name: 'Long price + ETA', size: _openRowBox)
Widget pendingOfferRowLongContent() => _hosted(
      const SubmittedOffer(
        id: 'pending-offer-jeeber-004',
        requestId: 'req-pending-offer-jeeber-004',
        price: 2750000,
        currency: 'LBP',
        etaMinutes: 1440,
      ),
    );
