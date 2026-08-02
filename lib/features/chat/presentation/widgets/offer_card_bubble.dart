import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/delivery_chat_message.dart';
import 'chat_bubble_timestamp.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

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

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/chat/offer_card_bubble_preview_test.dart
// ===========================================================================

// Widget previews for [OfferCardBubble] — run with
// `flutter widget-preview start`.
//
// [OfferCardBubble] is a pure view over a [DeliveryChatMessage] carrying an
// [OfferCardPayload]: no cubit, no repository, no image fetch (every fixture
// leaves `jeeberAvatarUrl` null, so the avatar always falls back to its
// initial). It is therefore network-free by construction, not merely by the
// guard in [jeebPreviewHost].
//
// The fixture values reuse `test/features/chat/offer_card_bubble_widget_test.dart`
// (Kamal Hajj / $35 / 20 min / rating 4.8 / "Fast delivery guaranteed") so the
// canvas and the widget test describe the same card. The prop combinations
// reuse `chat_screen.dart` `_MessageRow`, which is the only production caller:
//
// ```dart
// onDecline:      isDeclined ? null : (id) => cubit.declineOffer(id),
// isAccepting:    state.acceptingOfferId == offerId,
// acceptDisabled: (state.acceptingOfferId != null && !isAccepting) || isDeclined,
// ```
//
// **Read the canvas knowing this: the footer row overflows on every phone.**
// The Accept + Decline row is a `Row(mainAxisSize: min)` of two intrinsically
// sized `OmdsPrimaryButton`s, and it is simply wider than the card. Measured,
// not guessed:
//
// | rendering                | Accept | Decline | overflow at 390 pt |
// |--------------------------|-------:|--------:|-------------------:|
// | EN light                 |  201.2 |   133.7 |              97 px |
// | AR RTL dark              |  172.0 |    77.0 |              11 px |
// | EN 200% text             |  369.2 |   231.7 |             363 px |
// | EN 200%, Accept only     |  369.2 |       — |             119 px |
//
// At 360 pt (the narrow-phone floor the app supports) EN overflows by 127 px.
// Nothing in `test/` sees this: widget tests pump into an 800×600 viewport
// where the same row has 450 px to spare. That gap — real device width vs test
// viewport — is the whole reason these previews are worth opening, so the
// `size:` boxes below are all real phone widths rather than something roomy
// enough to look clean.
//
// The preview render tests inherit the same 800 px viewport, so they stay
// green; the stripes are a canvas finding, not a test failure.

/// A phone-width card box. Height covers header + note + clock + CTA row.
const Size _offerCardBubbleCardBox = Size(390, 220);

/// Builds the card exactly the way `chat_screen.dart` `_MessageRow` does.
///
/// [declined] collapses the three things production changes at once when the
/// client turns an offer down — 40% opacity, no Decline button, Accept locked —
/// so a preview cannot accidentally show a combination the app never ships.
Widget _offerCardBubbleHosted({
  required String offerId,
  required String jeeberName,
  String note = 'Fast delivery guaranteed',
  double fee = 35.0,
  String currency = 'USD',
  int etaMinutes = 20,
  double rating = 4.8,
  bool isAccepting = false,
  bool acceptDisabled = false,
  bool declined = false,
  bool hasServerTimestamp = true,
}) {
  final Widget card = OfferCardBubble(
    message: DeliveryChatMessage.offerCard(
      id: 'msg-$offerId',
      author: ChatAuthor.them,
      sentAt: DateTime(2026, 6, 1, 12, 34),
      status: MessageStatus.delivered,
      hasServerTimestamp: hasServerTimestamp,
      payload: OfferCardPayload(
        offerId: offerId,
        jeeberId: 'j-$offerId',
        jeeberName: jeeberName,
        fee: fee,
        currency: currency,
        etaMinutes: etaMinutes,
        note: note,
        rating: rating,
      ),
    ),
    onAccept: (_) {},
    onDecline: declined ? null : (_) {},
    isAccepting: isAccepting,
    acceptDisabled: acceptDisabled || declined,
  );
  return declined ? Opacity(opacity: 0.4, child: card) : card;
}

/// The happy path: a live offer in a broadcasting chat, both actions armed.
///
/// This is the reference rendering every other state is read against — and the
/// one that shows the footer overflow at its most ordinary (97 px, EN, 390 pt).
@JeebPreview(group: 'chat', name: 'Live offer', size: _offerCardBubbleCardBox)
Widget offerCardBubbleLiveOffer() => _offerCardBubbleHosted(
      offerId: 'offer-preview-live',
      jeeberName: 'Kamal Hajj',
    );

/// Accept tapped, saga in flight (`state.acceptingOfferId == offerId`).
///
/// Two things to check. The label swaps to "Accepting…" — a *shorter* string in
/// EN than "Accept Offer" (313 px vs 369 at 200% text), so the row visibly
/// twitches narrower mid-flight. And that label is the ONLY progress affordance
/// on the card: there is no spinner and the pill stays fully saturated, so on a
/// slow accept the card looks idle rather than busy.
@JeebPreview(group: 'chat', name: 'Accept in flight', size: _offerCardBubbleCardBox)
Widget offerCardBubbleAccepting() => _offerCardBubbleHosted(
      offerId: 'offer-preview-accepting',
      jeeberName: 'Rami Aoun',
      isAccepting: true,
    );

/// A rival offer is being accepted, so THIS card's Accept is locked
/// (`acceptingOfferId != null && !isAccepting`).
///
/// Put this next to `Live offer` in the canvas: they are pixel-identical. The
/// widget forwards `acceptDisabled` into an early `return` inside `onTap` and
/// never passes `isEnabled: false` to `OmdsPrimaryButton`, so the dead pill
/// keeps the full-strength navy fill, the full-contrast label, and a
/// `Semantics(button: true)` node with no disabled flag. The only feedback for
/// a tap here is nothing happening.
@JeebPreview(group: 'chat', name: 'Accept locked (rival winning)', size: _offerCardBubbleCardBox)
Widget offerCardBubbleAcceptLocked() => _offerCardBubbleHosted(
      offerId: 'offer-preview-locked',
      jeeberName: 'Nour Haddad',
      fee: 42.0,
      etaMinutes: 35,
      acceptDisabled: true,
    );

/// Declined: the 40%-opacity, Accept-only card the timeline keeps in place
/// after the client turns the offer down.
///
/// The only state where the footer holds a single button, which is also the
/// only state that fits at 390 pt in EN at 100% text. Worth checking that 40%
/// opacity over `surfaceContainerHigh` still reads as *dimmed*, not as
/// *disabled chrome*, in the AR RTL **dark** rendering — that is where a
/// low-contrast card disappears into its own background.
@JeebPreview(group: 'chat', name: 'Declined', size: _offerCardBubbleCardBox)
Widget offerCardBubbleDeclined() => _offerCardBubbleHosted(
      offerId: 'offer-preview-declined',
      jeeberName: 'Layla Nasr',
      note: 'I can be there in 15 minutes.',
      fee: 28.0,
      etaMinutes: 15,
      rating: 4.9,
      declined: true,
    );

/// The bare payload a brand-new jeeber sends: no note, no rating yet.
///
/// Two fallbacks fire at once and both are load-bearing:
///
/// * empty `note` → the body degrades to the localized `chatOfferEtaMinutes`
///   line ("ETA 12 min"), which must NOT stay English in the AR rendering;
/// * `rating == 0` → the star row is dropped entirely rather than drawing five
///   empty stars, which would read as "rated zero" instead of "not yet rated".
///
/// It also exposes the gap this widget has no fallback for: `fee` and
/// `currency` are rendered **nowhere**. The Figma copy assumes the jeeber typed
/// the price into the free-text note, so an offer with no note shows the client
/// no price at all — while the Accept button's screen-reader label still
/// announces "$12". A sighted user has less information than a blind one here.
@JeebPreview(group: 'chat', name: 'No note, no rating', size: _offerCardBubbleCardBox)
Widget offerCardBubbleBarePayload() => _offerCardBubbleHosted(
      offerId: 'offer-preview-bare',
      jeeberName: 'Nadine Khoury',
      note: '',
      fee: 12.0,
      etaMinutes: 12,
      rating: 0,
    );

/// Longest plausible content: a full tripartite Arabic-transliterated name and
/// a two-sentence note.
///
/// The name is `Expanded` + `maxLines: 1` + ellipsis, so it must truncate
/// rather than push the stars off the trailing edge; the note has no
/// `maxLines`, so it must wrap and grow the card. In the AR RTL rendering the
/// ellipsis has to land on the *left*. This is also the state where the 200%
/// rendering pushes the CTA row furthest out of the card (363 px).
@JeebPreview(group: 'chat', name: 'Long name + long note', size: Size(390, 320))
Widget offerCardBubbleLongContent() => _offerCardBubbleHosted(
      offerId: 'offer-preview-long',
      jeeberName: 'Abdulrahman Al-Muhandis Al-Trabulsi',
      note: 'I am two streets away and can take the parcel right now, but the '
          'building has no lift so please meet me at the door.',
      fee: 120.0,
      etaMinutes: 90,
      rating: 5.0,
    );

/// A history row the server returned with no usable timestamp
/// (`hasServerTimestamp: false`).
///
/// `ChatBubbleTimestamp` renders nothing rather than a fabricated clock — the
/// regression the `orderAnchor` rework in `delivery_chat_message.dart` was
/// built to make impossible. If this card ever shows `00:00` (or a 1970 date),
/// the anchor has leaked back into a rendered surface.
///
/// Visually it is also the tightest card: dropping the clock removes a whole
/// line, so the CTA row sits directly under the note with only `Spacing.small`
/// between them.
@JeebPreview(group: 'chat', name: 'Undated row (no clock)', size: Size(390, 200))
Widget offerCardBubbleUndated() => _offerCardBubbleHosted(
      offerId: 'offer-preview-undated',
      jeeberName: 'Ziad Sfeir',
      note: 'Still available if you need it.',
      etaMinutes: 25,
      rating: 4.2,
      hasServerTimestamp: false,
    );
