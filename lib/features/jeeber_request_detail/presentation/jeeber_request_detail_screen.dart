import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/formatting/friendly_reference.dart';
import '../../../l10n/app_localizations.dart';
import '../../jeeber_home/domain/entities/feed_request.dart';
import '../domain/services/prohibited_item_report_service.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../devtool/catalog/fixtures/jeeber_request_detail_screen_fixtures.dart';
import '../../../core/previews/jeeb_preview.dart';

/// T-mobile-013 / T-MOB-FIX-001: Jeeber request-detail hub.
///
/// Reached from the dashboard feed-row tap (in-app `extra` payload) and from a
/// matching push-notification deep link. This is the ONLY in-app entry to the
/// offer-composition form (`/jeeber/requests/:id/offer`), so it owns the
/// "Make offer" CTA. The route already wires the offer form's `onSubmitted`
/// to `/chat`, so this screen only has to launch it.
class JeeberRequestDetailScreen extends StatefulWidget {
  const JeeberRequestDetailScreen({
    super.key,
    required this.request,
    required this.reportService,
    required this.onDeclined,
  });

  final FeedRequest request;
  final ProhibitedItemReportService reportService;
  final ValueChanged<String> onDeclined;

  @override
  State<JeeberRequestDetailScreen> createState() =>
      _JeeberRequestDetailScreenState();
}

class _JeeberRequestDetailScreenState extends State<JeeberRequestDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: OMDSAppBar(
        title: l10n.jeeberRequestDetailTitle,
        showBackButton: true,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _RequestSummary(request: widget.request)),
            _ActionBar(
              onMakeOffer: _openOfferForm,
              onDecline: () => widget.onDeclined(widget.request.id),
            ),
          ],
        ),
      ),
    );
  }

  void _openOfferForm() {
    context.pushNamed(
      'jeeber-offer-submission',
      pathParameters: {'id': widget.request.id},
    );
  }
}

/// Summary of the [FeedRequest] payload, laid out with the same
/// `OMDSSectionCard` + detail-row idiom as the client-side delivery-details
/// card. Surfaces the request content (G1: `description` — what the customer
/// actually asked for, rendered first and in full), the pickup point, and the
/// request reference. Richer dropoff/fee/distance rows slot in here unchanged
/// once the detail route is upgraded to carry the full `DeliveryRequest`
/// payload (a contract change, out of scope here).
class _RequestSummary extends StatelessWidget {
  const _RequestSummary({required this.request});

  final FeedRequest request;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xLarge),
      child: OMDSSectionCard(
        key: const Key('jeeber-request-detail-summary'),
        title: l10n.jeeberRequestDetailRequestSection,
        content: _RequestSummaryRows(request: request),
      ),
    );
  }
}

/// The genuinely-present fields of the [FeedRequest], one detail row each.
///
/// G1 (sprint-009 P0): the customer's own "What do you need?" text leads the
/// card — it is the content the jeeber is agreeing to buy/deliver, so it
/// renders FIRST, full-length (no truncation), above pickup and reference.
class _RequestSummaryRows extends StatelessWidget {
  const _RequestSummaryRows({required this.request});

  final FeedRequest request;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final description = request.description?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (description != null && description.isNotEmpty) ...[
          Semantics(
            identifier: 'jeeber_request_detail_description',
            child: _DetailRow(
              icon: Icons.shopping_bag_outlined,
              label: l10n.jeeberRequestDetailSectionDescription,
              value: description,
            ),
          ),
          const SizedBox(height: Spacing.medium),
        ],
        _DetailRow(
          icon: Icons.adjust,
          label: l10n.jeeberRequestDetailSectionPickup,
          value: request.shortLabel,
        ),
        const SizedBox(height: Spacing.medium),
        _DetailRow(
          icon: Icons.confirmation_number_outlined,
          label: l10n.jeeberRequestDetailReference,
          value: friendlyReference(request.id),
        ),
      ],
    );
  }
}

/// Icon-badge + label + value row, mirroring the client delivery-details card
/// idiom so jeeber and client detail screens read consistently.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DetailRowBadge(icon: icon),
        const SizedBox(width: Spacing.medium),
        Expanded(
          child: _DetailRowText(label: label, value: value),
        ),
      ],
    );
  }
}

class _DetailRowBadge extends StatelessWidget {
  const _DetailRowBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: Sizes.twoXLarge,
      height: Sizes.twoXLarge,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: Sizes.medium,
        color: colorScheme.onPrimaryContainer,
      ),
    );
  }
}

class _DetailRowText extends StatelessWidget {
  const _DetailRowText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Sizes.threeXSmall),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Bottom action area: primary "Make offer" (the offer-form entry) and an
/// outlined "Decline". Each CTA carries a Semantics identifier for Maestro QA.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.onMakeOffer, required this.onDecline});

  final VoidCallback onMakeOffer;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(Spacing.xLarge),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            identifier: 'jeeber-request-detail-make-offer',
            button: true,
            child: OmdsPrimaryButton(
              text: l10n.offerSubmissionTitle,
              onTap: onMakeOffer,
            ),
          ),
          const SizedBox(height: Spacing.small),
          Semantics(
            identifier: 'jeeber-request-detail-decline',
            button: true,
            child: OmdsPrimaryButton(
              text: l10n.jeeberRequestDetailDeclineButton,
              variant: OmdsButtonVariant.outlined,
              onTap: onDecline,
            ),
          ),
        ],
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
// Render tests:
// test/previews/jeeber_request_detail/jeeber_request_detail_screen_preview_test.dart
// ===========================================================================
//
// [JeeberRequestDetailScreen] is the last surface a jeeber reads before
// bidding, and it is PURELY a function of the [FeedRequest] it is handed: no
// cubit, no repository, no GetIt lookup, nothing async. It therefore has no
// loading and no error state of its own — those belong to
// [JeeberRequestDetailLoader], which chooses between this screen, the loading
// scaffold and [JeeberRequestUnavailableScreen], and which carries its own
// previews in `jeeber_request_detail_loader.dart`. Reviewing "what does the
// jeeber see while it fetches" belongs there; reviewing "what does the jeeber
// decide on once it resolves" belongs here.
//
// Which leaves two axes, and both are below:
//
//   * the PAYLOAD — `description` present, absent, or long, and `shortLabel`
//     present or empty; and
//   * the WINDOW — 390 x 844 vs the 320 x 568 floor, at 100% and 200% text.
//
// The payload is deliberately held constant across the window states (the same
// G1 request appears on the phone, on the compact floor and at 200%) so that
// what changes between those cards is only the geometry.
//
// The states, the seams and the frames all come from
// `lib/devtool/catalog/fixtures/jeeber_request_detail_screen_fixtures.dart`,
// shared VERBATIM with the Screen Catalog entry in
// `lib/devtool/catalog/entries/batch_05_entries.dart` — the two designed states
// a designer signs off against ("With request description (G1)" / "Without
// description") are the same objects here, so the canvas and the catalog cannot
// drift. Two things about that fixture are worth knowing before editing:
//
//   1. Each frame is pinned INSIDE the fixture — a [MediaQuery] override plus a
//      [SizedBox] — rather than left to the canvas [Size]. The canvas honours
//      `size:`, but the render tests pump onto a fixed 800 x 600 surface, so a
//      state that merely ASKED for a 320 x 568 canvas would be measured at
//      800 x 600 and all seven states would collapse into the same widget.
//      Windows that exist FOR a text scale set one; the rest inherit, so
//      `matrix: true` can still render its own 200% card.
//   2. This screen owns its own [Scaffold] and [jeebPreviewHost] wraps every
//      child in one as well, so the canvas shows two nested Scaffolds. The
//      inner one is the real surface; the outer contributes a background and a
//      `SafeArea` — which zeroes `MediaQuery.padding`, and is exactly why each
//      window has to RESTORE the insets or the phone frame would model a
//      bezel-less device.
//
// Network-free by construction, not by the guard: the only injected dependency
// is [ProhibitedItemReportService], whose `report()` is an empty `async` body,
// and the screen never calls it anyway (see below).
//
// WHAT THESE PREVIEWS SHOW THAT THE WIDGET TESTS DO NOT — each pinned as an
// assertion in the render test:
//
// * **An empty pickup label renders as a labelled row with nothing in it.**
//   `description` is trim-guarded and its whole row disappears when blank;
//   `shortLabel` has no such guard, and it does not need to be malformed data
//   to be empty — `DioRequestFeedRepository._parseRequest` deliberately
//   DEGRADES-DON'T-DROPS a feed item with no `pickup` into
//   `RequestLocation(label: '')`, and `_parseFeedLocation` defaults the label
//   to `''` whenever an item carries coordinates but no address. That empty
//   string reaches `FeedRequest.shortLabel` unchanged. `Pickup label empty`
//   is that payload: an icon badge, the word "Pickup", and a blank line where
//   the address should be.
// * **The two CTAs use two different navigation idioms, and only one of them
//   is a declared seam.** `Decline request` calls the injected `onDeclined`
//   immediately — one tap, no confirmation, nothing undoable — while
//   `Send your offer` reaches for an ambient GoRouter
//   (`context.pushNamed('jeeber-offer-submission')`) that the screen's own API
//   never mentions. In the canvas the primary CTA of this screen therefore
//   throws when clicked, and the destructive one works first time.
// * **`reportService` is required, threaded from GetIt through the loader, and
//   never read.** `_openOfferForm` does not use it and `build` does not use it;
//   there is no "report a prohibited item" affordance anywhere on the screen.
//   Every preview below has to construct one to compile, which is the cheapest
//   possible demonstration that it is dead weight.
// * **The action bar does not scale with text, and that is what saves the
//   layout.** 24 dp padding + 48 dp button + 12 dp gap + 48 dp button + 24 dp
//   padding is a FIXED 156 dp whatever the scaler says (`OmdsPrimaryButton`
//   pins `height: Sizes.fourXLarge`), so the `Expanded` summary above it takes
//   the whole hit and simply scrolls — no overflow at 200% on either device.
//   The cost is on the other side of the same coin: the buttons' touch targets
//   and label boxes are frozen at 48 dp for a user who asked for 200% text.
// * **Before any content, a third of the display is already spoken for.** On
//   the reference phone the app bar takes 103 dp (56 + the 47 dp status bar)
//   and the bar takes 156 dp above the 34 dp home indicator its `SafeArea`
//   clears — 293 dp of 844, leaving the summary a 551 dp viewport. On the
//   320 x 568 floor it is 56 + 156 = 212 dp of 568, leaving 356 dp, and that is
//   the window where the ordinary G1 card stops fitting.
// * **The reference row shortens some ids and not others.** `friendlyReference`
//   turns the gateway's UUID into `#775EAE`, but passes `req-101` through
//   verbatim because it starts with a human-reference prefix — so two jeebers
//   looking at two requests can see two different KINDS of reference.

/// The canvas box for a whole screen: a real device plus the fixture's 1 dp
/// outline (12 dp) and its caption strip (44 dp).
const Size _jeeberRequestDetailScreenPhoneCanvas = Size(402, 888);

/// The same, for the 320 x 568 floor.
const Size _jeeberRequestDetailScreenCompactCanvas = Size(332, 612);

/// Ids handed to `onDeclined`, in tap order.
///
/// A "Decline request" button wired to `() {}` looks exactly like one wired to
/// nothing at all, and what is worth reviewing about this one is that it is
/// live on the FIRST tap — no confirmation sheet, no undo. The render test taps
/// it and asserts this moves.
final List<String> jeeberRequestDetailScreenDeclines = <String>[];

/// Resets [jeeberRequestDetailScreenDeclines]; the list is top-level, so one
/// test's taps would otherwise leak into the next.
void jeeberRequestDetailScreenResetDeclines() =>
    jeeberRequestDetailScreenDeclines.clear();

/// Mounts the screen the way `/jeeber/requests/:id` mounts it, in one
/// simulated [JeeberRequestDetailScreenWindow].
///
/// `onDeclined` is the recorder rather than `(_) {}` on purpose — see
/// [jeeberRequestDetailScreenDeclines]. There is nothing to seed for the offer
/// CTA: it does not take a callback.
Widget _jeeberRequestDetailScreenHosted({
  required JeeberRequestDetailScreenWindow window,
  required FeedRequest request,
  required String payloadLabel,
}) =>
    JeeberRequestDetailScreenPreviewHost(
      window: window,
      payloadLabel: payloadLabel,
      screen: JeeberRequestDetailScreen(
        request: request,
        reportService: jeeberRequestDetailScreenReportService,
        onDeclined: jeeberRequestDetailScreenDeclines.add,
      ),
    );

/// The reference reading, and the state the Screen Catalog calls "With request
/// description (G1)": a feed-row tap on a request whose client typed what they
/// need.
///
/// G1 puts that text FIRST and in full, above the pickup and the reference,
/// because it is the thing the jeeber is agreeing to buy. Matrixed because this
/// card is where the three renderings say different things: in AR the row
/// labels and the icon badges mirror while the client's own text stays LTR
/// inside them, and the 200% card is where a three-row card on a phone still
/// has room to spare.
@JeebPreview(
  group: 'jeeber_request_detail',
  name: 'Phone · description present (G1)',
  size: _jeeberRequestDetailScreenPhoneCanvas,
  matrix: true,
)
Widget jeeberRequestDetailScreenFullRequest() =>
    _jeeberRequestDetailScreenHosted(
      window: JeeberRequestDetailScreenWindows.phone,
      request: JeeberRequestDetailScreenRequests.described,
      payloadLabel: 'description present (G1)',
    );

/// The catalog's second designed state: `description` is null, which is legal
/// on the feed DTO and normal on older items.
///
/// The entire description row vanishes — the guard is `description != null &&
/// description.isNotEmpty`, so this degrades cleanly — and the card collapses
/// to a pickup label and a reference. Worth looking at next to the state above
/// for what the jeeber is actually asked to commit to here: an address and an
/// id, with no idea what they are being asked to buy.
@JeebPreview(
  group: 'jeeber_request_detail',
  name: 'Phone · no description (legacy payload)',
  size: _jeeberRequestDetailScreenPhoneCanvas,
)
Widget jeeberRequestDetailScreenNoDescription() =>
    _jeeberRequestDetailScreenHosted(
      window: JeeberRequestDetailScreenWindows.phone,
      request: JeeberRequestDetailScreenRequests.withoutDescription,
      payloadLabel: 'no description (legacy payload)',
    );

/// The longest plausible payload on the reference device: a real shopping list,
/// a pickup label with a landmark in it, and a gateway UUID.
///
/// This is the state that decides whether the summary card scrolls or
/// overflows, because the description is rendered with `maxLines: null` on
/// purpose (G1: the jeeber must read the ENTIRE request before offering). It
/// scrolls, and that is the right answer: `_RequestSummary` is a
/// `SingleChildScrollView` inside an `Expanded`, so a 794 dp card in a 551 dp
/// viewport becomes 291 dp of scroll rather than an overflow, and the action
/// bar under it stays pinned. Matrixed because length is exactly what swings by
/// locale and by scaler.
///
/// (Measured under `flutter_test`, which lays every glyph out as a square of
/// the font size — English measures roughly twice as wide as Inter renders it,
/// so treat the dp counts here as an upper bound and the STRUCTURE as the
/// finding.)
@JeebPreview(
  group: 'jeeber_request_detail',
  name: 'Phone · longest payload',
  size: _jeeberRequestDetailScreenPhoneCanvas,
  matrix: true,
)
Widget jeeberRequestDetailScreenLongest() => _jeeberRequestDetailScreenHosted(
      window: JeeberRequestDetailScreenWindows.phone,
      request: JeeberRequestDetailScreenRequests.longest,
      payloadLabel: 'longest payload',
    );

/// The degraded feed payload: no description AND no pickup label.
///
/// `DioRequestFeedRepository` documents this shape — it degrades a feed item
/// with an unusable `pickup` into `RequestLocation(label: '')` rather than
/// dropping the item, because dropping it "was a second cause of the empty
/// feed". Nothing downstream re-guards that empty string: the row renders its
/// icon badge and the word "Pickup" over a blank line, which reads as a
/// rendering failure rather than as missing data. Compare the description row,
/// which is trim-guarded and disappears entirely.
@JeebPreview(
  group: 'jeeber_request_detail',
  name: 'Phone · pickup label empty (feed degrade)',
  size: _jeeberRequestDetailScreenPhoneCanvas,
)
Widget jeeberRequestDetailScreenUnlabelledPickup() =>
    _jeeberRequestDetailScreenHosted(
      window: JeeberRequestDetailScreenWindows.phone,
      request: JeeberRequestDetailScreenRequests.unlabelledPickup,
      payloadLabel: 'pickup label empty (feed degrade)',
    );

/// The same G1 request on the small-phone floor: 320 x 568, no system chrome.
///
/// The action bar's 156 dp is a much bigger bite out of a 568 dp screen than
/// out of an 844 dp one — 27% against 18% — and it is taken before the content
/// is measured, so the summary is left a 356 dp viewport for a card that needs
/// 394. **This is the first window in which the ORDINARY request scrolls**, at
/// default text, with three short rows in it: 86 dp of the card is below the
/// fold, and what is below the fold is the request reference.
///
/// How much of that is the test font is the open question — `flutter_test`
/// draws square glyphs, so the same three rows wrap onto fewer lines in Inter
/// and may well fit. The reading to take from the canvas, which draws the
/// shipped font, is how little margin there is either way.
@JeebPreview(
  group: 'jeeber_request_detail',
  name: 'Compact 320 × 568',
  size: _jeeberRequestDetailScreenCompactCanvas,
)
Widget jeeberRequestDetailScreenCompact() => _jeeberRequestDetailScreenHosted(
      window: JeeberRequestDetailScreenWindows.compact,
      request: JeeberRequestDetailScreenRequests.described,
      payloadLabel: 'description present (G1)',
    );

/// The accessibility ceiling with the worst content: 200% text on the reference
/// phone, carrying the longest payload.
///
/// Pinned into the tree rather than left to the canvas matrix so the render
/// test measures the same layout the canvas draws. It holds — the summary
/// scrolls and both CTAs stay on screen — because the action bar does not grow.
/// What to read here is the ratio. The description alone measures 2208 dp
/// against a 551 dp viewport: the client's own text, the one thing the jeeber
/// is being asked to price, is four screenfuls of scrolling, while the CTAs
/// that act on it sit frozen at their unscaled 48 dp. Nothing on the screen
/// tells the jeeber there is more of the request below the fold.
@JeebPreview(
  group: 'jeeber_request_detail',
  name: 'Phone · EN 200% · longest payload',
  size: _jeeberRequestDetailScreenPhoneCanvas,
)
Widget jeeberRequestDetailScreenLargeText() =>
    _jeeberRequestDetailScreenHosted(
      window: JeeberRequestDetailScreenWindows.phoneLargeText,
      request: JeeberRequestDetailScreenRequests.longest,
      payloadLabel: 'longest payload',
    );

/// The worst case the app supports: the 320 dp floor at 200% text.
///
/// Both ceilings at once, against a bottom bar that does not shrink — 156 dp of
/// a 568 dp screen spent on two buttons whose labels are frozen at 48 dp while
/// every row above them has doubled. The summary keeps what is left and
/// scrolls, so nothing is clipped; whether "Send your offer" and "Decline
/// request" still FIT inside those 48 dp boxes in the shipped font is a
/// question only the canvas can answer, because widget tests lay text out in
/// the square test font.
@JeebPreview(
  group: 'jeeber_request_detail',
  name: 'Compact 320 × 568 · EN 200%',
  size: _jeeberRequestDetailScreenCompactCanvas,
)
Widget jeeberRequestDetailScreenCompactLargeText() =>
    _jeeberRequestDetailScreenHosted(
      window: JeeberRequestDetailScreenWindows.compactLargeText,
      request: JeeberRequestDetailScreenRequests.described,
      payloadLabel: 'description present (G1)',
    );
