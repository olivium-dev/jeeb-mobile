/// Widget previews for [OrderSummaryPinnedHeader] — run with
/// `flutter widget-preview start`.
///
/// The header is a pure-props widget: everything it paints comes from the one
/// [DeliveryTrackingInfo] it is handed, so no cubit, no repository and no DI
/// graph is involved. These previews are network-free by construction, not just
/// by the guard in [jeebPreviewHost].
///
/// The fixtures deliberately reuse the values from
/// `test/features/live_tracking/tracking_header_overflow_test.dart` — the
/// "RIGHT OVERFLOWED BY 75 PIXELS" gate — right down to the unmapped
/// `premium-white-glove-…` tier slug and the six-digit SYP price. That suite can
/// only assert `takeException() == null`, which answers "did it overflow?" and
/// nothing else. These previews are the half of the contract it cannot reach:
/// at 200% text and in Arabic, *not overflowing* and *still being readable* stop
/// being the same question, and the `Wrap` + `ConstrainedBox` fix buys the first
/// by spending the second.
///
/// Every state passes `onOpenChat`, because that is how the production tracking
/// surface mounts the header (`live_tracking_screen.dart`); `onTrack` is null
/// there to avoid a self-navigating CTA, so only the JM-031 chat-parity state
/// below supplies it.
library;

import 'package:flutter/material.dart';

import '../../features/live_tracking/domain/delivery_tracking_info.dart';
import '../../features/live_tracking/presentation/widgets/order_summary_pinned_header.dart';
import '../harness/jeeb_preview.dart';

/// Phone width, and tall enough for the 200%-text rendering — the tallest of
/// the three matrix cells by a wide margin, and the one that matters here.
///
/// Measured on a 390 dp canvas: the states below need 188–228 dp at 1x and
/// 404–444 dp at 2x. A box cut to the 1x rendering would report the other two as
/// overflowing the CANVAS, which says nothing at all about the widget.
const Size _headerBox = Size(390, 448);

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
const Size _longNameBox = Size(390, 736);

/// Builds the header exactly as a surface mounts it.
Widget _hosted(
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
/// Defaults are the happy path from the overflow suite's own `_info`. Each
/// state passes its own [deliveryId] so no two fixtures are Equatable-equal;
/// nothing on screen reads it.
DeliveryTrackingInfo _info({
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
@JeebPreview(name: 'Tracking surface', size: _headerBox)
Widget orderSummaryPinnedHeaderTracking() =>
    _hosted(_info(deliveryId: 'd-32-tracking'));

/// The JM-031 chat/deep-link rendering, which is the ONLY one with two CTAs.
///
/// Both buttons are `Expanded` in a single `Row`, so this is where the button
/// labels get half the width they have anywhere else — "Track order" and "Open
/// chat" are short in English and longer in Arabic, and the 200%-text rendering
/// halves the room again. If either label truncates or the row overflows, it
/// shows up here and nowhere else.
@JeebPreview(name: 'Chat parity (both CTAs)', size: _headerBox)
Widget orderSummaryPinnedHeaderBothCtas() =>
    _hosted(_info(deliveryId: 'd-32-chat'), trackCta: true);

/// The reported overflow, made visible: no ETA yet and no tier.
///
/// `summaryEtaPending` is 11 characters in English and 25 in Arabic ("الوقت
/// المقدّر قيد التحديد"), and this is the state a customer sees for the whole
/// window between accept and the first GPS fix — i.e. the longest string in the
/// strip is also the one shown the most. It doubles as the negative control for
/// the tier row: `order_summary_tier` must be absent, not blank.
@JeebPreview(name: 'ETA pending, no tier', size: _headerBox)
Widget orderSummaryPinnedHeaderEtaPending() => _hosted(
      _info(deliveryId: 'd-32-pending', tier: null, etaMinutes: null),
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
@JeebPreview(name: 'Unmapped tier id', size: _headerBox)
Widget orderSummaryPinnedHeaderUnmappedTier() => _hosted(
      _info(
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
/// VERTICALLY it is not. See [_longNameBox]: the name is the only unclamped
/// `Text` here, so at 200% it wraps to whatever height it likes and takes the
/// pinned header with it. Read this preview's 200% rendering beside the
/// 'Tracking surface' one — same widget, same box width, 288 dp of difference.
///
/// The price also renders as a bare `1234567.89` in both locales: no thousands
/// separator, no Arabic-Indic digits, and the ISO code rather than a symbol.
@JeebPreview(name: 'Long name + huge price', size: _longNameBox)
Widget orderSummaryPinnedHeaderHugePrice() => _hosted(
      _info(
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
@JeebPreview(name: 'Arabic item in EN UI', size: _headerBox)
Widget orderSummaryPinnedHeaderArabicItem() => _hosted(
      _info(
        deliveryId: 'd-32-bidi',
        itemSummary: '٢ كيلو تفاح من سبينيس',
      ),
    );
