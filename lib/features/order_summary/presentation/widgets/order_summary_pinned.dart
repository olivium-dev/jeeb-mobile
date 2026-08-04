import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_radii.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_avatar.dart';
import '../../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../../core/widgets/jeeb/jeeb_tier_chip.dart';
import '../../domain/order_summary.dart';
import '../order_summary_l10n.dart';

/// Ticket radius — R12's own slab (`JeebRadii.xl`, board `border-radius:22px`).
/// The shipped 20 was off the §5 ladder; the two screens are the same object.
const double _ticketRadius = JeebRadii.xl;

/// R12's `_kTicketTopGap`: board `margin:22px` above the ticket, less the top
/// bar's 4dp tap overhang.
const double _ticketTopGap = 18;

/// JM-031 — the pinned order-summary header WIDGET (CTO-D3 primary rendering).
///
/// A reusable, self-contained strip that hosts inject into BOTH `order-chat`
/// (JM-025) and `order-tracking` (JM-032) so the customer always sees the
/// authoritative, locked snapshot of their accepted order (D71): accepted COD
/// price, Jeeber name + rating (D6), ETA, tier, item summary, and the
/// "Pay cash on delivery" reminder (D11 — NO commission/finance line on this
/// customer-facing surface).
///
/// Dumb widget (guardrail §1): data in via [summary], events out via
/// [onOpenChat] / [onTrack]. It NEVER touches `sl` or `context.go` — the host
/// route owns navigation. Hosts pass:
///   * chat host (JM-025): `onTrack` → `/orders/:id/tracking`, `onOpenChat` null
///     (already on chat) or a no-op/scroll.
///   * tracking host (JM-032): `onOpenChat` → `/chat/:id`, `onTrack` null
///     (already on tracking).
///   * standalone deep-link screen (JM-056 target): both wired.
/// A null callback hides the corresponding CTA so it is never a dead end.
///
/// Every interactive/asserted element carries the EXACT `Semantics(identifier:)`
/// from `63_W1_TEST_PLAN §2.11`.
///
/// ## redesign-2026-08
///
/// A re-skin onto the Jeeb kit, not a product change: same data, same block
/// order, same callbacks, same identifiers. The bespoke grey slab became the
/// neighbour's shape — one [JeebOutlinedCard.grouped] ticket (identity → tier +
/// ETA → item → price) over a [JeebInfoNote] trust line and a [JeebCtaFooter].
/// There is no render for this screen; the language is taken from 10
/// (`Review & send`), which the customer sees immediately before this one.
class OrderSummaryPinned extends StatelessWidget {
  const OrderSummaryPinned({
    super.key,
    required this.summary,
    this.onOpenChat,
    this.onTrack,
    this.dense = false,
  });

  /// The locked accepted-order snapshot to render.
  final OrderSummary summary;

  /// Tapped on `order_summary_open_chat`. Null hides the chat CTA (e.g. when the
  /// widget is already hosted inside the chat screen).
  final VoidCallback? onOpenChat;

  /// Tapped on `order_summary_track`. Null hides the track CTA (e.g. when the
  /// widget is already hosted inside the tracking screen).
  final VoidCallback? onTrack;

  /// When true, renders as a compact pinned strip (for the chat/tracking header
  /// injection) rather than the roomier standalone-screen card.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final OrderSummaryL10n l10n = OrderSummaryL10n.of(context);
    // 24px board gutter on the standalone screen; the dense injection keeps the
    // tighter 16 it has always had.
    final double gutter = dense ? Spacing.medium : Spacing.xLarge;
    final String? item = summary.itemSummary?.trim();
    final Widget? footer = ctaFooter(
      context,
      onOpenChat: onOpenChat,
      onTrack: onTrack,
      padding: EdgeInsetsDirectional.only(
        top: dense ? Spacing.small : Spacing.large,
      ),
    );

    return Semantics(
      identifier: 'order_summary_pinned',
      container: true,
      explicitChildNodes: true,
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          gutter,
          dense ? Spacing.small : _ticketTopGap,
          gutter,
          0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            JeebOutlinedCard.grouped(
              radius: _ticketRadius,
              // R12's slab stroke: board `rgba(255,255,255,.15)` snaps to the
              // §4 strong rung, not rest glass's 12%.
              borderColor: _semanticsOf(context).glassBorderStrong,
              children: <Widget>[
                _JeeberBlock(summary: summary),
                _TierEtaBlock(summary: summary),
                if (item != null && item.isNotEmpty)
                  _ItemBlock(label: l10n.itemLabel, value: item),
                _PriceBlock(
                  label: l10n.priceLabel,
                  amount: summary.price.toStringAsFixed(2),
                  currency: summary.currency,
                ),
              ],
            ),
            SizedBox(height: dense ? Spacing.small : Spacing.medium),
            // D11 trust line. R12 puts its reassurance under the docked CTA;
            // this one is tied to the price, so it stays under the ticket.
            JeebInfoNote.muted(
              identifier: 'order_summary_cash_label',
              icon: Icons.payments,
              text: l10n.cashLabel,
            ),
            // ── CTAs (each hidden when its callback is null) ────────────────
            ?footer,
          ],
        ),
      ),
    );
  }

  /// The CTA pair, the surviving one, or nothing at all. Both pills are 58 —
  /// R12's docked height — so the two variants share one baseline.
  ///
  /// ONE implementation, two placements (the R5/W1 precedent): the standalone
  /// screen docks it under the scroll area the way R12 docks `Broadcast`, and
  /// the injected/dense form keeps it inline under the ticket. `Track` is the
  /// accent pill — R12's caption calls the forward act "the lone solid-orange
  /// act", so the orange budget is spent once and `Open chat` stays glass.
  static Widget? ctaFooter(
    BuildContext context, {
    required VoidCallback? onOpenChat,
    required VoidCallback? onTrack,
    required EdgeInsetsGeometry padding,
  }) {
    if (onOpenChat == null && onTrack == null) return null;
    final OrderSummaryL10n l10n = OrderSummaryL10n.of(context);

    final Widget? chatCta = onOpenChat == null
        ? null
        : Semantics(
            identifier: 'order_summary_open_chat',
            button: true,
            child: JeebCtaButton.outline(
              label: l10n.openChat,
              height: JeebCtaButton.primaryHeightTall,
              onTap: onOpenChat,
            ),
          );
    final Widget? trackCta = onTrack == null
        ? null
        : Semantics(
            identifier: 'order_summary_track',
            button: true,
            child: JeebCtaButton.accent(
              label: l10n.track,
              height: JeebCtaButton.primaryHeightTall,
              onTap: onTrack,
            ),
          );

    if (chatCta != null && trackCta != null) {
      return JeebCtaFooter.split(
        padding: padding,
        expandLeading: true,
        leading: chatCta,
        trailing: trackCta,
      );
    }
    return JeebCtaFooter.single(
      padding: padding,
      child: (chatCta ?? trackCta)!,
    );
  }
}

/// Jeeber avatar + name (`order_summary_jeeber_name`) + rating chip (D6: only
/// when a real score exists — cold-start jeebers show the name alone).
class _JeeberBlock extends StatelessWidget {
  const _JeeberBlock({required this.summary});

  final OrderSummary summary;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(Spacing.medium),
      child: Row(
        children: <Widget>[
          // `initial` takes a full name — the kit's `initialFrom` normalises it
          // (and renders '?' rather than inventing a mark when it is empty).
          JeebAvatar.thread(
            initial: summary.jeeberName,
            imageUrl: summary.jeeberAvatarUrl,
          ),
          const SizedBox(width: Spacing.small),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Semantics(
                  identifier: 'order_summary_jeeber_name',
                  container: true,
                  child: Text(
                    summary.jeeberName,
                    style: context.jeebText.cardTitle.copyWith(
                      color: scheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (summary.hasRating) ...<Widget>[
                  const SizedBox(height: Spacing.twoXSmall),
                  // JEBV4-285: the stars + rating + review-count row is
                  // intrinsically wider than the Expanded name/rating block can
                  // be — a long review count (e.g. "(312)") pushed it past the
                  // edge and tripped a RenderFlex overflow stripe. scaleDown
                  // keeps the whole rating legible by shrinking it to the
                  // available width instead of clipping; centerStart keeps it
                  // leading-aligned in both LTR and RTL.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: OmdsStarRatingDisplay(
                      averageRating: summary.jeeberRating!,
                      totalReviews: summary.jeeberRatingCount,
                      starSize: Sizes.medium,
                      // OMDS already wraps the label in parentheses; the old
                      // '($count)' shipped a doubled "((214))".
                      reviewsLabelBuilder: (count) => '$count',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tier pill + ETA qualifier — 10's tier row (`tpl 596`: chip, then the muted
/// SLA line) carrying `order_summary_tier` and `order_summary_eta`.
///
/// A [Wrap], not a [Row], for the reason `tracking_header_overflow_test`
/// documents on the tracking surface: an unmapped tier id arrives raw off the
/// wire and Arabic ETA copy is twice as long as English, so at 200% text scale
/// the two runs cannot share a line. Wrapping stacks them instead of painting
/// an overflow stripe; the [ConstrainedBox] bounds the unbounded main-axis
/// constraints a `Wrap` hands its children so one long token ellipsises.
class _TierEtaBlock extends StatelessWidget {
  const _TierEtaBlock({required this.summary});

  final OrderSummary summary;

  @override
  Widget build(BuildContext context) {
    final OrderSummaryL10n l10n = OrderSummaryL10n.of(context);
    final String tier = summary.tier.trim();
    final int? eta = summary.etaMinutes;
    final JeebTier resolved = JeebTier.fromId(tier);
    final TextStyle mutedRun = context.jeebText.bodySmall.copyWith(
      color: _mutedInk(context),
    );
    final Widget chip;
    if (tier.isEmpty) {
      // `tierName('')` echoes the id back, so an absent tier used to render a
      // labelled BLANK — a field that reads broken rather than unknown. The
      // meta chip carries the same honest "Pending" the chat header's chip uses.
      chip = JeebTierChip.meta(label: l10n.tierPending);
    } else if (resolved == JeebTier.unknown) {
      // An unmapped slug comes straight off the wire, so its length is
      // unbounded — and the kit chip cannot ellipsise (its `Row` hands the
      // label Text unbounded constraints). Render the unknown case as a muted
      // run, the way the tracking header does, rather than an overflow stripe.
      chip = Text(
        l10n.tierName(tier),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: mutedRun,
      );
    } else {
      chip = JeebTierChip(tier: resolved, label: l10n.tierName(tier));
    }
    // ETA keeps its label in the run (the tracking header's composition) so the
    // number is never a bare, unattributed "20 min".
    final String etaText = eta == null
        ? l10n.etaPending
        : '${l10n.etaLabel}: ${l10n.etaMinutes(eta)}';

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.medium,
        Spacing.small,
        Spacing.medium,
        Spacing.small,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Wrap(
            spacing: Spacing.xSmall,
            runSpacing: Spacing.twoXSmall,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                child: Semantics(
                  identifier: 'order_summary_tier',
                  container: true,
                  child: chip,
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                child: Semantics(
                  identifier: 'order_summary_eta',
                  container: true,
                  child: Text(
                    etaText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mutedRun,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The one-line order summary (`order_summary_item`), drawn as 10 draws its
/// stops: a muted qualifier over the value.
class _ItemBlock extends StatelessWidget {
  const _ItemBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(Spacing.medium),
      child: Semantics(
        identifier: 'order_summary_item',
        container: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: context.jeebText.bodySmall.copyWith(
                color: _mutedInk(context),
              ),
            ),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              // R12 sets the value under a muted qualifier at 14/w700: `body`
              // is the nearest rung, `cardTitle` (15.5) overshoots it.
              style: context.jeebText.body.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Accepted COD price (`order_summary_price`) — the ticket's last row and the
/// only number on the screen, so it carries the `price` token.
class _PriceBlock extends StatelessWidget {
  const _PriceBlock({
    required this.label,
    required this.amount,
    required this.currency,
  });

  final String label;
  final String amount;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(Spacing.medium),
      child: Semantics(
        identifier: 'order_summary_price',
        container: true,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.jeebText.bodySmall.copyWith(
                  color: _mutedInk(context),
                ),
              ),
            ),
            const SizedBox(width: Spacing.small),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerEnd,
                // An amount never reorders in Arabic.
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    '$amount $currency',
                    // Read-only summary: the `price` ramp carries the emphasis,
                    // the ink stays `onSurface` — accent is for acts, not recaps.
                    style: context.jeebText.price.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Read defensively: a harness that themes without the extension must not crash.
JeebSemanticColors _semanticsOf(BuildContext context) =>
    Theme.of(context).extension<JeebSemanticColors>() ??
    JeebSemanticColors.midnight();

Color _mutedInk(BuildContext context) => _semanticsOf(context).mutedText;
