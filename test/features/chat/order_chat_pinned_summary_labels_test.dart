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

Widget _host(Widget child) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        _delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    );

void main() {
  setUpAll(_loadArb);

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

    // Heading is the human order reference, passed through untouched.
    expect(find.text('ORD-23470'), findsOneWidget);
    // Link carries its own label — not a second copy of the title.
    expect(find.text('View summary'), findsOneWidget);
    // Party name: the customer sees the winning Jeeber.
    expect(find.text('Kamal Hajj'), findsOneWidget);
    // Locked figures render verbatim.
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

    expect(find.text('Delivered'), findsOneWidget);
  });
}
