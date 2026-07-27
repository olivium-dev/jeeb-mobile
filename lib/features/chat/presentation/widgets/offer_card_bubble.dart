import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/delivery_chat_message.dart';
import 'chat_bubble_timestamp.dart';

/// Offer card landing in the broadcasting chat (Figma node 56535:6659).
///
/// Mirrors the Figma layout: a grey incoming-style card carrying the Jeeber's
/// name + inline star rating on the header row, the offer note as the body,
/// and a footer with the timestamp, a navy "Accept Offer" pill, and a Decline
/// button. The screen hands [onAccept]/[onDecline] to the cubit.
class OfferCardBubble extends StatelessWidget {
  const OfferCardBubble({
    super.key,
    required this.message,
    required this.onAccept,
    this.onDecline,
    this.isAccepting = false,
    this.acceptDisabled = false,
  });

  final DeliveryChatMessage message;
  final ValueChanged<String> onAccept;
  final ValueChanged<String>? onDecline;
  final bool isAccepting;
  final bool acceptDisabled;

  @override
  Widget build(BuildContext context) {
    final payload = message.offerPayload;
    if (payload == null) return const SizedBox.shrink();
    return Semantics(
      identifier: 'chat_detail_message_${message.id}',
      child: Padding(
        key: Key('chat-offer-card-${payload.offerId}'),
        padding: const EdgeInsetsDirectional.only(
          start: Spacing.medium,
          end: Spacing.threeXLarge,
          top: Spacing.twoXSmall,
          bottom: Spacing.twoXSmall,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _OfferAvatar(payload: payload),
            const SizedBox(width: Spacing.small),
            Expanded(
              child: _OfferCardBody(
                message: message,
                child: _OfferActions(
                  payload: payload,
                  isAccepting: isAccepting,
                  acceptDisabled: acceptDisabled,
                  onAccept: onAccept,
                  onDecline: onDecline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Accept + Decline row in the offer card footer.
class _OfferActions extends StatelessWidget {
  const _OfferActions({
    required this.payload,
    required this.isAccepting,
    required this.acceptDisabled,
    required this.onAccept,
    this.onDecline,
  });

  final OfferCardPayload payload;
  final bool isAccepting;
  final bool acceptDisabled;
  final ValueChanged<String> onAccept;
  final ValueChanged<String>? onDecline;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onDecline != null) ...[
          _DeclineButton(payload: payload, onDecline: onDecline!),
          const SizedBox(width: Spacing.small),
        ],
        _AcceptButton(
          payload: payload,
          isAccepting: isAccepting,
          acceptDisabled: acceptDisabled,
          onAccept: onAccept,
        ),
      ],
    );
  }
}

/// Navy "Accept Offer" pill in the offer card footer.
class _AcceptButton extends StatelessWidget {
  const _AcceptButton({
    required this.payload,
    required this.isAccepting,
    required this.acceptDisabled,
    required this.onAccept,
  });

  final OfferCardPayload payload;
  final bool isAccepting;
  final bool acceptDisabled;
  final ValueChanged<String> onAccept;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'chat_detail_accept_${payload.offerId}',
      button: true,
      label: '${l10n.chatOfferAccept}: ${payload.jeeberName}, '
          '${payload.fee} ${payload.currency}, '
          '${l10n.chatOfferEtaMinutes(payload.etaMinutes)}',
      child: OmdsPrimaryButton(
        key: Key('chat-offer-accept-${payload.offerId}'),
        text: isAccepting ? l10n.chatOfferAccepting : l10n.chatOfferAccept,
        onTap: () {
          if (acceptDisabled || isAccepting) return;
          onAccept(payload.offerId);
        },
        borderRadius: OmdsBorderRadius.pill,
      ),
    );
  }
}

/// Outlined "Decline" button in the offer card footer.
class _DeclineButton extends StatelessWidget {
  const _DeclineButton({
    required this.payload,
    required this.onDecline,
  });

  final OfferCardPayload payload;
  final ValueChanged<String> onDecline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'chat_detail_decline_${payload.offerId}',
      button: true,
      label: '${l10n.chatOfferDecline}: ${payload.jeeberName}',
      child: OmdsPrimaryButton(
        key: Key('chat-offer-decline-${payload.offerId}'),
        text: l10n.chatOfferDecline,
        onTap: () => onDecline(payload.offerId),
        borderRadius: OmdsBorderRadius.pill,
        variant: OmdsButtonVariant.outlined,
      ),
    );
  }
}

/// Small circular counterpart avatar pinned outside the card, leading edge.
class _OfferAvatar extends StatelessWidget {
  const _OfferAvatar({required this.payload});

  final OfferCardPayload payload;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return OmdsProfileAvatar(
      initial: payload.jeeberName.isEmpty ? 'J' : payload.jeeberName.characters.first,
      profilePicUrl: payload.jeeberAvatarUrl,
      size: Sizes.threeXLarge,
      backgroundColor: colorScheme.surfaceContainer,
      initialColor: colorScheme.primary,
    );
  }
}

/// Grey card body: header (name + stars), note, then footer (time + CTA).
class _OfferCardBody extends StatelessWidget {
  const _OfferCardBody({required this.message, required this.child});

  final DeliveryChatMessage message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final payload = message.offerPayload!;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: const BorderRadiusDirectional.only(
          topStart: Radius.circular(Spacing.twoXSmall),
          topEnd: Radius.circular(Spacing.small),
          bottomStart: Radius.circular(Spacing.small),
          bottomEnd: Radius.circular(Spacing.small),
        ),
      ),
      padding: const EdgeInsets.all(Spacing.medium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OfferHeader(payload: payload),
          const SizedBox(height: Spacing.small),
          _OfferNote(payload: payload),
          const SizedBox(height: Spacing.twoXSmall),
          ChatBubbleTimestamp(
            sentAt: message.sentAt,
            hasServerTimestamp: message.hasServerTimestamp,
          ),
          const SizedBox(height: Spacing.small),
          Align(alignment: AlignmentDirectional.centerEnd, child: child),
        ],
      ),
    );
  }
}

/// Header row: Jeeber name (start) + inline star rating (end).
class _OfferHeader extends StatelessWidget {
  const _OfferHeader({required this.payload});

  final OfferCardPayload payload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            payload.jeeberName,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (payload.rating > 0)
          // a11y (JEBV4-98 / F13): the display suppresses the numeric value and
          // review count, so — unlike offer_card.dart — the bare stars announce
          // nothing to a screen reader. A Semantics label carries the rating.
          Semantics(
            label: l10n.chatOfferRatingA11y(payload.rating.toStringAsFixed(1)),
            child: ExcludeSemantics(
              child: OmdsStarRatingDisplay(
                averageRating: payload.rating,
                starSize: Sizes.medium,
                activeColor: theme.colorScheme.tertiary,
                showRatingValue: false,
                showReviewCount: false,
              ),
            ),
          ),
      ],
    );
  }
}

/// The free-text offer note (Figma copy carries the price inline).
class _OfferNote extends StatelessWidget {
  const _OfferNote({required this.payload});

  final OfferCardPayload payload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = payload.note.isNotEmpty
        ? payload.note
        : AppLocalizations.of(context)
            .chatOfferEtaMinutes(payload.etaMinutes);
    return Text(
      note,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: theme.colorScheme.onSurface,
      ),
    );
  }
}
