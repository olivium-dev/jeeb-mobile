import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../domain/delivery_tracking_info.dart';
import '../live_tracking_l10n.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

/// JM-032 AC1 (with JM-031, CTO-D3): the pinned order-summary header injected at
/// the TOP of the tracking screen. Carries the signature id
/// `order_summary_pinned` plus the accepted-order fields the JM-031 contract
/// names (price/jeeber/ETA/tier + "Pay cash on delivery", D11/D71).
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
  final VoidCallback? onTrack;

  @override
  Widget build(BuildContext context) {
    final l10n = LiveTrackingL10n.of(context);
    final theme = Theme.of(context);
    final price = info.price;
    final tier = info.tier;
    final eta = info.etaMinutes;

    return Semantics(
      identifier: 'order_summary_pinned',
      container: true,
      explicitChildNodes: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsetsDirectional.all(Spacing.medium),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(OMDSBorderRadius.lg),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Jeeber name + price row.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Semantics(
                    identifier: 'order_summary_jeeber_name',
                    child: Text(
                      info.jeeberName ?? '',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                if (price != null)
                  // Flexible, not rigid: the name beside it is Expanded, so a
                  // long price would otherwise starve the name to zero width
                  // and then overflow the row itself.
                  Flexible(
                    child: Semantics(
                      identifier: 'order_summary_price',
                      child: Text(
                        _formatPrice(price, info.currency),
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Spacing.xSmall),
            // Tier + ETA facts. See [_HeaderFactStrip] for why this is not a Row.
            _HeaderFactStrip(
              tier: tier == null || tier.isEmpty
                  ? null
                  : '${l10n.summaryTierLabel}: ${l10n.tierName(tier)}',
              eta: eta == null
                  ? l10n.summaryEtaPending
                  : '${l10n.summaryEtaLabel}: ${l10n.summaryEtaMinutes(eta)}',
            ),
            if (info.itemSummary != null) ...[
              const SizedBox(height: Spacing.xSmall),
              Text(
                info.itemSummary!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: Spacing.xSmall),
            // "Pay cash on delivery" reminder (D11) — NO commission line.
            Semantics(
              identifier: 'order_summary_cash_label',
              child: Text(
                l10n.summaryCashLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onOpenChat != null || onTrack != null) ...[
              const SizedBox(height: Spacing.small),
              Row(
                children: [
                  if (onOpenChat != null)
                    Expanded(
                      child: Semantics(
                        identifier: 'order_summary_open_chat',
                        button: true,
                        child: OmdsPrimaryButton(
                          text: l10n.summaryOpenChat,
                          variant: OmdsButtonVariant.outlined,
                          onTap: onOpenChat!,
                        ),
                      ),
                    ),
                  if (onOpenChat != null && onTrack != null)
                    const SizedBox(width: Spacing.small),
                  if (onTrack != null)
                    Expanded(
                      child: Semantics(
                        identifier: 'order_summary_track',
                        button: true,
                        child: OmdsPrimaryButton(
                          text: l10n.summaryTrack,
                          onTap: onTrack!,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatPrice(double price, String? currency) {
    final amount = price.toStringAsFixed(2);
    return currency == null ? amount : '$amount $currency';
  }
}

/// The tier + ETA line of the pinned header.
///
/// ## Why this is a [Wrap] and not a [Row]
///
/// It used to be a `Row` holding two bare `Text` children with no `Expanded`,
/// no `Flexible`, no `maxLines` and no `overflow`. A `Row` lays non-flex
/// children out with `maxWidth: infinity`, so each `Text` claimed its full
/// unwrapped intrinsic width and `RenderFlex` painted the overflow stripe: on a
/// Samsung A33 (411.4 dp wide, less `Spacing.medium` padding either side =
/// 379.4 dp of content) the strip reported **RIGHT OVERFLOWED BY 75 PIXELS**.
/// There was no shrink capacity anywhere in the row, so any excess was a hard
/// overflow rather than a wrap or a truncation.
///
/// Three things stack to produce that excess, and all three are ordinary:
///   * text scaling — the app clamps at 2.0 and the a11y AC requires 200%
///     without overflow, which doubles both labels while the box does not;
///   * Arabic — `summaryEtaPending` is 11 characters in English and 25 in
///     Arabic ("الوقت المقدّر قيد التحديد"), so RTL is materially worse;
///   * an unmapped tier id — `LiveTrackingL10n.tierName` echoes the raw id back
///     for anything outside its five known slugs, and since #208 that id comes
///     straight off the wire, so it can be arbitrarily long.
///
/// A `Wrap` cannot overflow horizontally: when the two facts no longer fit side
/// by side they stack onto a second run, which keeps both readable at 200%
/// instead of truncating them. The [ConstrainedBox] is what handles the third
/// case — `Wrap` hands its children unbounded main-axis constraints, so a
/// single token longer than the line would still overflow without an explicit
/// ceiling; bounded to the strip's own width it ellipsises instead.
///
/// The durable fix belongs one level down, in `omds-flutter`: `OmdsChip`
/// centres its capsule with a `Center` (expanding to its constraints) and
/// renders an un-ellipsisable label, which is why it could not simply be
/// dropped in here — the same substitution was tried and reverted on the chat
/// header (`order_chat_pinned_summary.dart`). Until `OmdsChip` shrink-wraps and
/// ellipsises, this local strip is the fix.
class _HeaderFactStrip extends StatelessWidget {
  const _HeaderFactStrip({required this.tier, required this.eta});

  /// Pre-composed tier label, or null when the delivery carries no tier.
  final String? tier;

  /// Pre-composed ETA label. Always rendered — it has a "pending" form.
  final String eta;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return LayoutBuilder(
      builder: (context, constraints) {
        Widget fact(String identifier, String text) => ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: Semantics(
                identifier: identifier,
                child: Text(
                  text,
                  style: style,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
        return Wrap(
          spacing: Spacing.medium,
          runSpacing: Spacing.xSmall,
          children: [
            if (tier != null) fact('order_summary_tier', tier!),
            fact('order_summary_eta', eta),
          ],
        );
      },
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
// Render tests: test/previews/live_tracking/order_summary_pinned_header_preview_test.dart
// ===========================================================================
// Widget previews for [OrderSummaryPinnedHeader] — run with
// `flutter widget-preview start`.
//
// The header is a pure-props widget: everything it paints comes from the one
// [DeliveryTrackingInfo] it is handed, so no cubit, no repository and no DI
// graph is involved. These previews are network-free by construction, not just
// by the guard in [jeebPreviewHost].
//
// The fixtures deliberately reuse the values from
// `test/features/live_tracking/tracking_header_overflow_test.dart` — the
// "RIGHT OVERFLOWED BY 75 PIXELS" gate — right down to the unmapped
// `premium-white-glove-…` tier slug and the six-digit SYP price. That suite can
// only assert `takeException() == null`, which answers "did it overflow?" and
// nothing else. These previews are the half of the contract it cannot reach:
// at 200% text and in Arabic, *not overflowing* and *still being readable* stop
// being the same question, and the `Wrap` + `ConstrainedBox` fix buys the first
// by spending the second.
//
// Every state passes `onOpenChat`, because that is how the production tracking
// surface mounts the header (`live_tracking_screen.dart`); `onTrack` is null
// there to avoid a self-navigating CTA, so only the JM-031 chat-parity state
// below supplies it.

/// Phone width, and tall enough for the 200%-text rendering — the tallest of
/// the three matrix cells by a wide margin, and the one that matters here.
///
/// Measured on a 390 dp canvas: the states below need 188–228 dp at 1x and
/// 404–444 dp at 2x. A box cut to the 1x rendering would report the other two as
/// overflowing the CANVAS, which says nothing at all about the widget.
const Size _orderSummaryPinnedHeaderBox = Size(390, 448);

/// The long-name state needs its own box, and the reason IS the finding.
///
/// `order_summary_jeeber_name` is the one `Text` in this header with no
/// `maxLines` and no `overflow` — the price beside it is clamped to one line,
/// and both facts in `_HeaderFactStrip` are too. So at the 200% ceiling a
/// three-part name wraps unbounded and the header grows to **732 dp**, against
/// 444 dp for the identical row with "Kamal Hajj" in it. The huge price
/// contributes nothing to that: swapping it back to `12.50 USD` still measures
/// 732 dp.
///
/// Nothing catches this today. `tracking_header_overflow_test.dart` pumps a
/// 914 dp-tall surface, so 732 dp fits and `takeException()` stays null; on a
/// real phone the header simply eats the viewport and pushes the stepper and
/// the map off screen instead of reporting anything.
const Size _orderSummaryPinnedHeaderLongNameBox = Size(390, 736);

/// Builds the header exactly as a surface mounts it.
Widget _orderSummaryPinnedHeaderHosted(
  DeliveryTrackingInfo info, {
  bool trackCta = false,
}) =>
    OrderSummaryPinnedHeader(
      info: info,
      // The tracking screen always wires this one (JM-025).
      onOpenChat: () {},
      onTrack: trackCta ? () {} : null,
    );

/// An accepted-order row, with every summary field overridable.
///
/// Defaults are the happy path from the overflow suite's own `_orderSummaryPinnedHeaderInfo`. Each
/// state passes its own [deliveryId] so no two fixtures are Equatable-equal;
/// nothing on screen reads it.
DeliveryTrackingInfo _orderSummaryPinnedHeaderInfo({
  required String deliveryId,
  String? jeeberName = 'Kamal Hajj',
  double? price = 12.5,
  String? currency = 'USD',
  String? tier = 'express',
  int? etaMinutes = 8,
  String? itemSummary = 'painkillers from the pharmacy',
}) =>
    DeliveryTrackingInfo(
      deliveryId: deliveryId,
      currentStage: TrackingStage.inTransit,
      stageTimestamps: const <TrackingStage, DateTime>{},
      price: price,
      currency: currency,
      jeeberName: jeeberName,
      tier: tier,
      etaMinutes: etaMinutes,
      itemSummary: itemSummary,
    );

/// The production tracking-surface rendering: every field resolved, chat CTA
/// only.
///
/// This is the state to read for the D11/D71 contract — price, jeeber, tier,
/// ETA, item, and "Pay cash on delivery". What must NOT be here is any
/// commission or finance line: the header is customer-facing, and a fee figure
/// appearing on it is the D11 violation.
@JeebPreview(group: 'live_tracking', name: 'Tracking surface', size: _orderSummaryPinnedHeaderBox)
Widget orderSummaryPinnedHeaderTracking() =>
    _orderSummaryPinnedHeaderHosted(_orderSummaryPinnedHeaderInfo(deliveryId: 'd-32-tracking'));

/// The JM-031 chat/deep-link rendering, which is the ONLY one with two CTAs.
///
/// Both buttons are `Expanded` in a single `Row`, so this is where the button
/// labels get half the width they have anywhere else — "Track order" and "Open
/// chat" are short in English and longer in Arabic, and the 200%-text rendering
/// halves the room again. If either label truncates or the row overflows, it
/// shows up here and nowhere else.
@JeebPreview(group: 'live_tracking', name: 'Chat parity (both CTAs)', size: _orderSummaryPinnedHeaderBox)
Widget orderSummaryPinnedHeaderBothCtas() =>
    _orderSummaryPinnedHeaderHosted(_orderSummaryPinnedHeaderInfo(deliveryId: 'd-32-chat'), trackCta: true);

/// The reported overflow, made visible: no ETA yet and no tier.
///
/// `summaryEtaPending` is 11 characters in English and 25 in Arabic ("الوقت
/// المقدّر قيد التحديد"), and this is the state a customer sees for the whole
/// window between accept and the first GPS fix — i.e. the longest string in the
/// strip is also the one shown the most. It doubles as the negative control for
/// the tier row: `order_summary_tier` must be absent, not blank.
@JeebPreview(group: 'live_tracking', name: 'ETA pending, no tier', size: _orderSummaryPinnedHeaderBox)
Widget orderSummaryPinnedHeaderEtaPending() => _orderSummaryPinnedHeaderHosted(
      _orderSummaryPinnedHeaderInfo(deliveryId: 'd-32-pending', tier: null, etaMinutes: null),
    );

/// An unmapped tier id, echoed raw — the #208 regression class.
///
/// `LiveTrackingL10n.tierName` returns its argument verbatim for anything
/// outside its five known slugs, and since #208 that id comes straight off the
/// wire (`tierId`), so its length is not bounded by anything the app controls.
/// A single token longer than the line is what the `ConstrainedBox` inside
/// `_HeaderFactStrip` exists for: `Wrap` hands its children unbounded main-axis
/// constraints, so without that ceiling this state paints the overflow stripe
/// again. It should ellipsize.
@JeebPreview(group: 'live_tracking', name: 'Unmapped tier id', size: _orderSummaryPinnedHeaderBox)
Widget orderSummaryPinnedHeaderUnmappedTier() => _orderSummaryPinnedHeaderHosted(
      _orderSummaryPinnedHeaderInfo(
        deliveryId: 'd-32-tier',
        tier: 'premium-white-glove-same-day-metropolitan',
      ),
    );

/// A high-magnitude price beside a long name — the top row's own ceiling, and
/// the state where the two halves of that row behave differently.
///
/// HORIZONTALLY the row is safe, and deliberately so: the name is `Expanded`
/// and the price only `Flexible`, so the name collapses first and the price
/// ellipsises instead of the row overflowing. A Lebanese- or Syrian-lira amount
/// is six or seven digits before the decimal point, which is ordinary rather
/// than adversarial — this is the everyday case in a SYP market.
///
/// VERTICALLY it is not. See [_orderSummaryPinnedHeaderLongNameBox]: the name is the only unclamped
/// `Text` here, so at 200% it wraps to whatever height it likes and takes the
/// pinned header with it. Read this preview's 200% rendering beside the
/// 'Tracking surface' one — same widget, same box width, 288 dp of difference.
///
/// The price also renders as a bare `1234567.89` in both locales: no thousands
/// separator, no Arabic-Indic digits, and the ISO code rather than a symbol.
@JeebPreview(group: 'live_tracking', name: 'Long name + huge price', size: _orderSummaryPinnedHeaderLongNameBox)
Widget orderSummaryPinnedHeaderHugePrice() => _orderSummaryPinnedHeaderHosted(
      _orderSummaryPinnedHeaderInfo(
        deliveryId: 'd-32-price',
        jeeberName: 'Abdulrahman Al-Muhandis Al-Trabulsi',
        price: 1234567.89,
        currency: 'SYP',
      ),
    );

/// Bidi: an Arabic item summary inside an English UI.
///
/// The item summary is the only free text on this header — the one place the UI
/// locale and the content direction can disagree, because customers type their
/// request in Arabic and then read it back inside whichever locale the app is
/// in. The sibling strip on the chat surface renders the same field through
/// `AutoDirectionText` (UAX#9 first-strong, per string); this header uses a bare
/// `Text`, so compare the two renderings of this preview before assuming they
/// agree.
@JeebPreview(group: 'live_tracking', name: 'Arabic item in EN UI', size: _orderSummaryPinnedHeaderBox)
Widget orderSummaryPinnedHeaderArabicItem() => _orderSummaryPinnedHeaderHosted(
      _orderSummaryPinnedHeaderInfo(
        deliveryId: 'd-32-bidi',
        itemSummary: '٢ كيلو تفاح من سبينيس',
      ),
    );
