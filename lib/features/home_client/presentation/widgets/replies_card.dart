import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/client_home_request.dart';

import '../../../../core/previews/jeeb_preview.dart';

/// Replies-tab row: order id, destination, avatar stack, and JM-027/JM-028/JM-029 CTAs.
class RepliesCard extends StatelessWidget {
  const RepliesCard({
    super.key,
    required this.request,
    required this.onCheckOffers,
    required this.onAccept,
  });

  final ClientHomeRequest request;
  final VoidCallback onCheckOffers;
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
      // Semantics boundary: keeps each node queryable for Maestro/screen readers.
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

/// CTA row: IntrinsicWidth-wrapped OMDS buttons must stay 100% OMDS design tokens.
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

/// One reply row: header + one-line summary + the CTA row + divider. Phone
/// width, because `_RepliesActions` is `MainAxisAlignment.end` with no wrap —
const Size repliesCardBox = Size(390, 200);

/// The same box with headroom for the `maxLines: 2` summary the long-content
/// state actually fills.
const Size _repliesCardTallBox = Size(390, 230);

/// A Replies row in the shape `GET /v1/requests?status=offers-received`
/// delivers it: offers are in, no jeeber assigned yet, no ETA, no progress.
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
      offerAvatarUrls: List<String>.filled(avatarCount, ''),
      conversationId: 'conv-$id',
    );

Widget _repliesCardHosted(ClientHomeRequest request) => RepliesCard(
      request: request,
      onCheckOffers: () {},
      onAccept: () {},
    );

/// The Figma reference row (`+6 offers`): nine offers, three inline avatars.
/// Three things have to survive together on one line — an ellipsizing order id
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
/// A Replies row can only exist because offers came in, so this should be
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
/// Also the G1 echo guard, made visible: `itemsSummary` here is byte-identical
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
/// A redelivery order id well past the width of the header, a three-digit
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
