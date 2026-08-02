/// Widget previews for [OrderChatPinnedSummary] — run with
/// `flutter widget-preview start`.
///
/// The strip is a pure-props widget: everything it paints comes from the
/// [OrderChatSummary] it is handed, so no repository, cubit or DI graph is
/// involved and these previews are network-free by construction rather than by
/// the guard in [jeebPreviewHost].
///
/// The ONE piece of ambient state is the expand/collapse choice, which lives in
/// the process-wide [ChatHeaderExpansionStore] (b02: collapsed by default,
/// remembered per order for the session). [_hosted] seeds that store for the
/// state's own key before building, which is why an "expanded" preview opens
/// expanded. Seeding happens when the preview FUNCTION runs, not on every
/// rebuild, so tapping the disclosure control in the canvas still works.
///
/// Each state carries its own `deliveryId`: the store keys on it, so two states
/// sharing an id would share one expansion choice and the collapsed preview
/// would open expanded after the expanded one had rendered.
///
/// The fixtures mirror `test/features/chat/order_chat_pinned_summary_labels_test.dart`
/// and `test/features/chat/chat_header_a11y_test.dart`; the previews exist so
/// the *visual* half of those contracts (row overflow, RTL mirroring, the
/// 200%-text ceiling) is reviewable without booting the app into an accepted
/// order.
library;

import 'package:flutter/material.dart';

import '../../features/chat/domain/order_chat_summary.dart';
import '../../features/chat/presentation/widgets/chat_header_expansion_store.dart';
import '../../features/chat/presentation/widgets/order_chat_pinned_summary.dart';
import '../harness/jeeb_preview.dart';

/// Collapsed, the strip is ONE 48 dp row — but at 200% text it wraps the
/// reference / status / amount onto a second line by design, so the box has to
/// leave room for two (measured 80 dp at 1x, 144 dp at 2x).
const Size _collapsedBox = Size(390, 180);

/// Expanded: collapsed row + party line + requirement + chips + cash reminder.
///
/// Sized for the 200%-text rendering, which is the tallest of the three: across
/// the expanded states below the strip measures 204–272 dp at 1x and 368–452 dp
/// at 2x on a 390 dp canvas. A box that fits only the 1x rendering would report
/// the other two as overflowing the CANVAS, which says nothing about the widget.
const Size _expandedBox = Size(390, 480);

/// The initial requirement as customers actually type it: one run-on line, no
/// punctuation, well past the two-line clamp.
const String _longDescription =
    'two kilos of red apples and one kilo of bananas plus a large sourdough '
    'loaf from the bakery counter and if they have the imported yoghurt take '
    'four of the small ones otherwise skip it and please ring the intercom '
    'twice because the doorbell has been broken since last week thank you';

/// Mirrors `_OrderChatPinnedSummaryState._expansionKey`.
///
/// It is duplicated rather than exposed because the store key is production
/// implementation detail. `test/previews/chat/order_chat_pinned_summary_preview_test.dart`
/// asserts that an "expanded" preview really opens expanded, which is what
/// catches this copy drifting from the original.
String _expansionKeyFor(OrderChatSummary summary) {
  if (summary.deliveryId.isNotEmpty) return 'delivery:${summary.deliveryId}';
  if (summary.requestId.isNotEmpty) return 'request:${summary.requestId}';
  return 'unkeyed';
}

/// Builds the strip with its session expansion state pre-seeded.
///
/// [viewerIsJeeber] also drops the view-summary link, because that is how the
/// production Jeeber leg renders it: the `order-summary` route is owner-scoped,
/// so a null handler removes the affordance rather than leaving a dead one.
Widget _hosted(
  OrderChatSummary summary, {
  required String counterpartName,
  bool expanded = false,
  bool viewerIsJeeber = false,
}) {
  ChatHeaderExpansionStore.instance
      .setExpanded(_expansionKeyFor(summary), expanded: expanded);
  return OrderChatPinnedSummary(
    summary: summary,
    counterpartName: counterpartName,
    onViewSummary: viewerIsJeeber ? null : () {},
    viewerIsJeeber: viewerIsJeeber,
  );
}

/// What every customer sees first (b02): the strip is collapsed by default, so
/// the message list survives an open keyboard.
///
/// Only three things are on screen — reference, status, amount — and the whole
/// row must stay inside 48 dp. This is the state to check when a status label
/// gets longer in translation: Arabic "قيد التوصيل" and a 200% text scale both
/// push this row, and the row's answer is to WRAP, not to squeeze or clip.
@JeebPreview(name: 'Collapsed (default)', size: _collapsedBox)
Widget orderChatPinnedSummaryCollapsed() => _hosted(
      const OrderChatSummary(
        deliveryId: '9acb579d-1c2e-4f3a-b8d1-77aa10cc42e6',
        requestId: '9acb579d-1c2e-4f3a-b8d1-77aa10cc42e6',
        orderRef: 'ORD-23470',
        priceLabel: r'$12.00',
        jeeberName: 'Kamal Hajj',
        etaMinutes: 25,
        tierId: 'express',
        statusId: 'in_transit',
        description: '2 kilos apples from Spinneys',
      ),
      counterpartName: 'Kamal Hajj',
    );

/// The happy path once disclosed: every locked figure resolved.
///
/// Note what is NOT here — a second slab of chroma. b02 spends the header's
/// only accent on the status chip; if this preview ever shows two competing
/// coloured capsules, the M3 hierarchy fix has regressed. The cash reminder is
/// also the contrast canary: it used to be `onPrimaryContainer` faded to 3.85:1
/// over a saturated fill, which is what made it unreadable.
@JeebPreview(name: 'Expanded (all fields)', size: _expandedBox)
Widget orderChatPinnedSummaryExpanded() => _hosted(
      const OrderChatSummary(
        deliveryId: 'c1f0e2b4-8d55-4a17-9e30-5b6c7d8e9f01',
        requestId: 'c1f0e2b4-8d55-4a17-9e30-5b6c7d8e9f01',
        orderRef: 'ORD-23471',
        priceLabel: r'$12.00',
        jeeberName: 'Kamal Hajj',
        etaMinutes: 25,
        tierId: 'express',
        statusId: 'picked_up',
        description: '2 kilos apples from Spinneys',
      ),
      counterpartName: 'Kamal Hajj',
      expanded: true,
    );

/// Cold open: the chat is on screen but the summary fetch has not landed, so
/// the row carries nothing but its delivery id.
///
/// This is the run-22 regression state, made visible. The strip used to fill
/// every unresolved figure — heading included — with the literal screen title
/// "Order summary", three times on one screen. The fixed vocabulary is a short
/// derived reference (`#7719D4`, never a raw UUID), a localized "Pending" per
/// unresolved chip, and "Matched" as the honest status floor. Any "Order
/// summary" text in this preview is that bug returning.
@JeebPreview(name: 'Pending (nothing resolved)', size: _expandedBox)
Widget orderChatPinnedSummaryPending() => _hosted(
      const OrderChatSummary(
        deliveryId: '5b2e8c14-77af-4a63-9c05-6d90ab7719d4',
      ),
      counterpartName: 'Kamal Hajj',
      expanded: true,
    );

/// The Jeeber leg (P3 + the run-22 role fix), which differs in two ways that
/// are easy to get backwards.
///
/// The party line names the person on the OTHER side — a Jeeber must see the
/// CUSTOMER, never their own name echoed back — and here that customer resolved
/// to a synthetic `jeeb-<hash>` handle, so it is suppressed for the localized
/// generic. Second, there is no view-summary link at all: `order-summary` is
/// owner-scoped, so the whole node is removed rather than left as a dead
/// affordance.
@JeebPreview(name: 'Jeeber viewer (no link)', size: _expandedBox)
Widget orderChatPinnedSummaryJeeberViewer() => _hosted(
      const OrderChatSummary(
        deliveryId: '2ab41d67-0c98-4f52-b7e1-3d5a9e0f4c88',
        orderRef: 'ORD-23472',
        priceLabel: r'$12.00',
        jeeberName: 'Kamal Hajj',
        etaMinutes: 25,
        tierId: 'flash',
        statusId: 'at_door',
        description: '2 kilos apples from Spinneys',
      ),
      counterpartName: 'jeeb-e1a35ea8a520',
      expanded: true,
      viewerIsJeeber: true,
    );

/// The layout ceiling: everything at its longest plausible value at once — a
/// long order reference, a three-part Arabic-transliterated name, a Lebanese
/// lira amount (no cents, six digits), a 3-hour ETA and a 260-char requirement.
///
/// Two independent clamps are under review here. The collapsed row ellipsises
/// the reference so the amount and the expand control can never be pushed off
/// the trailing edge, and the requirement clamps to two lines so a long
/// description cannot push the message list off screen (the run-22 "BOTTOM
/// OVERFLOWED" class). The AR RTL and 200%-text renderings are the ones that
/// matter: the EN light rendering keeps looking fine long after both have
/// broken.
@JeebPreview(name: 'Longest content', size: _expandedBox)
Widget orderChatPinnedSummaryLongContent() => _hosted(
      const OrderChatSummary(
        deliveryId: '7c0a4e21-93b6-4f18-a5d2-8e1f6b40aa31',
        requestId: '7c0a4e21-93b6-4f18-a5d2-8e1f6b40aa31',
        orderRef: 'ORD-2026-0801-BEIRUT-HAMRA-0042',
        priceLabel: '1,250,000 L.L.',
        jeeberName: 'Abdulrahman Al-Muhandis Al-Trabulsi',
        etaMinutes: 185,
        tierId: 'on-the-way',
        statusId: 'in_transit',
        description: _longDescription,
      ),
      counterpartName: 'Abdulrahman Al-Muhandis Al-Trabulsi',
      expanded: true,
    );

/// Bidi: an Arabic requirement inside an English UI (P3/M10).
///
/// The requirement is the only free text on this strip, so it is the only place
/// the UI locale and the content direction can disagree. [AutoDirectionText]
/// applies the UAX#9 first-strong rule per string, which must put this text
/// right-aligned and RTL while the surrounding English chrome stays LTR — and
/// must do the mirror of that in the AR RTL rendering of this same preview.
/// A description that reads left-aligned here is the bug.
@JeebPreview(name: 'Arabic requirement in EN UI', size: _expandedBox)
Widget orderChatPinnedSummaryArabicDescription() => _hosted(
      const OrderChatSummary(
        deliveryId: '8d3c95f2-41ab-4c07-9e6b-2f5081bc7a19',
        orderRef: 'ORD-23473',
        priceLabel: r'$7.50',
        jeeberName: 'Kamal Hajj',
        etaMinutes: 15,
        tierId: 'standard',
        statusId: 'matched',
        description: '٢ كيلو تفاح من سبينيس',
      ),
      counterpartName: 'Kamal Hajj',
      expanded: true,
    );
