import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../domain/order_summary.dart';
import '../order_summary_l10n.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

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
    final l10n = OrderSummaryL10n.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final priceText = summary.price.toStringAsFixed(2);

    return Semantics(
      identifier: 'order_summary_pinned',
      container: true,
      explicitChildNodes: true,
      child: Container(
        margin: EdgeInsetsDirectional.all(dense ? Spacing.small : Spacing.medium),
        padding: const EdgeInsetsDirectional.all(Spacing.medium),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: OmdsBorderRadius.medium,
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Jeeber identity + accepted price ──────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OmdsProfileAvatar(
                  initial: _initial(summary.jeeberName),
                  profilePicUrl: summary.jeeberAvatarUrl,
                  size: Sizes.fourXLarge,
                ),
                const SizedBox(width: Spacing.small),
                Expanded(child: _JeeberBlock(summary: summary)),
                const SizedBox(width: Spacing.small),
                _PriceBlock(
                  label: l10n.priceLabel,
                  amount: priceText,
                  currency: summary.currency,
                ),
              ],
            ),
            const SizedBox(height: Spacing.small),
            // ── Facts row: ETA + tier ─────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _Fact(
                    identifier: 'order_summary_eta',
                    icon: Icons.access_time,
                    label: l10n.etaLabel,
                    value: summary.etaMinutes != null
                        ? l10n.etaMinutes(summary.etaMinutes!)
                        : l10n.etaPending,
                  ),
                ),
                const SizedBox(width: Spacing.small),
                Expanded(
                  child: _Fact(
                    identifier: 'order_summary_tier',
                    icon: Icons.bolt_outlined,
                    label: l10n.tierLabel,
                    // `tierName('')` returns '' (its `default` arm echoes the
                    // id back), so an absent tier used to render a labelled
                    // BLANK — an icon and the word "Tier" with nothing after
                    // it, which reads as a broken field rather than an unknown
                    // one. The ETA cell beside it already had this placeholder;
                    // so does the chat header's tier chip. Give the tier cell
                    // the same honest "Pending" rather than a hole.
                    value: summary.tier.trim().isEmpty
                        ? l10n.tierPending
                        : l10n.tierName(summary.tier),
                  ),
                ),
              ],
            ),
            // ── Item summary ──────────────────────────────────────────────
            if (summary.itemSummary != null) ...[
              const SizedBox(height: Spacing.small),
              _Fact(
                identifier: 'order_summary_item',
                icon: Icons.inventory_2_outlined,
                label: l10n.itemLabel,
                value: summary.itemSummary!,
              ),
            ],
            const SizedBox(height: Spacing.small),
            // ── Pay-cash-on-delivery reminder (D11) ───────────────────────
            Semantics(
              identifier: 'order_summary_cash_label',
              container: true,
              child: Row(
                children: [
                  Icon(
                    Icons.payments_outlined,
                    size: Sizes.medium,
                    color: colors.primary,
                  ),
                  const SizedBox(width: Spacing.xSmall),
                  Expanded(
                    child: Text(
                      l10n.cashLabel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── CTAs (each hidden when its callback is null) ──────────────
            if (onOpenChat != null || onTrack != null) ...[
              const SizedBox(height: Spacing.medium),
              Row(
                children: [
                  if (onOpenChat != null)
                    Expanded(
                      child: Semantics(
                        identifier: 'order_summary_open_chat',
                        button: true,
                        child: OmdsPrimaryButton(
                          text: l10n.openChat,
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
                          text: l10n.track,
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

  static String _initial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }
}

/// Jeeber name (`order_summary_jeeber_name`) + rating chip (D6: only when a
/// real score exists — cold-start jeebers show the name alone).
class _JeeberBlock extends StatelessWidget {
  const _JeeberBlock({required this.summary});

  final OrderSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          identifier: 'order_summary_jeeber_name',
          container: true,
          child: Text(
            summary.jeeberName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (summary.hasRating) ...[
          const SizedBox(height: Spacing.twoXSmall),
          // JEBV4-285: the stars + rating + review-count row is intrinsically
          // wider than the Expanded name/rating block can be once the avatar and
          // price pill claim their share of the header Row — a long review count
          // (e.g. "(312)") pushed it past the edge and tripped a RenderFlex
          // overflow stripe. scaleDown keeps the whole rating legible by shrinking
          // it to the available width instead of clipping; centerStart keeps it
          // leading-aligned in both LTR and RTL.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: OmdsStarRatingDisplay(
              averageRating: summary.jeeberRating!,
              totalReviews: summary.jeeberRatingCount,
              starSize: Sizes.medium,
              reviewsLabelBuilder: (count) => '($count)',
            ),
          ),
        ],
      ],
    );
  }
}

/// Accepted COD price (`order_summary_price`) pill.
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      identifier: 'order_summary_price',
      container: true,
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.small,
          vertical: Spacing.xSmall,
        ),
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: OmdsBorderRadius.small,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onPrimaryContainer.withValues(
                  alpha: UIConstants.opacityHigh,
                ),
              ),
            ),
            Text(
              '$amount $currency',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A labelled fact chip (icon + label + value) used for ETA / tier / item. The
/// [identifier] is applied to the value-bearing container so Maestro can assert
/// the field is present regardless of its visible (localized) copy.
class _Fact extends StatelessWidget {
  const _Fact({
    required this.identifier,
    required this.icon,
    required this.label,
    required this.value,
  });

  final String identifier;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      identifier: identifier,
      container: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: Sizes.medium, color: colors.onSurfaceVariant),
          const SizedBox(width: Spacing.xSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: colors.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
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
// Render tests: test/previews/order_summary/order_summary_pinned_preview_test.dart
// ===========================================================================
//
// [OrderSummaryPinned] is a dumb, pure-props widget (guardrail §1): everything
// it paints comes from the one [OrderSummary] value object it is handed, and it
// never touches `sl` or `context.go`. So these previews need no cubit, no
// repository and no DI graph — they are network-free by construction, not just
// by the guard in [jeebPreviewHost]. `jeeberAvatarUrl` is left null throughout
// so the canvas never reaches for a CDN either; the initials avatar is what a
// real accepted order shows most of the time anyway.
//
// The fixture values are lifted from the widget's own suites rather than
// invented — `test/features/order_summary/order_summary_pinned_test.dart`
// (Kamal Hajj · 9.00 USD · express · 20 min · "Groceries from Spinneys" ·
// 4.9 from 312) and `test/features/order_summary/tier_wire_key_test.dart` (the
// blank-tier payload). Those suites assert Semantics ids and callback wiring,
// which is the half of the contract a machine can check. These previews are the
// other half: whether the strip is still READABLE once the same data is drawn
// in Arabic, in the dark theme, and at the 200% text ceiling.
//
// One state per way this widget has actually been seen to go wrong, plus the
// two host wirings (chat injection vs. standalone deep link) that decide which
// CTAs exist.

/// Phone width, and tall enough for the roomy (non-dense) card with an item
/// line and CTAs. Measured at 314 dp on a 390 dp canvas at 1x, in both locales.
const Size _orderSummaryPinnedCardBox = Size(390, 336);

/// The dense chat/tracking injection: one CTA, no item line — 266 dp at 1x.
///
/// Note how little `dense` actually buys. It swaps `Spacing.medium` for
/// `Spacing.small` on the OUTER margin only, so 48 of the 48 dp saved here come
/// from the two dropped rows, not from the flag.
const Size _orderSummaryPinnedDenseBox = Size(390, 288);

/// The box for the two `matrix: true` states, sized to the TALLEST of their
/// three cells rather than the first one.
///
/// The EN-200% cell measures 526 dp against 314 dp for the same card at 1x. A
/// box cut to the 1x rendering would report the other two cells as overflowing
/// the CANVAS, which says nothing at all about the widget — so this is 560.
const Size _orderSummaryPinnedMatrixBox = Size(390, 560);

/// An accepted-order snapshot with every field overridable.
///
/// Each state passes its own [deliveryId] so no two fixtures are
/// Equatable-equal; nothing on screen reads it. Each also carries a distinct
/// [itemSummary], so the render test can pin a string only ONE state produces —
/// a suite where every state shares its copy passes even when two previews are
/// wired to the same fixture.
OrderSummary _orderSummaryPinnedSummary({
  required String deliveryId,
  String jeeberName = 'Kamal Hajj',
  double price = 9.0,
  String currency = 'USD',
  String tier = 'express',
  double? rating = 4.9,
  int? ratingCount = 312,
  int? etaMinutes = 20,
  String? itemSummary = 'Groceries from Spinneys',
}) =>
    OrderSummary(
      deliveryId: deliveryId,
      requestId: 'req-client-001-accepted',
      conversationId: 'conv-journey-accepted',
      price: price,
      currency: currency,
      jeeberName: jeeberName,
      tier: tier,
      jeeberRating: rating,
      jeeberRatingCount: ratingCount,
      etaMinutes: etaMinutes,
      itemSummary: itemSummary,
    );

/// Mounts the widget the way a host route does: data in, callbacks out.
///
/// A null callback is not a disabled button — it removes the CTA entirely, so
/// [chat] / [track] are what decide the shape of the bottom row.
Widget _orderSummaryPinnedHosted(
  OrderSummary summary, {
  bool chat = true,
  bool track = true,
  bool dense = false,
}) =>
    OrderSummaryPinned(
      summary: summary,
      onOpenChat: chat ? () {} : null,
      onTrack: track ? () {} : null,
      dense: dense,
    );

/// The standalone deep-link rendering (JM-056) — the ONLY host that mounts both
/// CTAs, and therefore the only one where the button row has to share a line.
///
/// This is the state to read for the D11/D71 contract: the locked COD price the
/// customer hands over in cash, the jeeber, ETA, tier, item, and "Pay cash on
/// delivery". What must NOT appear is any commission or finance figure — this
/// surface is customer-facing.
///
/// The matrix is on, and the 200% cell is the reason. Read it first: on a 390 dp
/// phone this ORDINARY card — "Kamal Hajj", `9.00 USD` — overflows its top row
/// by 29 px at the 200% ceiling, and starts overflowing at a text scale of
/// about 1.8. The `_PriceBlock` beside the name is a rigid `Row` child with no
/// width ceiling and no `maxLines`, so it takes its full intrinsic width, the
/// `Expanded` name/rating block beside it is starved toward zero, and the row
/// runs off the trailing edge. The sibling rendering of this same JM-031
/// contract — `OrderSummaryPinnedHeader` in `live_tracking` — already fixed
/// exactly this by making its price `Flexible` with `maxLines: 1`; this one did
/// not. The CTA row below it is fine at 200%: both buttons are `Expanded`, so
/// "Open chat"/"Track order" (longer in Arabic: "فتح المحادثة"/"تتبّع الطلب")
/// stay inside their halves.
@JeebPreview(
  group: 'order_summary',
  name: 'Deep link · both CTAs',
  size: _orderSummaryPinnedMatrixBox,
  matrix: true,
)
Widget orderSummaryPinnedDeepLink() => _orderSummaryPinnedHosted(
      _orderSummaryPinnedSummary(deliveryId: 'del-31-deeplink'),
    );

/// The chat-host injection (JM-025): `dense: true`, chat CTA suppressed because
/// the customer is already on that screen, and a cold-start jeeber.
///
/// Two hide-branches fire at once here, and both are deliberate rather than
/// broken-looking:
///   * D6 — no score yet means NO rating chip, not an empty five-star row. The
///     name has to carry the block on its own without the column collapsing.
///   * A null `itemSummary` drops the item fact entirely, so the facts row is
///     the last thing above the cash reminder.
///
/// It is also the control for the overflow described on the deep-link state: at
/// 200% this card overflows its top row by the SAME 29 px with the rating chip
/// gone entirely, which is how you know the rating is not what is pushing the
/// row out — the price pill is.
@JeebPreview(
  group: 'order_summary',
  name: 'Chat host · dense, no rating',
  size: _orderSummaryPinnedDenseBox,
)
Widget orderSummaryPinnedChatHostDense() => _orderSummaryPinnedHosted(
      _orderSummaryPinnedSummary(
        deliveryId: 'del-31-chat',
        jeeberName: 'Yasmine Haddad',
        rating: null,
        ratingCount: 0,
        itemSummary: null,
      ),
      chat: false,
    );

/// The tier-wire regression (`tier_wire_key_test.dart`), made visible.
///
/// The gateway serialises `tierId`, never `tier`, on `GET /v1/deliveries/{id}`
/// and `GET /v1/requests/{id}`, so for a long time this cell received `''` —
/// and `tierName('')` echoes its argument back, which rendered an icon, the
/// word "Tier", and then NOTHING. A labelled hole reads as a broken app; the
/// fix was to show the same honest "Pending" the ETA cell beside it already
/// had. If this preview ever shows a bare "Tier" again, that fix is gone.
///
/// It is also the longest-lived state on the tracking surface: between accept
/// and the first GPS fix the customer sees "ETA pending" — 11 characters in
/// English and 25 in Arabic ("الوقت المقدّر قيد التحديد") — inside a cell that
/// is exactly half the card wide.
@JeebPreview(
  group: 'order_summary',
  name: 'ETA + tier pending',
  size: _orderSummaryPinnedCardBox,
)
Widget orderSummaryPinnedPendingFields() => _orderSummaryPinnedHosted(
      _orderSummaryPinnedSummary(
        deliveryId: 'del-31-pending',
        tier: '',
        etaMinutes: null,
        itemSummary: 'Medicine from Mazen Pharmacy',
      ),
      chat: false,
    );

/// The header row's ceiling, and where the price-pill problem stops being an
/// accessibility edge case and becomes the DEFAULT rendering for a whole market.
///
/// A six- or seven-digit lira amount is ordinary in SYP, not adversarial. With
/// `1234567.89 SYP` in the pill this card overflows its top row from a text
/// scale of about **1.1** — one notch above the system default, not the 200%
/// ceiling — and by 222 px at 200%. Swap the price back to `9.00 USD` and the
/// identical row with the identical long name is clean until 1.8, so the name
/// is not the cause: it is `Expanded` with `maxLines: 1` and ellipsises as
/// designed. The price pill has no such ceiling.
///
/// The long name and the "(312)" review count are still here because they are
/// the JEBV4-285 guard: the stars + score + count row is intrinsically wider
/// than the `Expanded` block it sits in, and the `FittedBox(scaleDown)` in
/// [_JeeberBlock] is what stopped it painting its own overflow stripe. Read
/// this state for whether the rating is still LEGIBLE once shrunk — `scaleDown`
/// buys "no overflow" by spending type size.
///
/// The matrix is on because the three cells fail differently: Arabic mirrors
/// the row so the pill moves to the leading edge, and 200% is where the 222 px
/// is. Note also that the amount renders as a bare `1234567.89` in BOTH locales
/// — no thousands separator, no Arabic-Indic digits, ISO code rather than a
/// symbol.
@JeebPreview(
  group: 'order_summary',
  name: 'Long name + huge price',
  size: _orderSummaryPinnedMatrixBox,
  matrix: true,
)
Widget orderSummaryPinnedLongNameHugePrice() => _orderSummaryPinnedHosted(
      _orderSummaryPinnedSummary(
        deliveryId: 'del-31-price',
        jeeberName: 'Abdulrahman Al-Muhandis Al-Trabulsi',
        price: 1234567.89,
        currency: 'SYP',
        itemSummary: 'Two crates of bottled water',
      ),
    );

/// Bidi: an Arabic item summary rendered inside an English UI.
///
/// `itemSummary` is the only free text on this card — the one place the UI
/// locale and the content direction can legitimately disagree, because
/// customers type their request in Arabic and then read it back in whichever
/// locale the app happens to be in. It goes through a bare `Text`, so the
/// paragraph takes the AMBIENT direction rather than the string's own
/// first-strong character (UAX#9). Read this state's English rendering beside
/// the Arabic one the render test pumps: if the trailing punctuation of an
/// Arabic line lands on the wrong side, this is where it shows.
@JeebPreview(
  group: 'order_summary',
  name: 'Arabic item in EN UI',
  size: _orderSummaryPinnedCardBox,
)
Widget orderSummaryPinnedArabicItem() => _orderSummaryPinnedHosted(
      _orderSummaryPinnedSummary(
        deliveryId: 'del-31-bidi',
        itemSummary: '٢ كيلو تفاح من سبينيس',
      ),
      chat: false,
    );
