/// Widget previews for [ActiveOrderCard] — run with
/// `flutter widget-preview start`.
///
/// [ActiveOrderCard] is a pure view over one [ClientHomeRequest]: no cubit, no
/// repository, no image fetch (the avatar is an OMDS profile avatar driven by
/// the title's first letter, never a URL). Every fixture below is a plain value
/// object and both callbacks are no-ops, so these previews are network-free by
/// construction, not merely by the guard in [jeebPreviewHost].
///
/// Fixture values reuse `test/features/home_client/in_progress_tab_test.dart`
/// (`_activeRequest`: "Pharmacy run" / "Ashrafieh, Beirut" / Flash) so the
/// canvas and the widget tests describe the same card.
///
/// ## The two CTA gates are the first thing to read this canvas for
///
/// Production (`in_progress_tab.dart` `_ActiveList`) ALWAYS passes a non-null
/// `onOpenChat`, so which pills appear is decided entirely inside the card:
///
/// ```dart
/// _canTrack(s)  => s != delivered && s != cancelled      // Q-085: nearly always
/// _hasJeeber(s) => s == accepted || atPickup || enRoute  // JM-025: chat re-entry
/// ```
///
/// Every fixture therefore passes `onOpenChat` exactly as production does, and
/// the *status* is what varies. A canvas where "Open chat" shows up on the
/// `Searching` card is the phantom-chat regression those two gates were split
/// apart to prevent.
///
/// ## Read the canvas knowing this: two rows overflow at real phone width
///
/// The body column gets `390 − 32` (card padding) `− 40` (avatar) `− 4` (gap)
/// **= 314 pt**. Measured at that width, not guessed:
///
/// | row                        | EN light | AR RTL dark | EN 200% text |
/// |----------------------------|---------:|------------:|-------------:|
/// | actions (chat + track)     |   384 pt |      354 pt |       706 pt |
/// | actions (track only)       |   229 pt |      158 pt |       425 pt |
/// | stage labels (3 × label)   |   265 pt |  **330 pt** |       518 pt |
///
/// Against 314 pt of room that is: the two-pill action row **overflows in every
/// rendering** (EN 70 px, AR 40 px, 200% 392 px); the stage-label row overflows
/// in **Arabic on every card** (16 px) and at 200% text (204 px) even on a card
/// with no buttons at all.
///
/// Nothing under `test/` sees either one: widget tests pump into an 800×600
/// viewport where the same body column has 724 pt and everything fits with
/// room to spare. That gap — real device width vs test viewport — is the whole
/// reason these previews are worth opening, so the `size:` boxes below are real
/// phone widths rather than something roomy enough to look clean. The preview
/// render tests inherit the same 800 pt viewport and stay green; the stripes
/// are a canvas finding, not a test failure.
library;

import 'package:flutter/material.dart';

import '../harness/jeeb_preview.dart';
import '../../features/home_client/domain/client_home_request.dart';
import '../../features/home_client/presentation/widgets/active_request_card.dart';

/// A phone-width card box. The full card lays out at **181 pt** tall at 390 pt
/// (249 pt at 200% text), so 200 pt frames it with the divider visible.
const Size _cardBox = Size(390, 200);

/// A card whose gates are both closed loses the whole action row: **121 pt**
/// instead of 181.
const Size _shortCardBox = Size(390, 140);

/// Builds the card exactly the way `in_progress_tab.dart` `_ActiveList` does:
/// `onTap` = Track, and `onOpenChat` ALWAYS non-null.
///
/// The card's own status gates are what decide which pills render, so no
/// preview here may pass `onOpenChat: null` — doing so would fake a hidden chat
/// pill that production can never produce.
Widget _hosted({
  required String id,
  required String title,
  required ClientRequestStatus status,
  required int progressStep,
  ClientRequestTier tier = ClientRequestTier.flash,
  String destinationLabel = 'Ashrafieh, Beirut',
  String? itemsSummary,
}) =>
    ActiveOrderCard(
      request: ClientHomeRequest(
        id: id,
        title: title,
        status: status,
        destinationLabel: destinationLabel,
        itemsSummary: itemsSummary,
        progressStep: progressStep,
        tier: tier,
      ),
      onTap: () {},
      onOpenChat: () {},
    );

/// The fullest card: a Jeeber is on the road, so BOTH gates are open and the
/// action row carries "Open chat" + "Track my order".
///
/// This is the reference rendering every other state is read against, and the
/// only shape where two pills compete for one row — 384 pt of button in 314 pt
/// of column, so the trailing edge of "Track my order" is cut off on a 390 pt
/// phone. The AR rendering mirrors the overflow to the left edge, which clips
/// the *secondary* pill instead; at 200% text both pills are unreachable.
@JeebPreview(name: 'En route · chat + track', size: _cardBox)
Widget activeOrderCardEnRoute() => _hosted(
      id: 'preview-en-route',
      title: 'Pharmacy run',
      status: ClientRequestStatus.enRoute,
      progressStep: 2,
    );

/// Still searching: the auction is open and NO Jeeber is engaged yet.
///
/// The regression guard, made visible. `onOpenChat` is non-null here exactly as
/// production passes it, so the "Open chat" pill must be suppressed by
/// `_hasJeeber` alone; "Track my order" must still render, because Q-085
/// (option A, ratified) puts the Track CTA on EVERY In-Progress card — even one
/// with no delivery row yet. If this card ever shows "Open chat", widening the
/// Track gate has leaked into the chat gate and clients get a pill that opens
/// an empty conversation.
///
/// It is also the only *fitting* action row: alone, the Track pill is 229 pt
/// and clears 314 pt comfortably. Everything the two-pill card suffers from is
/// the second pill.
@JeebPreview(name: 'Searching · track only', size: _cardBox)
Widget activeOrderCardSearching() => _hosted(
      id: 'preview-searching',
      title: 'Grocery run',
      status: ClientRequestStatus.searching,
      progressStep: 0,
      tier: ClientRequestTier.standard,
    );

/// Terminal state: delivered. Both gates close, so the card renders with NO
/// action row at all.
///
/// Delivered rows are filtered out of In Progress upstream, so this is the
/// defensive shape — and the most useful one in the canvas, because it strips
/// the buttons away and leaves the *stage-label row overflowing on its own* in
/// the AR RTL rendering (330 pt of Arabic labels in 314 pt). A buttonless card
/// that still shows overflow stripes proves that overflow is a localization
/// bug, not a CTA-layout bug.
///
/// Note also what the bar says here: `progressStep: 3` is documented as
/// "AtDoor/Done" and fills the bar completely, while the legend underneath
/// stops at "In Transit". The indicator tops out one stage past its own labels.
@JeebPreview(name: 'Delivered · no actions', size: _shortCardBox)
Widget activeOrderCardDelivered() => _hosted(
      id: 'preview-delivered',
      title: 'Bakery order',
      status: ClientRequestStatus.delivered,
      progressStep: 3,
      tier: ClientRequestTier.express,
    );

/// Content ceiling: the longest plausible title next to the longest plausible
/// items summary (the multi-item `description` G1 now routes into
/// [ClientHomeRequest.summaryLine]).
///
/// The title is `Flexible` + `maxLines: 1` + ellipsis, so it must truncate
/// rather than push the tier badge off the trailing edge; the summary line is
/// `maxLines: 1` + ellipsis too. Put this card next to `En route` in the
/// canvas: they are **exactly the same height** (181 pt). Nothing on this card
/// wraps, so a real 6-item order shows the client "1 kilo potato, water gallon,
/// coff…" and no way to see the rest — the card cannot grow, only clip. In the
/// AR RTL rendering both ellipses have to land on the *left*.
@JeebPreview(name: 'Long title + long summary', size: _cardBox)
Widget activeOrderCardLongContent() => _hosted(
      id: 'preview-long',
      title: 'Pharmacy pickup for Mrs. Haddad on Rue Sursock',
      status: ClientRequestStatus.accepted,
      progressStep: 0,
      itemsSummary: '1 kilo potato, water gallon, coffee blend, two loaves of '
          'brown bread, a bag of ice and paracetamol',
    );

/// Degraded payload: no title and a tier the app does not know.
///
/// Two fallbacks fire at once. `_initial('')` gives the avatar a literal "?"
/// (the deliberate "we know nothing" glyph), and [ClientRequestTier.unknown]
/// resolves to an EMPTY badge label — a 0 pt `Text('')` that still carries its
/// 8 pt leading gap. The header row is therefore blank on both ends and the
/// card's only identifying text is the destination line, while the action row
/// below it is fully armed (`atPickup` opens both gates). A tier the backend
/// adds mid-deploy lands here, so it must degrade rather than crash — but an
/// unlabelled card with live CTAs is worth a design decision, not just a
/// null-safety one.
@JeebPreview(name: 'Untitled · unknown tier', size: _cardBox)
Widget activeOrderCardUntitledUnknownTier() => _hosted(
      id: 'preview-untitled',
      title: '',
      status: ClientRequestStatus.atPickup,
      progressStep: 1,
      tier: ClientRequestTier.unknown,
      destinationLabel: 'Mar Mikhael, Beirut',
    );
