import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_tier_chip.dart';
import '../../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../mixed_direction/presentation/mixed_direction_text.dart';
import '../../domain/delivery_tracking_info.dart';
import '../live_tracking_l10n.dart';

/// JM-032 AC1 (with JM-031, CTO-D3): the pinned order-summary header injected at
/// the TOP of the tracking screen. Carries the signature id
/// `order_summary_pinned` plus the accepted-order fields the JM-031 contract
/// names (price/jeeber/ETA/tier + "Pay cash on delivery", D11/D71).
///
/// redesign-2026-08 (§C task 3): the grey slab is gone. This IS the screen's
/// top bar now — a [JeebTopBar] whose leading circle owns `tracking_back`, whose
/// title is the item summary and whose subtitle is the meta line that carries
/// the five pinned display leaves. The chat CTA moved from a full-width outlined
/// button to the bar's Ø40 trailing circle; its identifier is unchanged, so
/// `tracking_open_chat_requestid_test.dart` (which taps by identifier) is
/// untouched.
///
/// On the tracking surface the summary is sourced from the same delivery row the
/// `LiveTrackingCubit` already polls (`GET /v1/delivery/:id`) — no second fetch
/// and no cross-feature DI coupling. JM-031 owns the standalone pinned WIDGET
/// (chat + deep-link route); this header is its tracking-surface rendering and
/// uses the identical ids so the customer sees one consistent summary.
///
/// CUSTOMER-FACING: NO commission/finance line is ever shown here (D11).
class OrderSummaryPinnedHeader extends StatelessWidget {
  const OrderSummaryPinnedHeader({
    super.key,
    required this.info,
    this.onOpenChat,
    this.onTrack,
  });

  final DeliveryTrackingInfo info;

  /// `order_summary_open_chat` → order-chat (JM-025). Hidden when null.
  final VoidCallback? onOpenChat;

  /// `order_summary_track` → order-tracking (JM-032). On the tracking screen
  /// itself this is the current surface, so it is omitted (null) to avoid a
  /// self-navigating CTA; it exists for parity with the JM-031 chat rendering.
  ///
  /// The redesigned bar has exactly ONE trailing circle, so a non-null value
  /// here is still deliberately not drawn — `order_summary_track` stays absent
  /// on this surface, as it always has been.
  final VoidCallback? onTrack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final trackingL10n = LiveTrackingL10n.of(context);
    final chat = onOpenChat;

    return Semantics(
      identifier: 'order_summary_pinned',
      container: true,
      explicitChildNodes: true,
      child: JeebTopBar.back(
        identifier: 'tracking_back',
        // The repo precedent for an in-body back button on a deep-link-rootable
        // route (settings, client offers, wallet, jeeber pending offers):
        // `maybePop` alone no-ops on a stack root and leaves a dead circle, and
        // `'/'` is exactly `AppRouter.backFallbacks['live-tracking']`.
        onLeadingPressed: () =>
            context.canPop() ? context.pop() : context.go('/'),
        titleScale: JeebTopBarTitleScale.compact,
        title: info.itemSummary ?? l10n.trackingTitle,
        subtitleSlot: _MetaLine(info: info),
        trailing: chat == null
            ? null
            : JeebTopBarAction(
                icon: Icons.chat_bubble,
                onPressed: chat,
                identifier: 'order_summary_open_chat',
                semanticLabel: trackingL10n.summaryOpenChat,
              ),
      ),
    );
  }
}

/// Formats the accepted price for display. Shared by the header meta line and
/// [TrackingCourierCard] so the two money runs cannot drift apart.
///
/// Deliberately NOT a currency-symbol mapper: the gateway sends an ISO code and
/// inventing `$`/`£` client-side would be a second source of truth.
String formatTrackingPrice(double price, String? currency) {
  final amount = price.toStringAsFixed(2);
  return currency == null ? amount : '$amount $currency';
}

/// The meta line under the bar title — the board's `⚡ Flash · $8 cash`
/// (`12-live-tracking.html` tpl 724), extended with the two runs D-12-1/D-12-2
/// keep alive (jeeber name + ETA) because `tracking_header_overflow_test.dart`
/// pins their identifiers.
///
/// ## Why this is a [Wrap] and not a [Row]
///
/// It used to be a `Row` holding two bare `Text` children with no `Expanded`,
/// no `Flexible`, no `maxLines` and no `overflow`. A `Row` lays non-flex
/// children out with `maxWidth: infinity`, so each `Text` claimed its full
/// unwrapped intrinsic width and `RenderFlex` painted the overflow stripe: on a
/// Samsung A33 (411.4 dp wide, less the gutters = 379.4 dp of content) the strip
/// reported **RIGHT OVERFLOWED BY 75 PIXELS**. There was no shrink capacity
/// anywhere in the row, so any excess was a hard overflow rather than a wrap or
/// a truncation.
///
/// Three things stack to produce that excess, and all three are ordinary:
///   * text scaling — the app clamps at 2.0 and the a11y AC requires 200%
///     without overflow, which doubles every run while the box does not;
///   * Arabic — `summaryEtaPending` is 11 characters in English and 25 in
///     Arabic ("الوقت المقدّر قيد التحديد"), so RTL is materially worse;
///   * an unmapped tier id — `LiveTrackingL10n.tierName` echoes the raw id back
///     for anything outside its five known slugs, and since #208 that id comes
///     straight off the wire, so it can be arbitrarily long.
///
/// A `Wrap` cannot overflow horizontally: when the runs no longer fit side by
/// side they stack onto another line, which keeps them readable at 200% instead
/// of truncating them. The [ConstrainedBox] is what handles the third case —
/// `Wrap` hands its children unbounded main-axis constraints, so a single token
/// longer than the line would still overflow without an explicit ceiling;
/// bounded to the strip's own width it ellipsises instead.
///
/// The board draws `·` separators between the runs. They are deliberately NOT
/// rendered: a literal middot between wrapped runs strands itself at the end of
/// a line under RTL, and each run is its own semantics leaf. Wrap `spacing` is
/// the separator instead — a noted, minor divergence from the board.
class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.info});

  final DeliveryTrackingInfo info;

  @override
  Widget build(BuildContext context) {
    final l10n = LiveTrackingL10n.of(context);
    final theme = Theme.of(context);
    // Qualifier ink — the board draws this whole line periwinkle (tpl 724).
    final style = context.jeebText.bodySmall.copyWith(
      color: _mutedInk(theme),
    );
    final price = info.price;
    final tier = info.tier;
    final eta = info.etaMinutes;
    final hasTier = tier != null && tier.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        Widget run(String identifier, Widget child) => ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: Semantics(identifier: identifier, child: child),
            );

        Widget line(String text) => Text(
              text,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );

        return Wrap(
          spacing: Spacing.xSmall,
          runSpacing: Spacing.twoXSmall,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            // 1 — tier. Emoji + localized name, plain text, no "Tier:" prefix
            // and NOT a pill (tpl 724). Absent entirely when the row carries no
            // tier (pinned by tracking_header_overflow_test).
            if (hasTier)
              run(
                'order_summary_tier',
                line('${JeebTierChip.emojiFor(tier)} ${l10n.tierName(tier)}'),
              ),
            // 2 — price. Latin digits beside Arabic copy: isolate the run so
            // the amount cannot be reordered by the surrounding bidi context.
            if (price != null)
              run(
                'order_summary_price',
                MixedDirectionText(
                  formatTrackingPrice(price, info.currency),
                  style: style,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            // 3 — the D11 cash reminder. The board draws one short word; screen
            // readers get the full sentence instead of a bare "cash".
            Semantics(
              identifier: 'order_summary_cash_label',
              label: l10n.summaryCashLabel,
              excludeSemantics: true,
              child: line(l10n.cashShort),
            ),
            // 4 — D-12-1: the jeeber name run the board does not draw but C1
            // pins. Kept here rather than deleted at the cost of one test edit.
            run('order_summary_jeeber_name', line(info.jeeberName ?? '')),
            // 5 — D-12-2: ETA, unchanged composition (it also appears on the
            // map pill, exactly as it already did today).
            run(
              'order_summary_eta',
              line(
                eta == null
                    ? l10n.summaryEtaPending
                    : '${l10n.summaryEtaLabel}: ${l10n.summaryEtaMinutes(eta)}',
              ),
            ),
          ],
        );
      },
    );
  }

  /// Read defensively: `ThemeData.light()` harnesses (every `wrapForTest`
  /// widget test) carry no `JeebSemanticColors` extension.
  Color _mutedInk(ThemeData theme) =>
      (theme.extension<JeebSemanticColors>() ?? JeebSemanticColors.light())
          .mutedText;
}
