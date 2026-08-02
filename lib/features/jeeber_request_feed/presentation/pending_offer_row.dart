import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/submitted_offer.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';

/// A single submitted-offer row in the feed's Pending-Response sub-tab
/// (JM-047/048): the price the jeeber quoted + ETA + an "Awaiting customer
/// decision" status + a Withdraw control (D15).
///
/// The QA flow (`jm-048` AC3, `jm-047`) keys off the ROW INDEX, not the offer
/// id, so the row carries an index-based `pending_offer_<index>` root plus the
/// `pending_offer_<index>_price` / `_eta` / `_withdraw_cta` children and the
/// shared `pending_offer_awaiting_label` (65_W2_TEST_PLAN §2 JM-047/048).
/// `explicitChildNodes` keeps each child queryable as its own native node
/// rather than folding into the row.
class PendingOfferRow extends StatelessWidget {
  const PendingOfferRow({
    super.key,
    required this.index,
    required this.offer,
    required this.isWithdrawing,
    this.onWithdraw,
  });

  final int index;
  final SubmittedOffer offer;
  final bool isWithdrawing;
  final VoidCallback? onWithdraw;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'pending_offer_$index',
      container: true,
      explicitChildNodes: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.medium,
          vertical: Spacing.small,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PriceEtaRow(index: index, offer: offer),
            const SizedBox(height: Spacing.twoXSmall),
            // sprint-009: a terminal offer (accepted / lost) shows an outcome
            // badge and NO withdraw control; a still-open offer keeps the
            // "awaiting" label + Withdraw (unchanged contract).
            if (offer.status.isTerminal)
              _StatusBadge(index: index, status: offer.status)
            else ...[
              _AwaitingLabel(),
              const SizedBox(height: Spacing.small),
              _WithdrawAction(
                index: index,
                isWithdrawing: isWithdrawing,
                onWithdraw: onWithdraw,
              ),
            ],
            Padding(
              padding: const EdgeInsetsDirectional.only(top: Spacing.small),
              child: Divider(height: 1, color: colorScheme.outlineVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceEtaRow extends StatelessWidget {
  const _PriceEtaRow({required this.index, required this.offer});

  final int index;
  final SubmittedOffer offer;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: _PriceText(index: index, offer: offer)),
        if (offer.etaMinutes != null) ...[
          const SizedBox(width: Spacing.small),
          _EtaText(index: index, etaMinutes: offer.etaMinutes!),
        ],
      ],
    );
  }
}

class _PriceText extends StatelessWidget {
  const _PriceText({required this.index, required this.offer});

  final int index;
  final SubmittedOffer offer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final formatted = NumberFormat.simpleCurrency(
      locale: locale,
      name: offer.currency,
    ).format(offer.price);
    return Semantics(
      identifier: 'pending_offer_${index}_price',
      child: Text(
        formatted,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _EtaText extends StatelessWidget {
  const _EtaText({required this.index, required this.etaMinutes});

  final int index;
  final int etaMinutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'pending_offer_${index}_eta',
      child: Text(
        '$etaMinutes ${l10n.offerSubmissionEtaSuffix}',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        maxLines: 1,
      ),
    );
  }
}

/// sprint-009 offer-lifecycle outcome badge for a TERMINAL offer. Carries the
/// stable `pending_offer_<index>_status` id so a Maestro flow can assert the
/// customer's decision. Reuses the closest existing localized strings
/// (`requestStatusAccepted` / `requestFeedActionDeclinedSnack`) — the asserted
/// contract is the Semantics id, not the visible text (i18n-safe, integrator
/// owns the dedicated ARB keys).
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.index, required this.status});

  final int index;
  final OfferStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isAccepted = status == OfferStatus.accepted;
    final label = isAccepted
        ? l10n.requestStatusAccepted
        : l10n.requestFeedActionDeclinedSnack;
    final fg = isAccepted
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onSurfaceVariant;
    final bg = isAccepted
        ? theme.colorScheme.secondaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    return Semantics(
      identifier: 'pending_offer_${index}_status',
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: Spacing.small,
            vertical: Spacing.twoXSmall,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: OmdsBorderRadius.pill,
          ),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}

class _AwaitingLabel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'pending_offer_awaiting_label',
      child: Text(
        // No dedicated "Awaiting customer decision" key exists yet (JM-047
        // owns it; ARB is integrator-owned, 50_ROUTE_REQUESTS). Reuse the
        // closest existing localized string — the asserted contract is the
        // Semantics id, not the visible text (i18n-safe, CTO brief §6.6).
        AppLocalizations.of(context).jeeberFeedStatusPending,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

class _WithdrawAction extends StatelessWidget {
  const _WithdrawAction({
    required this.index,
    required this.isWithdrawing,
    required this.onWithdraw,
  });

  final int index;
  final bool isWithdrawing;
  final VoidCallback? onWithdraw;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: IntrinsicWidth(
        child: Semantics(
          identifier: 'pending_offer_${index}_withdraw_cta',
          button: true,
          // OmdsLoadingButton (not OmdsPrimaryButton) so the row shows a busy
          // spinner while `DELETE /offer-service/v1/offers/:id` is in flight
          // (the primary button has no loading state). Destructive tint via
          // textColor=error + a tinted surface keeps it visually an outline
          // withdraw control without a magic-pixel border (design-tokens rule).
          child: OmdsLoadingButton(
            key: Key('pending-offer-withdraw-$index'),
            text: AppLocalizations.of(context).offerSubmissionWithdrawButton,
            isLoading: isWithdrawing,
            backgroundColor: theme.colorScheme.errorContainer,
            textColor: theme.colorScheme.onErrorContainer,
            loadingColor: theme.colorScheme.onErrorContainer,
            borderRadius: OmdsBorderRadius.pill,
            onTap: onWithdraw ?? () {},
          ),
        ),
      ),
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
// Render tests: test/previews/jeeber_request_feed/pending_offer_row_preview_test.dart
// ===========================================================================

// Widget previews for [PendingOfferRow] — run with
// `flutter widget-preview start`.
//
// The row is pure: it takes an index, a [SubmittedOffer], a busy flag and a
// callback, and reads nothing off a cubit or a repository. Every state below
// is therefore network-free by construction — the guard in [jeebPreviewHost]
// is a net, not the plan — and the only inputs that can change what it renders
// are the offer's `status`, its `etaMinutes` and the width of the money string
// [NumberFormat.simpleCurrency] produces for its `currency`.
//
// That makes the states worth reviewing **lifecycle-shaped** (JM-047/048 open
// offer versus the sprint-009 terminal badges) and **width-shaped**, which is
// where a [Row] holding one [Expanded] price next to an inflexible ETA breaks.
//
// The fixtures reuse the values the existing widget tests already treat as
// realistic — `price: 12.5, currency: 'USD', etaMinutes: 25`, from
// `test/features/jeeber_pending_offers/jeeber_pending_offers_screen_test.dart`
// — so a preview and a failing test describe the same row.
//
// Four things the canvas shows that no widget test currently asserts, all in
// the widget and none of them fixed here. All numbers are measured off the
// render tree at the 390 dp width these previews pin.
//
// * **Dark mode erases the price.** `_PriceText` paints the money string in
//   `colorScheme.secondaryContainer` — a *container fill* role used as a
//   foreground. The light scheme hand-authors that role as `_jeebNavy`, so it
//   lands at #0B1351 on white and measures **17.13:1**, which is why nobody
//   has noticed. The dark scheme is `ColorScheme.fromSeed`, where the same
//   role is a mid-navy #444559 on a #131318 surface: **1.98:1**, under even
//   the 3:1 large-text floor. The M3 foreground for that fill,
//   `onSecondaryContainer`, measures 14.29:1. The row's most important datum
//   is the one element that disappears — visible in every **AR RTL dark**
//   rendering below.
// * **At 200% text the price is the only thing that yields.** `_PriceEtaRow`
//   gives the price an [Expanded] and the ETA a bare [Text], so the ETA takes
//   its full intrinsic width first and the price ellipsizes into the
//   remainder. [pendingOfferRowLongContent] at 200%: the price wants 353.6 dp
//   and is given 150 dp in EN, wants 385.9 dp and is given **104 dp** in AR.
//   It is not only the extreme fixture — plain `$18.00`
//   ([pendingOfferRowWithdrawing]) wants 225.2 dp of the 153 dp it gets in AR
//   at 200%, because "دقيقة" is wider than "min".
// * **200% text overruns both bottom controls.** `OmdsLoadingButton` pins its
//   height to `Sizes.fourXLarge` (48 dp) regardless of text scale, so
//   "Withdraw offer" — which wants 393.4 dp of the 358 dp available — wraps to
//   two ~40 dp lines inside a box that never grows, and the button swells from
//   an intrinsic 197 dp pill to the full 358 dp. The terminal badge fails the
//   other way: `_StatusBadge` sets `maxLines: 1` with no `overflow`, so
//   "Request declined" (wants 392 dp, given 334 dp) is cut mid-word with no
//   ellipsis to say so.
// * **Two placeholder strings are user-visible.** The awaiting label renders
//   `jeeberFeedStatusPending` → "Pending", not "Awaiting customer decision";
//   a lost offer renders `requestFeedActionDeclinedSnack` → "Request
//   declined", a snackbar string about a jeeber declining a *request*, shown
//   to a jeeber whose *offer* the customer did not pick. Both are deliberate
//   per the widget's own comments (the Semantics id is the asserted contract,
//   the ARB keys are integrator-owned) — the previews are what make it visible
//   that they ship. In light mode the awaiting label also measures 3.76:1
//   (`onSecondaryContainer` on white), under the 4.5:1 AA floor for 12 sp.

/// The width the row actually lays out at on a phone. A widget test pumps an
/// 800 dp surface, where every truncation below disappears, so the previews pin
/// the real width rather than inheriting the canvas.
const double _pendingOfferRowPhoneWidth = 390;

/// An OPEN offer: price + ETA + awaiting label + a 48 dp Withdraw button +
/// divider. Measures 141 dp at 1x and 181 dp at 200% text, so the box is tall
/// enough for the accessibility rendering of the matrix to be readable.
const Size _pendingOfferRowOpenBox = Size(390, 200);

/// A TERMINAL offer: no awaiting label and no Withdraw button, so the row drops
/// to 89 dp (129 dp at 200% text). A pending list mixing open and terminal
/// offers therefore has two row heights — worth seeing side by side.
const Size _pendingOfferRowTerminalBox = Size(390, 140);

/// The row as the feed and the standalone screen build it, pinned to phone
/// width.
///
/// [isWithdrawing] freezes the ticker: `OmdsLoadingButton(isLoading: true)`
/// renders an indeterminate [CircularProgressIndicator], which never stops
/// scheduling frames, and the render tests' `pumpAndSettle` would hang on it.
/// Muting the ticker still paints the arc — it just stops it spinning, which is
/// what a static canvas wanted anyway.
Widget _pendingOfferRowHosted(
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
      width: _pendingOfferRowPhoneWidth,
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
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'Awaiting decision',
  size: _pendingOfferRowOpenBox,
)
Widget pendingOfferRowAwaiting() => _pendingOfferRowHosted(
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
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'Withdraw in flight',
  size: _pendingOfferRowOpenBox,
)
Widget pendingOfferRowWithdrawing() => _pendingOfferRowHosted(
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
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'No ETA',
  size: _pendingOfferRowOpenBox,
)
Widget pendingOfferRowNoEta() => _pendingOfferRowHosted(
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
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'Accepted · terminal',
  size: _pendingOfferRowTerminalBox,
)
Widget pendingOfferRowAccepted() => _pendingOfferRowHosted(
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
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'Not selected · terminal',
  size: _pendingOfferRowTerminalBox,
)
Widget pendingOfferRowLost() => _pendingOfferRowHosted(
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
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'Long price + ETA',
  size: _pendingOfferRowOpenBox,
)
Widget pendingOfferRowLongContent() => _pendingOfferRowHosted(
      const SubmittedOffer(
        id: 'pending-offer-jeeber-004',
        requestId: 'req-pending-offer-jeeber-004',
        price: 2750000,
        currency: 'LBP',
        etaMinutes: 1440,
      ),
    );
