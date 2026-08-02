import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/client_home_request.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

/// Replies-tab row (JM-027 `my-orders` Replies sub-tab) matching the Figma
/// `+6 offers` panel.
///
/// Layout: title + tier badge, destination, stacked avatars of the offerers
/// (`OmdsAvatarStack`-equivalent — built inline because no OMDS primitive yet
/// exposes exactly the overlap-with-counter behavior the Figma wants), and a
/// CTA row carrying two actions per JM-027:
///   * `replies_check_offers_cta` → routes to the `offer-review` list
///     (`/requests/:id/offers`, JM-028), NOT `/chat/:id` (the old divergent
///     behavior the gap map flagged for `my-orders`).
///   * `replies_accept_cta` → opens the `offer-accept-confirm` sheet
///     (`offer_accept_sheet`, JM-029) [D11/D71].
/// Both are dumb callbacks (`onCheckOffers`/`onAccept`); the tab supplies the
/// navigation so the widget stays golden-testable.
class RepliesCard extends StatelessWidget {
  const RepliesCard({
    super.key,
    required this.request,
    required this.onCheckOffers,
    required this.onAccept,
  });

  final ClientHomeRequest request;

  /// Tapped on `replies_check_offers_cta` → offer-review-list (JM-028).
  final VoidCallback onCheckOffers;

  /// Tapped on `replies_accept_cta` → offer-accept-confirm sheet (JM-029).
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      key: Key('replies-card-${request.id}'),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.small,
      ),
      // `explicitChildNodes` makes the card a Semantics *boundary*: without it
      // the column auto-merges the avatar-stack node
      // (`orders_replies_avatar_stack_<id>`, nested in the header) and the CTA
      // button nodes (`replies_check_offers_cta` / `replies_accept_cta`) into
      // one, so only the avatar-stack id survives. The boundary keeps every id
      // as its own queryable node for Maestro and screen readers.
      child: Semantics(
        explicitChildNodes: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RepliesHeader(request: request),
            const SizedBox(height: Spacing.twoXSmall),
            _RepliesSummary(text: request.summaryLine),
            const SizedBox(height: Spacing.small),
            _RepliesActions(
              request: request,
              onCheckOffers: onCheckOffers,
              onAccept: onAccept,
            ),
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

/// Order id on the start, the offerer avatar stack + "+N" count on the end.
class _RepliesHeader extends StatelessWidget {
  const _RepliesHeader({required this.request});

  final ClientHomeRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            request.displayId ?? request.title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: Spacing.xSmall),
        _OfferAvatarStack(
          requestId: request.id,
          avatarUrls: request.offerAvatarUrls,
          totalCount: request.offerCount,
        ),
      ],
    );
  }
}

class _RepliesSummary extends StatelessWidget {
  const _RepliesSummary({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 0.4,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// The two JM-027 reply-card CTAs, pinned to the END of the row (Figma
/// 56535:2251): an outlined secondary "Accept" (`replies_accept_cta` →
/// offer-accept-confirm sheet, JM-029) and the primary "Check Offers"
/// (`replies_check_offers_cta` → offer-review-list, JM-028).
///
/// `OmdsPrimaryButton` / `OmdsOutlinedButton` are width-filling containers, so
/// each is wrapped in `IntrinsicWidth` to hug its label, and the `Row` is
/// end-aligned (`MainAxisAlignment.end`). Stays 100% OMDS (no raw Material
/// button); a hardcoded `width:` would violate the design-tokens rule.
class _RepliesActions extends StatelessWidget {
  const _RepliesActions({
    required this.request,
    required this.onCheckOffers,
    required this.onAccept,
  });

  final ClientHomeRequest request;
  final VoidCallback onCheckOffers;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IntrinsicWidth(
          child: Semantics(
            // JM-027 AC: Accept → offer-accept-confirm sheet (JM-029).
            identifier: 'replies_accept_cta',
            button: true,
            child: OMDSOutlinedButton(
              key: Key('replies-accept-${request.id}'),
              text: l10n.offersCardAccept,
              onTap: onAccept,
              borderRadius: OMDSBorderRadius.pill,
            ),
          ),
        ),
        const SizedBox(width: Spacing.small),
        IntrinsicWidth(
          child: Semantics(
            // JM-027 AC: Check Offers → offer-review-list (JM-028), NOT chat.
            identifier: 'replies_check_offers_cta',
            button: true,
            child: OmdsPrimaryButton(
              key: Key('replies-check-offers-${request.id}'),
              text: l10n.homeRepliesCheckOffersCta,
              onTap: onCheckOffers,
              borderRadius: OmdsBorderRadius.pill,
            ),
          ),
        ),
      ],
    );
  }
}

/// Overlapping offerer avatars followed by a navy "+N" overflow count,
/// matching the Figma `+6` cluster on the end of the Replies card header. No
/// OMDS avatar-stack primitive exists yet — flagged as an extraction candidate
/// for `omds-flutter` (`flutter-component-extraction-aggressive`).
class _OfferAvatarStack extends StatelessWidget {
  const _OfferAvatarStack({
    required this.requestId,
    required this.avatarUrls,
    required this.totalCount,
  });

  static const int _maxInline = 3;

  final String requestId;
  final List<String> avatarUrls;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    if (totalCount == 0) return const SizedBox.shrink();
    final inline = avatarUrls.take(_maxInline).toList(growable: false);
    final extra = totalCount - inline.length;
    return Semantics(
      identifier: 'orders_replies_avatar_stack_$requestId',
      label: '$totalCount',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _OverlappingAvatars(urls: inline),
          if (extra > 0) ...[
            const SizedBox(width: Spacing.twoXSmall),
            _OfferOverflowCount(extra: extra),
          ],
        ],
      ),
    );
  }
}

class _OverlappingAvatars extends StatelessWidget {
  const _OverlappingAvatars({required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    const overlap = Sizes.medium;
    final width = urls.isEmpty
        ? 0.0
        : Sizes.large + (urls.length - 1) * (Sizes.large - overlap);
    return SizedBox(
      width: width,
      height: Sizes.large,
      child: Stack(
        children: [
          for (var i = 0; i < urls.length; i++)
            PositionedDirectional(
              start: i * (Sizes.large - overlap),
              child: _OfferAvatar(url: urls[i]),
            ),
        ],
      ),
    );
  }
}

class _OfferOverflowCount extends StatelessWidget {
  const _OfferOverflowCount({required this.extra});

  final int extra;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      '+$extra',
      style: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _OfferAvatar extends StatelessWidget {
  const _OfferAvatar({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return OmdsProfileAvatar(
      initial: 'J',
      profilePicUrl: url,
      size: Sizes.large,
      backgroundColor: colorScheme.surfaceContainerHigh,
      initialColor: colorScheme.primary,
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
// Render tests: test/previews/home_client/replies_card_preview_test.dart
// ===========================================================================
//
// The card is a pure function of one [ClientHomeRequest] plus two
// [VoidCallback]s: no cubit, no repository, no clock. Every state below is a
// plain value object and two empty closures, which makes these previews
// network-free by construction rather than by the guard in [jeebPreviewHost].
//
// Two deliberate fixture choices:
//
//  * **Empty avatar URLs.** `_OfferAvatar` renders through
//    `OmdsProfileAvatar`, which short-circuits to its initials placeholder when
//    `profilePicUrl` is null or empty and only constructs a network image
//    otherwise. An empty string keeps the canvas off the CDN and — because the
//    placeholder is laid out at the same `Sizes.large` box — preserves the
//    exact geometry this card's layout risk lives in: the overlap ramp and the
//    "+N" cluster, not the image bytes.
//  * **No-op callbacks.** The tab supplies the real navigation
//    (`replies_check_offers_cta` → JM-028, `replies_accept_cta` → JM-029);
//    under the preview host there is no `GoRouter` and no `GetIt`, so a tap
//    must do nothing rather than throw. What these previews review is the CTA
//    ROW's layout — the navigation contract is
//    `test/features/home_client/replies_tab_test.dart`'s job.
//
// Fixture values (`ORD-234xx`, `Hamra, Beirut`, five/nine offers, three
// avatars) are lifted from `test/features/home_client/replies_tab_test.dart`
// so the canvas and the widget test describe the same rows.
//
// The states that matter are the ones where a *derived* value moves: the
// header is `displayId ?? title`, the subtitle is
// [ClientHomeRequest.summaryLine] (which suppresses an echo of the header),
// and the offer cluster is three different shapes depending on how
// `offerCount` compares to the number of avatar URLs — including two shapes
// that render nothing at all.

/// One reply row: header + one-line summary + the CTA row + divider. Phone
/// width, because `_RepliesActions` is `MainAxisAlignment.end` with no wrap —
/// it only overflows when the box is as narrow as a real phone.
///
/// Public because `test/previews/home_client/replies_card_preview_test.dart`
/// pumps into this exact box — the whole point of that suite is that the
/// defects only appear at real phone width.
const Size repliesCardBox = Size(390, 200);

/// The same box with headroom for the `maxLines: 2` summary the long-content
/// state actually fills.
const Size _repliesCardTallBox = Size(390, 230);

/// A Replies row in the shape `GET /v1/requests?status=offers-received`
/// delivers it: offers are in, no jeeber assigned yet, no ETA, no progress.
///
/// [avatarCount] drives how many overlapping circles render; the "+N" cluster
/// shows `offerCount - avatarCount` (clamped by `_maxInline` = 3).
ClientHomeRequest _repliesCardReply({
  required String id,
  String? displayId,
  String? title,
  required int offerCount,
  int avatarCount = 3,
  String destinationLabel = 'Hamra, Beirut',
  String? itemsSummary,
  ClientRequestTier tier = ClientRequestTier.express,
}) =>
    ClientHomeRequest(
      id: id,
      displayId: displayId,
      title: title ?? displayId ?? id,
      status: ClientRequestStatus.offersReceived,
      destinationLabel: destinationLabel,
      itemsSummary: itemsSummary,
      tier: tier,
      offerCount: offerCount,
      // Empty strings on purpose — see the banner prose: the avatar resolves to
      // its initials placeholder instead of reaching for a CDN.
      offerAvatarUrls: List<String>.filled(avatarCount, ''),
      conversationId: 'conv-$id',
    );

Widget _repliesCardHosted(ClientHomeRequest request) => RepliesCard(
      request: request,
      onCheckOffers: () {},
      onAccept: () {},
    );

/// The Figma reference row (`+6 offers`): nine offers, three inline avatars.
///
/// Three things have to survive together on one line — an ellipsizing order id
/// in an [Expanded], the overlap ramp, and the `+6` counter at its intrinsic
/// width. This is the state to read the AR RTL rendering of: the stack is built
/// from `PositionedDirectional`, so if the overlap ever stops mirroring, it
/// stops here first.
///
/// Note what is NOT on this row. The fixture is `ClientRequestTier.flash`, and
/// the card's own class doc promises "title + tier badge" — but
/// `_RepliesHeader` renders no badge of any kind, so Flash, Express and
/// Standard replies are pixel-identical here while the sibling
/// `PendingRequestCard` distinguishes them.
@JeebPreview(
  group: 'home_client',
  name: 'Nine offers · +6',
  size: repliesCardBox,
)
Widget repliesCardWithOverflowCount() => _repliesCardHosted(
      _repliesCardReply(
        id: 'rep-1',
        displayId: 'ORD-23470',
        offerCount: 9,
        tier: ClientRequestTier.flash,
      ),
    );

/// One offer, one avatar: `extra == 0`, so the "+N" counter is hidden entirely
/// and the header is an order id next to a single circle.
///
/// The boundary the counter is gated on — `if (extra > 0)` — is what keeps this
/// row from reading "+0". It is also the first row a sender sees the moment
/// bidding opens, so it is the most common shape of this card, not an edge.
@JeebPreview(
  group: 'home_client',
  name: 'Single offer · no counter',
  size: repliesCardBox,
)
Widget repliesCardSingleOffer() => _repliesCardHosted(
      _repliesCardReply(
        id: 'rep-2',
        displayId: 'ORD-23471',
        offerCount: 1,
        avatarCount: 1,
      ),
    );

/// Offers counted but no avatar URLs — the shape the gateway sends when every
/// offerer is a jeeber with no profile picture on file.
///
/// `inline` is empty, so `_OverlappingAvatars` lays out a zero-width box and
/// the cluster degrades to a bare `+4` floating at the end of the header, with
/// nothing to anchor it. Worth looking at next to `Nine offers · +6`: the same
/// widget, a very different-looking header.
@JeebPreview(
  group: 'home_client',
  name: 'Counted, no avatars',
  size: repliesCardBox,
)
Widget repliesCardCountWithoutAvatars() => _repliesCardHosted(
      _repliesCardReply(
        id: 'rep-3',
        displayId: 'ORD-23472',
        offerCount: 4,
        avatarCount: 0,
      ),
    );

/// Zero offers — the whole cluster collapses to `SizedBox.shrink()`.
///
/// A Replies row can only exist because offers came in, so this should be
/// unreachable; it is reachable anyway whenever the list row omits
/// `offerCount` (the field defaults to `0`) or an offer is withdrawn between
/// the list read and the render. What survives is a card with no offer
/// evidence at all still showing **Accept** and **Check Offers** — two CTAs
/// pointing at an empty offer list. The card has no empty branch of its own,
/// so this is what that looks like.
@JeebPreview(
  group: 'home_client',
  name: 'Zero offers · CTAs still shown',
  size: repliesCardBox,
)
Widget repliesCardZeroOffers() => _repliesCardHosted(
      _repliesCardReply(
        id: 'rep-4',
        displayId: 'ORD-23473',
        offerCount: 0,
        avatarCount: 0,
      ),
    );

/// No `displayId` on the row — the header falls back to [title].
///
/// Also the G1 echo guard, made visible: `itemsSummary` here is byte-identical
/// to the header (the customer's own "What do you need?" text became both), so
/// [ClientHomeRequest.summaryLine] must drop to the destination instead of
/// printing the same sentence twice. If this preview ever shows "Pharmacy run
/// for Mom" on both lines, that guard has regressed.
@JeebPreview(
  group: 'home_client',
  name: 'No display id · echo guard',
  size: repliesCardBox,
)
Widget repliesCardTitleFallback() => _repliesCardHosted(
      _repliesCardReply(
        id: 'rep-5',
        title: 'Pharmacy run for Mom',
        itemsSummary: 'Pharmacy run for Mom',
        destinationLabel: 'Mar Mikhael, Beirut',
        offerCount: 5,
      ),
    );

/// Layout ceiling: the longest row the gateway can actually produce.
///
/// A redelivery order id well past the width of the header, a three-digit
/// counter (`+117`, a broadcast that went wide), and a `summaryLine` built from
/// the customer's own free-text description — that field is `maxLines: 2`, so
/// this is where the two-line clamp is either enough or visibly not.
///
/// The 200% rendering of this preview is the one that matters: `Accept` and
/// `Check Offers` are `IntrinsicWidth` pills inside an end-aligned [Row] with
/// no `Wrap`, `Flexible` or `FittedBox` anywhere, so their combined width
/// scales with the text scale while the 390 dp card does not.
@JeebPreview(
  group: 'home_client',
  name: 'Long content · +117',
  size: _repliesCardTallBox,
)
Widget repliesCardLongContent() => _repliesCardHosted(
      _repliesCardReply(
        id: 'rep-6',
        displayId: 'ORD-23474-EXPRESS-REDELIVERY-ATTEMPT-3',
        offerCount: 120,
        itemsSummary: '1 kilo potato, water gallon, coffee blend, two boxes '
            'of paracetamol, a phone charger and whatever else is still open '
            'at this hour near the pharmacy',
        destinationLabel: 'Rue Gouraud, Gemmayzeh, Beirut',
      ),
    );
