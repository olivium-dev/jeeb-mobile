import 'package:flutter/material.dart';
// `show`: package:intl also exports a `TextDirection`, which would shadow the
// Flutter one this file's LTR-isolated distance depends on.
import 'package:intl/intl.dart' show NumberFormat;
import 'package:omds/omds.dart';

import '../../../core/accessibility/accessibility.dart';
import '../../../core/theme/jeeb_semantic_colors.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../core/widgets/jeeb/jeeb_tier_chip.dart';
import '../../../core/widgets/jeeb/jeeb_waveform.dart';
import '../../../l10n/app_localizations.dart';
import '../data/request_feed_models.dart';

/// The jeeber's feed card, rebuilt to the 24-screen redesign board
/// (`screens/16-jeeber-home.png`, tpl 930–952) per wiring W-2.
///
/// The board's card answers one question — *what is the job, and is it worth
/// my next twenty minutes* — in two rows:
///
/// * **Row 1** — an optional voice mark, the request CONTENT as the headline
///   (this is what the jeeber prices), and how long ago it landed.
/// * **Row 2** — the tier chip, `{distance} · {neighbourhood}`, and exactly
///   one decaying call to action.
///
/// The client's identity (avatar, name, star rating) deliberately **left** this
/// card: it is not what the jeeber decides on, it pushed the job description
/// down the card, and it now lives on the request detail. R5 rations the one
/// orange fill on the screen to the FRESHEST offerable row ([isFreshest]), so
/// "the newest job" is legible from arm's length; every older row's CTA is the
/// same pill in outline.
///
/// Feed-status branches are unchanged:
/// * [JeeberFeedItemStatus.incoming] — Ignore (text rank) + Make offer (pill).
/// * [JeeberFeedItemStatus.pendingResponse] — italic "Pending" status.
/// * [JeeberFeedItemStatus.accepted] — a delivery state-machine action pill.
///
/// G3 graceful exit: when [isExpired] is true (a supplied server `expiresAt`
/// has passed and the card is in its brief linger window), the card is dimmed
/// and the action row is replaced by an "Expired" status — the request never
/// silently vanishes mid-glance. The dim is a STATE, not a transition: R16/R21
/// list the expired-row dimming under *does not move*.
class JeeberFeedCard extends StatelessWidget {
  const JeeberFeedCard({
    super.key,
    required this.request,
    this.onTap,
    this.onIgnore,
    this.onOffer,
    this.onAdvanceStatus,
    this.isActionBusy = false,
    this.isExpired = false,
    this.exposeMakeOfferId = false,
    this.isFreshest = false,
    this.isVoice = false,
  });

  /// Row gutter — the board's 24px page margin (tpl 930). The 8 vertical is
  /// half of R16's measured ~16 gap between two stacked cards.
  static const EdgeInsetsGeometry rowPadding = EdgeInsetsDirectional.symmetric(
    horizontal: Spacing.xLarge,
    vertical: Spacing.xSmall,
  );

  final DeliveryRequest request;

  /// Tap-through to the request detail / chat. `null` makes the card inert.
  final VoidCallback? onTap;

  /// Dismiss the incoming request from the feed.
  final VoidCallback? onIgnore;

  /// Open the offer-submission flow for this request.
  final VoidCallback? onOffer;

  /// Advance the delivery state machine for an accepted request.
  final VoidCallback? onAdvanceStatus;

  /// Whether the accepted-status action button is mid-flight (shows a loader).
  final bool isActionBusy;

  /// G3: a supplied server `expiresAt` has passed and the card is in its linger
  /// window — dimmed, actions replaced by the "Expired" status, taps inert. The
  /// feed cubit removes it after the linger elapses.
  final bool isExpired;

  /// JM-048: when true, this card's offer button additionally carries the
  /// screen-level `feed_make_offer_cta` coined id (in addition to its per-row
  /// `jeeber_feed_request_offer_<id>`). The feed sets it on the FIRST incoming
  /// card only so the QA flow taps an unambiguous make-offer CTA — tapping it
  /// routes through the KYC gate (unapproved) or to the composer (approved),
  /// JM-044/048. Non-incoming cards (pending/accepted) never offer, so the id
  /// is inert for them.
  final bool exposeMakeOfferId;

  /// R5: this is the newest offerable row, so its CTA is the screen's single
  /// orange fill. Every other row's CTA is the same pill, outlined. The feed
  /// computes it from the same `firstIncomingIndex` that drives
  /// [exposeMakeOfferId] — one computation, no new state.
  final bool isFreshest;

  /// Renders the board's waveform mark before the headline. Wired to a literal
  /// `false` today: the feed item carries no `hasAudio`/`audioUrl` flag, and a
  /// guessed voice mark would be a lie about how the request was filed.
  final bool isVoice;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isExpired ? UIConstants.opacityDisabled : 1.0,
      child: Padding(
        padding: rowPadding,
        // The frozen `jeeber_feed_request_card_<id>` rides the kit card itself:
        // it emits one `Semantics(identifier:, button:, container:,
        // explicitChildNodes:)` node — value-identical to the hand-rolled
        // wrapper it replaces, and `explicitChildNodes` is what keeps the
        // nested ignore/offer/action ids independently queryable.
        child: JeebOutlinedCard(
          key: Key('jeeber-feed-card-${request.id}'),
          identifier: 'jeeber_feed_request_card_${request.id}',
          // An expired card is display-only for its linger window.
          onTap: isExpired ? null : onTap,
          child: _CardBody(
            request: request,
            onIgnore: onIgnore,
            onOffer: onOffer,
            onAdvanceStatus: onAdvanceStatus,
            isActionBusy: isActionBusy,
            isExpired: isExpired,
            exposeMakeOfferId: exposeMakeOfferId,
            isFreshest: isFreshest,
            isVoice: isVoice,
          ),
        ),
      ),
    );
  }
}

/// The two-row content model (tpl 931–943).
class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.request,
    required this.onIgnore,
    required this.onOffer,
    required this.onAdvanceStatus,
    required this.isActionBusy,
    required this.isExpired,
    required this.exposeMakeOfferId,
    required this.isFreshest,
    required this.isVoice,
  });

  final DeliveryRequest request;
  final VoidCallback? onIgnore;
  final VoidCallback? onOffer;
  final VoidCallback? onAdvanceStatus;
  final bool isActionBusy;
  final bool isExpired;
  final bool exposeMakeOfferId;
  final bool isFreshest;
  final bool isVoice;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('jeeber-feed-card-content'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeadlineRow(request: request, isVoice: isVoice),
        const SizedBox(height: Spacing.small),
        _MetaRow(
          request: request,
          onIgnore: onIgnore,
          onOffer: onOffer,
          onAdvanceStatus: onAdvanceStatus,
          isActionBusy: isActionBusy,
          isExpired: isExpired,
          exposeMakeOfferId: exposeMakeOfferId,
          isFreshest: isFreshest,
        ),
      ],
    );
  }
}

/// `[mark] {what the client asked for}        {when it landed}` (tpl 932–938).
class _HeadlineRow extends StatelessWidget {
  const _HeadlineRow({required this.request, required this.isVoice});

  final DeliveryRequest request;
  final bool isVoice;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (isVoice) ...[
          const JeebWaveform.cardMark(),
          const SizedBox(width: Spacing.xSmall),
        ],
        Expanded(child: _Headline(request: request)),
        const SizedBox(width: Spacing.xSmall),
        _Timestamp(receivedAt: request.receivedAt),
      ],
    );
  }
}

/// G1 (sprint-009 P0): the request CONTENT — the customer's own "What do you
/// need?" text — is the card's headline, because it is what the jeeber prices.
/// The board gives it one line: the full text lives on the request detail, and
/// a two-line headline pushed the decision row below the fold.
class _Headline extends StatelessWidget {
  const _Headline({required this.request});

  final DeliveryRequest request;

  @override
  Widget build(BuildContext context) {
    final summary = request.itemsSummary?.trim();
    return Text(
      summary != null && summary.isNotEmpty
          ? summary
          // Same fallback chain as before, demoted to a fallback: a request
          // with no description is still a job, and the client's own name is
          // the only other thing the gateway reliably sends.
          : _clientDisplayName(context, request),
      key: const Key('jeeber-feed-card-summary'),
      // `onSurface`: on Midnight `primary` is the brand orange, and R16 draws
      // the headline white — the orange is rationed to the freshest CTA.
      style: context.jeebText.cardTitle.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// `[tier] {distance} · {neighbourhood}     [action]` (tpl 939–943).
class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.request,
    required this.onIgnore,
    required this.onOffer,
    required this.onAdvanceStatus,
    required this.isActionBusy,
    required this.isExpired,
    required this.exposeMakeOfferId,
    required this.isFreshest,
  });

  final DeliveryRequest request;
  final VoidCallback? onIgnore;
  final VoidCallback? onOffer;
  final VoidCallback? onAdvanceStatus;
  final bool isActionBusy;
  final bool isExpired;
  final bool exposeMakeOfferId;
  final bool isFreshest;

  /// Above this text scale the meta row sheds its tier chip so the ONE action
  /// and the distance survive. Same 1.5 threshold — and the same reasoning —
  /// as 24's order-history row: the tier is the most re-derivable thing here.
  static const double largeTextScaleThreshold = 1.5;

  /// Ceiling on the action area's share of the row.
  ///
  /// A `Row` hands its non-flex children unbounded main-axis constraints, so a
  /// pill would otherwise take its intrinsic width and push the row past the
  /// card edge on a narrow handset or in a long-label locale. Capping it makes
  /// the label ellipsize instead — the row can no longer overflow, and the
  /// action still hugs the end edge because the meta line is `Expanded`.
  static const double maxActionFraction = 0.55;

  @override
  Widget build(BuildContext context) {
    final showTier =
        MediaQuery.textScalerOf(context).scale(1) <= largeTextScaleThreshold;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          key: const Key('jeeber-feed-card-footer'),
          children: [
            if (showTier && request.tier != null) ...[
              _TierChip(tier: request.tier!),
              const SizedBox(width: Spacing.xSmall),
            ],
            // Expanded (not Flexible + Spacer): the meta line hugs the start,
            // the slack collects between it and the action, and the action
            // stays flush with the end gutter in both directions.
            Expanded(child: _MetaLine(request: request)),
            const SizedBox(width: Spacing.xSmall),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth * maxActionFraction,
              ),
              child: isExpired
                  ? _ExpiredStatus(requestId: request.id)
                  : _ActionArea(
                      request: request,
                      onIgnore: onIgnore,
                      onOffer: onOffer,
                      onAdvanceStatus: onAdvanceStatus,
                      isActionBusy: isActionBusy,
                      exposeMakeOfferId: exposeMakeOfferId,
                      isFreshest: isFreshest,
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// `1.2 km · Achrafieh` — whichever half the gateway actually sent.
///
/// The separator is a Ø3 dot SHAPE, not a `'·'` string: no l10n key to
/// translate and no bidi hazard when an Arabic neighbourhood name meets a
/// latin-numeric distance (the same call 24's order card makes).
class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.request});

  /// The Ø3 separator dot between the distance and the neighbourhood.
  static const double dotSize = 3;

  final DeliveryRequest request;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = context.jeebText.bodySmall.copyWith(
      color: _mutedInk(context),
    );
    final distance = request.distanceFromYouKm;
    final place = request.pickup.label.trim();
    final hasDistance = distance != null;
    final hasPlace = place.isNotEmpty;
    if (!hasDistance && !hasPlace) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasDistance)
          Flexible(
            child: Text(
              l10n.requestFeedDistance(_formatDistance(context, distance)),
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // A number never reorders: keep `1.2 km` intact in Arabic copy.
              textDirection: TextDirection.ltr,
            ),
          ),
        if (hasDistance && hasPlace) ...[
          const SizedBox(width: Spacing.twoXSmall),
          _MetaDot(color: style.color!),
          const SizedBox(width: Spacing.twoXSmall),
        ],
        if (hasPlace)
          Flexible(
            child: Text(
              place,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  String _formatDistance(BuildContext context, double km) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return NumberFormat.decimalPattern(locale).format(km);
  }
}

class _MetaDot extends StatelessWidget {
  const _MetaDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _MetaLine.dotSize,
      height: _MetaLine.dotSize,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

/// The board's tier pill — one treatment for every tier (tpl 940/949), so the
/// eye reads *which* tier, not a colour-coded severity that does not exist.
class _TierChip extends StatelessWidget {
  const _TierChip({required this.tier});

  final JeeberRequestTier tier;

  @override
  Widget build(BuildContext context) {
    return JeebTierChip(
      tier: _kitTier(tier),
      label: _label(AppLocalizations.of(context)),
    );
  }

  String _label(AppLocalizations l10n) => switch (tier) {
    JeeberRequestTier.flash => l10n.requestFeedTierFlash,
    JeeberRequestTier.light => l10n.requestFeedTierLight,
    JeeberRequestTier.standard => l10n.requestFeedTierStandard,
    JeeberRequestTier.bulk => l10n.requestFeedTierBulk,
  };

  /// The app's four filed tiers onto the kit's glyph set — the same pairing the
  /// pre-redesign card used for its tier tints (light↔eco, bulk↔express).
  JeebTier _kitTier(JeeberRequestTier tier) => switch (tier) {
    JeeberRequestTier.flash => JeebTier.flash,
    JeeberRequestTier.light => JeebTier.eco,
    JeeberRequestTier.standard => JeebTier.standard,
    JeeberRequestTier.bulk => JeebTier.express,
  };
}

/// The card's one secondary ink (time, distance, place, status words).
///
/// Falls back the same way `context.jeebText`/`context.jeebRoles` do rather
/// than `!`-asserting the extension: bare widget hosts theme with
/// `ThemeData.light()`, and a card that throws there is a card nobody can
/// regression-test.
Color _mutedInk(BuildContext context) =>
    (Theme.of(context).extension<JeebSemanticColors>() ??
            JeebSemanticColors.light())
        .mutedText;

String _clientDisplayName(BuildContext context, DeliveryRequest request) {
  final name = request.senderName?.trim() ?? '';
  return name.isNotEmpty
      ? name
      : AppLocalizations.of(context).jeeberFeedAnonymousClient;
}

/// Status-driven action affordance. Branches on [DeliveryRequest.feedStatus]
/// so screens 24/25/26 all render through one card with different action
/// rows, never a phantom gap.
class _ActionArea extends StatelessWidget {
  const _ActionArea({
    required this.request,
    required this.onIgnore,
    required this.onOffer,
    required this.onAdvanceStatus,
    required this.isActionBusy,
    required this.exposeMakeOfferId,
    required this.isFreshest,
  });

  final DeliveryRequest request;
  final VoidCallback? onIgnore;
  final VoidCallback? onOffer;
  final VoidCallback? onAdvanceStatus;
  final bool isActionBusy;
  final bool exposeMakeOfferId;
  final bool isFreshest;

  @override
  Widget build(BuildContext context) {
    return switch (request.feedStatus) {
      JeeberFeedItemStatus.incoming => _IncomingActions(
        requestId: request.id,
        onIgnore: onIgnore,
        onOffer: onOffer,
        exposeMakeOfferId: exposeMakeOfferId,
        isFreshest: isFreshest,
      ),
      JeeberFeedItemStatus.pendingResponse => const _PendingStatus(),
      JeeberFeedItemStatus.accepted => _AcceptedAction(
        requestId: request.id,
        action: request.nextDeliveryAction,
        onTap: onAdvanceStatus,
        isBusy: isActionBusy,
      ),
    };
  }
}

class _IncomingActions extends StatelessWidget {
  const _IncomingActions({
    required this.requestId,
    required this.onIgnore,
    required this.onOffer,
    required this.exposeMakeOfferId,
    required this.isFreshest,
  });

  final String requestId;
  final VoidCallback? onIgnore;
  final VoidCallback? onOffer;
  final bool exposeMakeOfferId;
  final bool isFreshest;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1:2 — doc-13 P1: an even split starved the pill into "Make of…".
        // The CTA is the row's reason to exist, so the secondary word yields
        // first; both stay flexible so a narrow card ellipsizes, never
        // overflows.
        Flexible(
          child: _IgnoreButton(requestId: requestId, onTap: onIgnore),
        ),
        const SizedBox(width: Spacing.twoXSmall),
        Flexible(
          flex: 2,
          child: _OfferPill(
            requestId: requestId,
            onTap: onOffer,
            exposeMakeOfferId: exposeMakeOfferId,
            isFreshest: isFreshest,
          ),
        ),
      ],
    );
  }
}

/// R4: declining is the secondary word, not a red alarm — ignoring a request
/// is routine, and error-red spent the loudest ink in the app on the least
/// consequential tap on the screen.
class _IgnoreButton extends StatelessWidget {
  const _IgnoreButton({required this.requestId, required this.onTap});

  final String requestId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return JeebCtaButton.text(
      key: Key('jeeber-feed-ignore-$requestId'),
      identifier: 'jeeber_feed_request_ignore_$requestId',
      label: AppLocalizations.of(context).jeeberFeedIgnoreAction,
      // The kit's 0/22 default is a footer inset; inside a card row the word
      // only needs to clear the pill beside it, and every px it gives back is
      // a px the neighbourhood name keeps on a 360dp handset.
      contentPadding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.twoXSmall,
      ),
      onTap: onTap ?? () {},
    );
  }
}

/// The one action that decays (R5). The freshest offerable row gets the solid
/// accent pill + its glow; every older row gets the identical pill outlined,
/// so a glance at the feed sorts "new" from "still there" without reading a
/// timestamp.
class _OfferPill extends StatelessWidget {
  const _OfferPill({
    required this.requestId,
    required this.onTap,
    required this.exposeMakeOfferId,
    required this.isFreshest,
  });

  final String requestId;
  final VoidCallback? onTap;

  /// JM-048: expose the screen-level `feed_make_offer_cta` coined id on this
  /// row's offer button (the FIRST incoming card only). The per-row
  /// `jeeber_feed_request_offer_<id>` stays as the inner explicit-child node so
  /// existing T-MOB flows that key off it keep working; the QA JM-048 flow taps
  /// the unambiguous screen-level id (65_W2_TEST_PLAN §2 JM-044/048).
  final bool exposeMakeOfferId;

  final bool isFreshest;

  /// Between the board's 33 and the kit's 50/56 footer heights: this is a
  /// card-row pill, not a docked CTA. `MinTapTarget` still guarantees 48dp.
  static const double pillHeight = 36;

  /// The board's 8/16 pill inset (tpl 943), horizontal only — the height is
  /// fixed above.
  static const EdgeInsetsGeometry pillPadding = EdgeInsetsDirectional.symmetric(
    horizontal: Spacing.medium,
  );

  /// 12.5/w700 on the board; `bodySmall` + w700 is the ramp's nearest.
  static TextStyle pillLabelStyle(BuildContext context) =>
      context.jeebText.bodySmall.copyWith(fontWeight: FontWeight.w700);

  @override
  Widget build(BuildContext context) {
    void handleTap() => (onTap ?? () {})();
    final label = AppLocalizations.of(context).jeeberFeedMakeOfferAction;

    // Wave-A: `JeebCtaButton.accent` carries the accent fill, the `onAccent`
    // ink, the `ctaOrange` lift and `orangePressed` — the Theme-swap +
    // hand-rolled glow this replaced were a pre-kit workaround.
    final Widget pill = isFreshest
        ? JeebCtaButton.accent(
            key: Key('jeeber-feed-offer-$requestId'),
            label: label,
            height: pillHeight,
            expand: false,
            contentPadding: pillPadding,
            labelStyle: pillLabelStyle(context),
            onTap: handleTap,
          )
        : JeebCtaButton.outline(
            key: Key('jeeber-feed-offer-$requestId'),
            label: label,
            height: pillHeight,
            expand: false,
            contentPadding: pillPadding,
            labelStyle: pillLabelStyle(context),
            onTap: handleTap,
          );

    final button = Semantics(
      identifier: 'jeeber_feed_request_offer_$requestId',
      button: true,
      label: label,
      onTap: handleTap,
      child: ExcludeSemantics(
        child: MinTapTarget(onTap: handleTap, child: pill),
      ),
    );
    if (!exposeMakeOfferId) return button;
    return Semantics(
      identifier: 'feed_make_offer_cta',
      button: true,
      container: true,
      explicitChildNodes: true,
      child: button,
    );
  }
}

/// G3 graceful exit: the status line an expired card renders in place of its
/// action row during the linger window ("Expired", hourglass glyph). Carries
/// a per-request Semantics id so QA can assert the state before the sweep
/// collapses the card.
class _ExpiredStatus extends StatelessWidget {
  const _ExpiredStatus({required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context) {
    final color = _mutedInk(context);
    return Semantics(
      identifier: 'jeeber_feed_request_expired_$requestId',
      container: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.hourglass_disabled_outlined,
            size: Sizes.medium,
            color: color,
          ),
          const SizedBox(width: Spacing.twoXSmall),
          Flexible(
            child: Text(
              AppLocalizations.of(context).jeeberFeedStatusExpired,
              key: Key('jeeber-feed-expired-status-$requestId'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.jeebText.bodySmall.copyWith(
                color: color,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingStatus extends StatelessWidget {
  const _PendingStatus();

  @override
  Widget build(BuildContext context) {
    return Text(
      AppLocalizations.of(context).jeeberFeedStatusPending,
      key: const Key('jeeber-feed-pending-status'),
      style: context.jeebText.bodySmall.copyWith(
        color: _mutedInk(context),
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

class _AcceptedAction extends StatelessWidget {
  const _AcceptedAction({
    required this.requestId,
    required this.action,
    required this.onTap,
    required this.isBusy,
  });

  final String requestId;
  final JeeberDeliveryAction? action;
  final VoidCallback? onTap;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Figma 56560:1523 pins a content-hugging periwinkle pill to the END of the
    // accepted-card action row ("Order picked" / "Heading to drop off").
    // `OmdsLoadingButton` is an `AnimatedContainer` with `width: width ??
    // double.infinity`, so with no explicit width it expands to fill the
    // bounded incoming constraint. `IntrinsicWidth` feeds the button a tight
    // content-width constraint so it hugs the label; the meta line's `Expanded`
    // then collects the slack, which pins the hugged pill to the end (and
    // mirrors correctly in AR). Stays 100% OMDS; the `width:` param is the
    // alternative but it would hardcode a magic pixel value.
    return IntrinsicWidth(
      child: Semantics(
        identifier: 'jeeber_feed_request_action_$requestId',
        button: true,
        child: OmdsLoadingButton(
          key: Key('jeeber-feed-action-$requestId'),
          text: _label(AppLocalizations.of(context)),
          isLoading: isBusy,
          borderRadius: OmdsBorderRadius.pill,
          // Unset, OMDS fills from `colorScheme.primary` — orange under
          // Midnight, and R5 already spends this screen's one fill on the CTA.
          backgroundColor: scheme.secondary,
          textColor: scheme.onSecondary,
          onTap: onTap ?? () {},
        ),
      ),
    );
  }

  String _label(AppLocalizations l10n) => switch (action) {
    JeeberDeliveryAction.headingToDropOff =>
      l10n.jeeberFeedActionHeadingToDropOff,
    JeeberDeliveryAction.orderPicked || null => l10n.chatDmOrderPickedAction,
  };
}

/// "2 min ago" — how long the request has been sitting in the feed. A relative
/// age is what makes a feed row read as fresh; a wall clock does not.
class _Timestamp extends StatelessWidget {
  const _Timestamp({required this.receivedAt});

  final DateTime? receivedAt;

  @override
  Widget build(BuildContext context) {
    if (receivedAt == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    // SW-03: `receivedAt` arrives as a UTC instant from the gateway — convert
    // to DEVICE-LOCAL before measuring. Pre-fix the card read the raw UTC
    // fields ("12:31" under a 14:31 status bar), making fresh requests look
    // hours stale.
    final age = DateTime.now().difference(receivedAt!.toLocal());
    final text = age.inHours < 1
        ? l10n.jeeberFeedMinutesAgo(age.inMinutes.clamp(0, 59))
        : age.inDays < 1
        ? l10n.jeeberFeedHoursAgo(age.inHours)
        : l10n.jeeberFeedDaysAgo(age.inDays);
    return Text(
      text,
      key: const Key('jeeber-feed-card-timestamp'),
      style: context.jeebText.caption.copyWith(color: _mutedInk(context)),
    );
  }
}
