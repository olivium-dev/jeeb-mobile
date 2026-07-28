/// Run-22 chat-cluster regression — role-aware / content-aware labels on the
/// pinned order-summary strip (`order_chat_pinned_summary`).
///
/// The audited defect (proof-run22 customer-E-inprogress-bucket-a1): the strip
/// rendered the literal screen title "Order summary" as its heading, as the
/// view-summary link, AND as filler for every unresolved figure (3× on one
/// screen), plus a misleading "$ Track order" chip where the D11 cash reminder
/// belongs. These tests lock the fixed vocabulary:
///   * heading = human order reference (friendlyReference: ORD-… passthrough,
///     UUID → #XXXXXX) — never the screen title;
///   * link = "View summary";
///   * cash reminder = "Pay cash on delivery" — never "Track order";
///   * unresolved price/ETA/tier = localized "Pending" placeholder;
///   * status chip = canonical deliveryStage* vocabulary;
///   * party name is role-aware (customer sees the Jeeber, jeeber sees the
///     customer) and synthetic handles are suppressed for a role generic.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/domain/order_chat_summary.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_header_expansion_store.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/order_chat_pinned_summary.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Localization host (sync ARB load), mirroring order_chat_jm025_test.dart.
// ---------------------------------------------------------------------------
class _SyncLocDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncLocDelegate(this._arbByTag);
  final Map<String, String> _arbByTag;
  @override
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);
  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arbByTag[locale.languageCode]!);
  @override
  bool shouldReload(_SyncLocDelegate old) => false;
}

late _SyncLocDelegate _delegate;

void _loadArb() {
  final en = File('lib/l10n/app_en.arb').readAsStringSync();
  final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  _delegate = _SyncLocDelegate({'en': en, 'ar': ar});
}

Widget _host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        _delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    );

/// b02 chat-header redesign: the strip is COLLAPSED by default and discloses
/// the party line, the requirement, the ETA/tier chips and the cash reminder
/// behind `order_chat_summary_expand`. Every assertion below that targets one
/// of those elements now opens the disclosure first — the vocabulary they lock
/// is unchanged, only the number of taps to see it.
Future<void> _expand(WidgetTester tester) async {
  await tester.tap(find.bySemanticsIdentifier('order_chat_summary_expand'));
  await tester.pump();
}

void main() {
  setUpAll(_loadArb);
  // The choice is remembered for the SESSION, and widget tests share one
  // process — without this a test that expands leaks that state into the next.
  setUp(ChatHeaderExpansionStore.instance.reset);

  const uuid = '9acb579d-1c2e-4f3a-b8d1-77aa10cc42e6';
  const syntheticHandle = 'jeeb-e1a35ea8a520';

  testWidgets(
      'full summary (customer viewer): order ref heading, jeeber name, '
      'canonical status, no repeated "Order summary" and no "Track order"',
      (tester) async {
    const summary = OrderChatSummary(
      deliveryId: uuid,
      requestId: uuid,
      priceLabel: r'$9.00',
      jeeberName: 'Kamal Hajj',
      etaMinutes: 25,
      tierId: 'express',
      orderRef: 'ORD-23470',
      statusId: 'picked_up',
    );
    await tester.pumpWidget(_host(OrderChatPinnedSummary(
      summary: summary,
      counterpartName: 'Kamal Hajj',
      onViewSummary: () {},
    )));
    await tester.pump();
    await _expand(tester);

    // Heading is the human order reference, passed through untouched.
    expect(find.text('ORD-23470'), findsOneWidget);
    // Link carries its own label — not a second copy of the title.
    expect(find.text('View summary'), findsOneWidget);
    // Party name: the customer sees the winning Jeeber.
    expect(find.text('Kamal Hajj'), findsOneWidget);
    // Locked figures render verbatim from the fixture's priceLabel (this
    // widget takes an already-formatted label; it does not call MoneyFormat).
    expect(find.text(r'$9.00'), findsOneWidget);
    // Canonical status vocabulary (deliveryStage*).
    expect(find.text('Picked up'), findsOneWidget);
    // D11 cash reminder — the dedicated key, never the track CTA.
    expect(find.text('Pay cash on delivery'), findsOneWidget);
    expect(find.text('Track order'), findsNothing);
    // THE run-22 defect: the screen title must not appear anywhere on the strip.
    expect(find.text('Order summary'), findsNothing);
  });

  testWidgets(
      'sparse summary: UUID shortens to #CC42E6, unresolved figures read '
      '"Pending" (never the screen title ×3), status floors at Matched',
      (tester) async {
    const summary = OrderChatSummary(deliveryId: uuid);
    await tester.pumpWidget(_host(OrderChatPinnedSummary(
      summary: summary,
      counterpartName: 'Kamal Hajj',
      onViewSummary: () {},
    )));
    await tester.pump();
    await _expand(tester);

    // Heading derives a short stable reference from the delivery id.
    expect(find.text('#CC42E6'), findsOneWidget);
    // price + ETA + tier all pending → three placeholder chips, assertable ids
    // preserved, zero repeated titles.
    expect(find.text('Pending'), findsNWidgets(3));
    expect(find.text('Order summary'), findsNothing);
    // The strip only renders on an accepted order → Matched is the floor.
    expect(find.text('Matched'), findsOneWidget);
  });

  testWidgets(
      'synthetic jeeber handle is suppressed for the customer viewer — '
      'falls back to "Your Jeeber", never leaks jeeb-<hash>', (tester) async {
    const summary = OrderChatSummary(
      deliveryId: uuid,
      jeeberName: syntheticHandle,
    );
    await tester.pumpWidget(_host(OrderChatPinnedSummary(
      summary: summary,
      counterpartName: uuid, // counterpart resolved to a raw UUID — also junk
      onViewSummary: () {},
    )));
    await tester.pump();
    await _expand(tester);

    expect(find.text('Your Jeeber'), findsOneWidget);
    expect(find.text(syntheticHandle), findsNothing);
    expect(find.textContaining('jeeb-'), findsNothing);
  });

  testWidgets(
      'jeeber viewer sees the CUSTOMER, never their own jeeberName',
      (tester) async {
    const summary = OrderChatSummary(
      deliveryId: uuid,
      jeeberName: 'Kamal Hajj', // the viewer themselves
    );
    await tester.pumpWidget(_host(OrderChatPinnedSummary(
      summary: summary,
      counterpartName: 'Alice Client',
      onViewSummary: () {},
      viewerIsJeeber: true,
    )));
    await tester.pump();
    await _expand(tester);

    expect(find.text('Alice Client'), findsOneWidget);
    expect(find.text('Kamal Hajj'), findsNothing);
  });

  testWidgets(
      'jeeber viewer with a synthetic customer handle falls back to "Customer"',
      (tester) async {
    const summary = OrderChatSummary(deliveryId: uuid, jeeberName: 'Kamal');
    await tester.pumpWidget(_host(OrderChatPinnedSummary(
      summary: summary,
      counterpartName: syntheticHandle,
      onViewSummary: () {},
      viewerIsJeeber: true,
    )));
    await tester.pump();
    await _expand(tester);

    expect(find.text('Customer'), findsOneWidget);
    expect(find.text(syntheticHandle), findsNothing);
  });

  testWidgets('delivered status maps onto the canonical vocabulary',
      (tester) async {
    const summary = OrderChatSummary(
      deliveryId: uuid,
      orderRef: 'ORD-1',
      statusId: 'Done', // mock SM-1 terminal spelling
    );
    await tester.pumpWidget(_host(OrderChatPinnedSummary(
      summary: summary,
      counterpartName: 'Kamal Hajj',
      onViewSummary: () {},
    )));
    await tester.pump();
    await _expand(tester);

    expect(find.text('Delivered'), findsOneWidget);
  });

  // -------------------------------------------------------------------
  // P3 (b01-20260725) — the INITIAL REQUIREMENT row.
  // -------------------------------------------------------------------

  /// The description's own `Text` node (the one AutoDirectionText renders).
  Text descriptionText(WidgetTester tester, String data) =>
      tester.widget<Text>(find.descendant(
        of: find.bySemanticsIdentifier('order_chat_request_description'),
        matching: find.text(data),
      ));

  testWidgets('P3/M8: the initial-requirement row renders with both ids',
      (tester) async {
    const summary = OrderChatSummary(
      deliveryId: uuid,
      orderRef: 'ORD-1',
      description: '2 kilos apples from Spinneys',
    );
    await tester.pumpWidget(_host(OrderChatPinnedSummary(
      summary: summary,
      counterpartName: 'Kamal Hajj',
      onViewSummary: () {},
    )));
    await tester.pump();
    await _expand(tester);

    expect(
      find.bySemanticsIdentifier('order_chat_request_description'),
      findsOneWidget,
    );
    expect(find.bySemanticsIdentifier('order_summary_item'), findsOneWidget);
    expect(find.text('2 kilos apples from Spinneys'), findsOneWidget);
  });

  testWidgets('P3/M9: an EMPTY description hides the row entirely — no box, '
      'no "Pending" filler', (tester) async {
    const summary = OrderChatSummary(
      deliveryId: uuid,
      orderRef: 'ORD-1',
      description: '',
    );
    await tester.pumpWidget(_host(OrderChatPinnedSummary(
      summary: summary,
      counterpartName: 'Kamal Hajj',
      onViewSummary: () {},
    )));
    await tester.pump();
    await _expand(tester);

    expect(
      find.bySemanticsIdentifier('order_chat_request_description'),
      findsNothing,
    );
    expect(find.bySemanticsIdentifier('order_summary_item'), findsNothing);
    // The row adds ZERO "Pending" placeholders — the 3 chips are unchanged.
    expect(find.text('Pending'), findsNWidgets(3));
  });

  testWidgets('P3/M10: RTL — an Arabic description inside an English UI reads '
      'right-to-left', (tester) async {
    const arabic = '٢ كيلو تفاح من سبينيس';
    const summary = OrderChatSummary(
      deliveryId: uuid,
      orderRef: 'ORD-1',
      description: arabic,
    );
    await tester.pumpWidget(_host(OrderChatPinnedSummary(
      summary: summary,
      counterpartName: 'Kamal Hajj',
      onViewSummary: () {},
    )));
    await tester.pump();
    await _expand(tester);

    expect(descriptionText(tester, arabic).textDirection, TextDirection.rtl);
  });

  testWidgets('P3/M11: LTR — an English description inside an Arabic UI reads '
      'left-to-right, while the strip itself stays RTL', (tester) async {
    const english = 'Apples from Spinneys';
    const summary = OrderChatSummary(
      deliveryId: uuid,
      orderRef: 'ORD-1',
      description: english,
    );
    await tester.pumpWidget(_host(
      OrderChatPinnedSummary(
        summary: summary,
        counterpartName: 'Kamal Hajj',
        onViewSummary: () {},
      ),
      locale: const Locale('ar'),
    ));
    await tester.pump();
    await _expand(tester);

    expect(descriptionText(tester, english).textDirection, TextDirection.ltr);
    // The ambient strip direction is still RTL (the app is RTL-first).
    expect(
      Directionality.of(
        tester.element(find.byType(OrderChatPinnedSummary)),
      ),
      TextDirection.rtl,
    );
  });

  testWidgets('P3/M12: a 400-char description clamps to 2 lines + ellipsis and '
      'does not overflow a narrow strip', (tester) async {
    final long = 'apples ' * 60; // > 400 chars
    final summary = OrderChatSummary(
      deliveryId: uuid,
      orderRef: 'ORD-1',
      description: long,
    );
    await tester.pumpWidget(_host(SizedBox(
      // A realistic narrow-phone viewport. NOTE: the strip's own intrinsic
      // height is ~163 px even with NO description, so a 200 px host would
      // overflow on the empty strip too — that host would test the harness,
      // not the clamp.
      width: 360,
      height: 640,
      child: Column(children: [
        OrderChatPinnedSummary(
          summary: summary,
          counterpartName: 'Kamal Hajj',
          onViewSummary: () {},
        ),
      ]),
    )));
    await tester.pump();
    await _expand(tester);

    expect(tester.takeException(), isNull);
    final text = descriptionText(tester, long);
    expect(text.maxLines, 2);
    expect(text.overflow, TextOverflow.ellipsis);
    // R2 guard: the clamp BOUNDS the strip's growth. Measured baselines at this
    // width — pre-b02, no description 163.5 px, 2-line description 207.5 px.
    // Post-b02 the strip is COLLAPSED by default (one 48 dp row) and this
    // assertion is on the EXPANDED state, which carries the party line and the
    // ETA/tier/cash rows the old strip showed unconditionally: 248 px. The
    // clamp is still what bounds it — unclamped, 420 chars wrap to ~17 lines in
    // the square-glyph test font and the strip runs past 640 px.
    expect(
      tester.getSize(find.byType(OrderChatPinnedSummary)).height,
      lessThan(260),
    );
  });

  testWidgets('P3/M13: tapping the row expands it to the full text',
      (tester) async {
    final long = 'apples ' * 60;
    final summary = OrderChatSummary(
      deliveryId: uuid,
      orderRef: 'ORD-1',
      description: long,
    );
    // The harness, not the subject: with the header expanded AND the description
    // expanded to its full 420 chars the strip is ~650 px in the widget-test
    // font (square em glyphs, ~1.8x real Inter width), so the 600 px default
    // test surface is too short to lay it out. The clamp itself is asserted in
    // M12.
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_host(SizedBox(
      width: 360,
      height: 1200,
      child: Column(children: [
        OrderChatPinnedSummary(
          summary: summary,
          counterpartName: 'Kamal Hajj',
          onViewSummary: () {},
        ),
      ]),
    )));
    await tester.pump();
    await _expand(tester);

    expect(descriptionText(tester, long).maxLines, 2);

    await tester.tap(
      find.bySemanticsIdentifier('order_chat_request_description'),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(descriptionText(tester, long).maxLines, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('P3/M14: the view-summary LINK is hidden when onViewSummary is '
      'null (the Jeeber strip) — the strip itself still renders', (tester) async {
    const summary = OrderChatSummary(
      deliveryId: uuid,
      orderRef: 'ORD-1',
      description: '2 kilos apples from Spinneys',
    );
    await tester.pumpWidget(_host(const OrderChatPinnedSummary(
      summary: summary,
      counterpartName: syntheticHandle,
      onViewSummary: null,
      viewerIsJeeber: true,
    )));
    await tester.pump();
    await _expand(tester);

    expect(
      find.bySemanticsIdentifier('order_chat_pinned_summary'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('order_chat_view_summary_link'),
      findsNothing,
    );
    expect(find.text('View summary'), findsNothing);
    // Party line falls back to the localized customer generic.
    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('2 kilos apples from Spinneys'), findsOneWidget);
  });
}
