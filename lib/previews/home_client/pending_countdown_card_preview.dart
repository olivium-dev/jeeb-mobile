/// Widget previews for [PendingCountdownCard] — run with
/// `flutter widget-preview start`.
///
/// [PendingCountdownCard] is a pure view over one [ClientHomeRequest]: no
/// cubit, no repository, no image fetch. Every fixture below is a plain value
/// object, so these previews are network-free by construction rather than
/// merely by the guard in [jeebPreviewHost].
///
/// The fixture values reuse `test/features/home_client/pending_requests_tab_test.dart`
/// (`ORD-23470` / Achrafieh / Express / 12 min 30 s old) so the canvas and the
/// widget test describe the same card.
///
/// Despite the name there is no countdown here. The gateway list carries no
/// expiry instant, so the card renders the server-owned "Searching for
/// Jeebers…" line and — only when the row carried a real `createdAt` — a
/// past-fact "Created N ago". If a preview ever shows "Expired", the
/// manufactured-deadline lie has come back.
///
/// **Read the canvas knowing this: the "Searching for Jeebers…" row overflows
/// on real phone widths.** `_PendingServerStatus` is a
/// `Row(children: [Icon, SizedBox, Text])` in which the `Text` is neither
/// `Flexible` nor `Expanded` and sets no `overflow`, so it always claims its
/// full single-line intrinsic width and the row runs off the card. Measured on
/// this widget, not guessed — overflow in logical px, `Searching` fixture:
///
/// | text scale | 320 pt | 360 pt | 390 pt | 430 pt |
/// |------------|-------:|-------:|-------:|-------:|
/// | EN 1.0×    |    7   |    —   |    —   |    —   |
/// | EN 1.3×    |   86   |   46   |   16   |    —   |
/// | EN 1.5×    |  139   |   99   |   69   |   29   |
/// | EN 2.0×    |  271   |  231   |  201   |  161   |
/// | AR 2.0×    |  116   |   76   |   46   |    6   |
///
/// So the DEFAULT state of the Pending tab already stripes at 100% text on a
/// 320 pt phone, and from roughly 1.25× on a 390 pt one. The offers-badge
/// states never overflow — `OmdsChip` wraps its own label — which is exactly
/// why the two are previewed side by side.
///
/// Nothing in `test/` sees this: widget tests pump into an 800×600 viewport at
/// 1.0× text, where the same row has ~440 px to spare. That gap — real device
/// width versus test viewport — is the whole reason these previews are worth
/// opening, so the `size:` boxes below are real phone widths (390 pt, plus one
/// at the 320 pt floor) rather than something roomy enough to look clean. The
/// render tests inherit the same 800 px viewport and stay green; the stripes
/// are a canvas finding, not a test failure.
library;

import 'package:flutter/material.dart';

import '../harness/jeeb_preview.dart';
import '../../features/home_client/domain/client_home_request.dart';
import '../../features/home_client/presentation/tabs/pending_requests_tab.dart';

/// Phone width; height clears the tallest (200% text) rendering of the plain
/// searching card.
const Size _cardBox = Size(390, 180);

/// Phone width; height clears the extra line the offers chip adds.
const Size _chipBox = Size(390, 200);

/// Builds the card exactly the way `_PendingList` does — the only production
/// caller — with a live `onTap`, since the tap target is the whole row.
///
/// Defaults mirror the pending fixture in
/// `test/features/home_client/pending_requests_tab_test.dart`.
Widget _hosted({
  required String id,
  String? displayId = 'ORD-23470',
  String title = 'ORD-23470',
  String destinationLabel = 'Achrafieh',
  String? itemsSummary,
  ClientRequestTier tier = ClientRequestTier.express,
  int offerCount = 0,
  bool hasNewOffers = false,
  Duration? age,
}) {
  return PendingCountdownCard(
    request: ClientHomeRequest(
      id: id,
      displayId: displayId,
      title: title,
      // Membership in the pending bucket IS the status; the card never
      // recomputes it from a client clock.
      status: ClientRequestStatus.searching,
      destinationLabel: destinationLabel,
      itemsSummary: itemsSummary,
      tier: tier,
      offerCount: offerCount,
      hasNewOffers: hasNewOffers,
      createdAt: age == null ? null : DateTime.now().toUtc().subtract(age),
    ),
    onTap: () {},
  );
}

/// The default pending state: broadcast, no offers yet, no server timestamp.
///
/// This is the reference rendering every other state is read against, and the
/// one that carries the overflow above at its most ordinary — 201 px of stripes
/// in the EN 200% rendering at 390 pt. Check three things in the canvas: the
/// searching line stays localized in AR (`البحث عن جِيبرين…`, never English);
/// no age line appears at all, because a missing `createdAt` is UNKNOWN rather
/// than zero-age; and the word "Expired" appears nowhere.
@JeebPreview(name: 'Searching (no offers)', size: _cardBox)
Widget pendingCountdownCardSearching() => _hosted(id: 'preview-searching');

/// The same state on the 320 pt narrow-phone floor the app still supports.
///
/// Worth its own card because it is the one rendering where the overflow is
/// visible in the **EN light, 100% text** column — the reading a reviewer
/// actually trusts. At 320 pt the searching row is already 7 px too wide before
/// any accessibility setting is touched, so this is not an a11y-ceiling
/// curiosity: it ships to every small-phone user on the default surface of the
/// client home.
@JeebPreview(name: 'Searching · 320 pt phone', size: Size(320, 180))
Widget pendingCountdownCardSearchingNarrow() => _hosted(
      id: 'preview-narrow',
      displayId: 'ORD-31882',
    );

/// Offers have landed and the sender has not looked yet
/// (`offerCount > 0`, `hasNewOffers`).
///
/// The chip REPLACES the searching line rather than joining it, which is also
/// the fix-by-accident for the overflow above: `OmdsChip` wraps its own label,
/// so this state survives 2.0× text at 320 pt intact. Emphasised (filled) here.
///
/// Note this state is unreachable through the live client-home path — an
/// offer-bearing request is bucketed into Replies — so the canvas is the only
/// place most engineers will ever see it.
@JeebPreview(name: 'New offers (3, unseen)', size: _chipBox)
Widget pendingCountdownCardNewOffers() => _hosted(
      id: 'preview-offers-new',
      displayId: 'ORD-23480',
      offerCount: 3,
      hasNewOffers: true,
    );

/// One offer, already seen (`hasNewOffers: false`) — the tonal chip.
///
/// Put it next to the card above: the ONLY difference production draws between
/// "3 new offers you have not seen" and "1 offer you already read" is
/// `OmdsChip.isSelected`, i.e. a fill. In the AR RTL **dark** rendering, check
/// that the unselected `primaryContainer` fill is still distinguishable from
/// the card surface — if it is not, the unseen/seen distinction is invisible.
/// It also exercises the singular plural form (`1 offer` / `عرض واحد`).
@JeebPreview(name: 'Seen offers (1, tonal)', size: _chipBox)
Widget pendingCountdownCardSeenOffers() => _hosted(
      id: 'preview-offers-seen',
      displayId: 'ORD-23481',
      offerCount: 1,
    );

/// A row the gateway returned WITH a `createdAt`, 12½ minutes ago.
///
/// The age line is a growing past fact ("Created 12 minutes ago"), never a
/// countdown — a future timestamp from clock skew degrades to "just now"
/// instead of going negative. It is also the tallest state: the label has no
/// `maxLines`, so at 200% text it wraps to a second line and the card grows
/// from 129 px to 237 px, which is why this box is the deepest one here.
@JeebPreview(name: 'With created-age line', size: Size(390, 250))
Widget pendingCountdownCardCreatedAge() => _hosted(
      id: 'preview-age',
      displayId: 'ORD-23482',
      age: const Duration(minutes: 12, seconds: 30),
    );

/// Longest plausible content, and three fallbacks firing at once.
///
/// * **No `displayId`** — the header degrades to the raw request `title`, which
///   is the customer's own free-text "What do you need?" line. It is
///   `Expanded` + `maxLines: 1` + ellipsis, so it must truncate rather than
///   push the tier badge off the trailing edge; in AR RTL the ellipsis has to
///   land on the *left*.
/// * **`itemsSummary` present and different from the header** — `summaryLine`
///   prefers it over the destination, at `maxLines: 2`. A second ellipsis to
///   check for mirroring.
/// * **`ClientRequestTier.unknown`** — the mid-deploy fallback for a tier the
///   app has not shipped yet. `ClientHomeTierBadge` renders an EMPTY `Text` for
///   it, so the header keeps a `Spacing.xSmall` gap trailing a badge that draws
///   nothing. Cheap to spot here, invisible in a widget test.
///
/// The searching row overflows in this state too — same root cause, and worth
/// seeing that a long header does nothing to relieve it.
@JeebPreview(name: 'Long content · no id · unknown tier', size: Size(390, 220))
Widget pendingCountdownCardLongContent() => _hosted(
      id: 'preview-long',
      displayId: null,
      title: 'Two kilos of Baalbek potatoes, a 19-litre water gallon and a bag '
          'of medium-roast coffee beans from the shop next to the pharmacy',
      itemsSummary: '2 kg potatoes, 19 L water gallon, medium-roast coffee '
          'beans, 3 boxes of paracetamol, 1 pack of AA batteries',
      destinationLabel: 'Achrafieh, Sassine Square, building 12, 4th floor',
      tier: ClientRequestTier.unknown,
    );
