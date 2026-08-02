// Render tests for the OrderSummaryScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the shared template — see
// `test/previews/preview_test_harness.dart`.
//
// ## What `expectedText` pins
//
// Real screen copy wherever a state produces some that ONLY it can produce —
// the item summary, the uuid standing in for a jeeber name, the fake's canned
// order. Four states have nothing of their own: the cold read paints no text at
// all (`OmdsLoadingState` is built with no `message:`), the two error cards are
// copy-identical (which IS the finding), and the compact card is the reference
// card at a different width. Those four pin their dev-chrome CAPTION, and the
// `preview specifics` group below asserts the real state behind each one, so a
// caption is never the whole proof.
//
// ## Fonts
//
// `loadInterTestFont()` runs before every test here. The shared harness does
// not load fonts, and Flutter's test face makes every glyph a 1-em square —
// Latin measures ~2x too wide, Arabic ~2.4x. Nothing in this file asserts an
// overflow (the price-pill overflow the previews document is a live defect;
// pinning the broken measurement would turn the fix into a test failure), and
// the two geometry claims that the fake face would distort — the 320 pt frame
// in EN and in AR — are measured through `withGoldenTestFonts`, which is the
// only way to get real Arabic metrics: `jeebPreviewHost` builds
// `AppTheme.light()` unmodified and the theme carries no `fontFamilyFallback`.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/previews/jeeb_preview.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/order_summary_screen_fixtures.dart';
import 'package:jeeb_mobile/features/order_summary/presentation/order_summary_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/load_test_fonts.dart';
import '../../support/sync_app_localizations.dart';
import '../preview_test_harness.dart';

/// The generic failure copy, shared by every value of `OrderSummaryFailure`.
const String _kGenericError = 'Something went wrong. Please try again.';

/// `previewCanvas`, but with the deterministic Arabic face wired into the
/// theme.
///
/// The shared harness cannot do this — it builds `AppTheme.light()` directly —
/// and without it every Arabic glyph is laid out in the 1-em test face, which
/// is ~2.4x too wide. Used only where a geometry claim is being made.
Widget _orderSummaryCanvasWithFonts(
  Widget Function() preview,
  Locale locale,
) {
  return MaterialApp(
    theme: withGoldenTestFonts(AppTheme.light()),
    darkTheme: withGoldenTestFonts(AppTheme.dark()),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<Object?>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: jeebPreviewHost(preview()),
  );
}

Future<void> _pumpWithFonts(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(_orderSummaryCanvasWithFonts(preview, locale));
  await tester.pumpAndSettle();
}

/// Every visible string inside one of the card's semantics containers, joined
/// so a label + value cell reads as one string. Mirrors the helper in
/// `test/previews/order_summary/order_summary_pinned_preview_test.dart`.
String _factText(WidgetTester tester, String identifier) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.bySemanticsIdentifier(identifier),
        matching: find.byType(Text),
      ),
    )
    .map((Text t) => t.data ?? '')
    .join('|');

/// [matching], restricted to the device frame.
///
/// Every "this word appears nowhere" assertion has to be scoped this way: the
/// dev-chrome caption above the frame deliberately NAMES the state ("error ·
/// NETWORK (offline)"), so an unscoped `findsNothing` would be asserting
/// against the label instead of the screen.
Finder _inScreen(Finder matching) => find.descendant(
      of: find.byType(OrderSummaryScreen),
      matching: matching,
    );

/// Every string painted inside the device frame, in tree order.
///
/// Used to compare two error states as WHOLE pictures rather than one assertion
/// at a time — the claim is that nothing distinguishes them, and a list of
/// `findsNothing`s can only ever check the differences somebody thought of.
List<String> _screenText(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byType(OrderSummaryScreen),
        matching: find.byType(Text),
      ),
    )
    .map((Text t) => t.data ?? '')
    .toList();

void main() {
  setUpAll(() async {
    await loadInterTestFont();
    loadPreviewArbs();
  });

  testPreviewsRender(
    'OrderSummaryScreen',
    const <String, Widget Function()>{
      'Loaded · both CTAs': orderSummaryScreenLoaded,
      'Loading · cold read': orderSummaryScreenColdRead,
      'Error · not found': orderSummaryScreenNotFound,
      'Error · network': orderSummaryScreenNetworkFailure,
      'Minimal payload': orderSummaryScreenMinimalPayload,
      'Longest content': orderSummaryScreenLongestContent,
      'Compact viewport': orderSummaryScreenCompact,
      'Unconfigured DI · fabricated summary': orderSummaryScreenUnconfiguredDi,
    },
    expectedText: const <String, String>{
      // Screen copy: the item summary of the catalog's sample order.
      'Loaded · both CTAs': 'Pharmacy pickup',
      // Nothing on screen but the app-bar title — caption.
      'Loading · cold read': OrderSummaryScreenCaptions.coldRead,
      // Copy-identical to the network card — caption.
      'Error · not found': OrderSummaryScreenCaptions.notFound,
      'Error · network': OrderSummaryScreenCaptions.networkFailure,
      // Screen copy: the uuid the parser puts where a name belongs.
      'Minimal payload': kOrderSummaryScreenJeeberId,
      // Screen copy: the dictated run-on item summary.
      'Longest content': kOrderSummaryScreenLongItem,
      // The reference card at 320 — caption.
      'Compact viewport': OrderSummaryScreenCaptions.compact,
      // Screen copy: the shipped fake's canned order, which nothing asked for.
      'Unconfigured DI · fabricated summary': 'Groceries from Spinneys',
    },
  );

  group('OrderSummaryScreen preview specifics', () {
    // NB: one preview per test. Pumping a second preview into the same tester
    // does NOT rebuild these — the canvas produces the same widget types, so
    // the `BlocProvider` element is UPDATED rather than replaced and keeps the
    // cubit the first preview created.

    testWidgets('the phone previews pin a 390 pt frame, not the canvas width', (
      WidgetTester tester,
    ) async {
      // The harness pumps an 800 pt surface: a preview that left its width to
      // the host would measure 800 here, and none of this layout applies there.
      await pumpPreview(tester, orderSummaryScreenLoaded);

      expect(tester.getSize(find.byType(OrderSummaryScreen)).width, 390);
    });

    testWidgets('the compact preview pins the 320 pt floor', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, orderSummaryScreenCompact);

      expect(tester.getSize(find.byType(OrderSummaryScreen)).width, 320);
    });

    testWidgets('the loaded state renders the whole pinned card and both CTAs',
        (WidgetTester tester) async {
      await pumpPreview(tester, orderSummaryScreenLoaded);

      expect(find.text('Order summary'), findsOneWidget);
      expect(find.text('Rami Chidiac'), findsOneWidget);
      // `'$amount $currency'` — toStringAsFixed(2) plus the ISO code.
      expect(find.text('14.50 USD'), findsOneWidget);
      expect(_factText(tester, 'order_summary_eta'), 'ETA|12 min');
      expect(_factText(tester, 'order_summary_tier'), 'Tier|Express');
      expect(_factText(tester, 'order_summary_item'), 'Item|Pharmacy pickup');
      // D11: the customer-facing reminder, and no fee/commission line anywhere.
      expect(find.text('Pay cash on delivery'), findsOneWidget);
      for (final String forbidden in const <String>[
        'ommission', // Commission / commission
        'Platform fee',
        'Service fee',
        'Earnings',
      ]) {
        expect(
          _inScreen(find.textContaining(forbidden)),
          findsNothing,
          reason: forbidden,
        );
      }
      // This route is the only host that mounts BOTH CTAs.
      expect(
        find.bySemanticsIdentifier('order_summary_open_chat'),
        findsOneWidget,
      );
      expect(find.bySemanticsIdentifier('order_summary_track'), findsOneWidget);
    });

    testWidgets('nothing on the loaded screen says WHICH order this is', (
      WidgetTester tester,
    ) async {
      // The finding, pinned. `OrderSummary` carries `deliveryId`, `requestId`
      // and `conversationId`; the screen renders none of them, so two accepted
      // orders with the same jeeber and the same price are the same picture —
      // on the screen JM-056 deep-links INTO from a transaction row. If a
      // reference is ever surfaced here, this test fails and should be updated
      // deliberately, not by accident.
      await pumpPreview(tester, orderSummaryScreenLoaded);

      for (final String reference in const <String>[
        'DEL-2044',
        'REQ-2044',
        'CONV-2044',
      ]) {
        expect(
          _inScreen(find.textContaining(reference)),
          findsNothing,
          reason: reference,
        );
      }
    });

    testWidgets('the cold read is a bare spinner with no copy and no exits', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, orderSummaryScreenColdRead);

      expect(find.byType(OmdsLoadingState), findsOneWidget);
      // `Center(child: OmdsLoadingState())` passes no `message:`, so the app-bar
      // title is the ONLY string inside the device frame for as long as the
      // fetch takes.
      expect(_screenText(tester), <String>['Order summary']);
      // No card, no error, no route to anything.
      expect(find.bySemanticsIdentifier('order_summary_pinned'), findsNothing);
      expect(find.text(_kGenericError), findsNothing);
      expect(find.bySemanticsIdentifier('order_summary_track'), findsNothing);
    });

    testWidgets('a 404 and an offline phone are the SAME picture', (
      WidgetTester tester,
    ) async {
      // The finding, pinned. `OrderSummaryFailure` classifies network /
      // notFound / unknown and `OrderSummaryCubit` stores the value in
      // `state.error` — which `_OrderSummaryView` never reads. Its `failed` arm
      // hardcodes `l10n.errorGeneric`, so every failure is one card.
      await pumpPreview(tester, orderSummaryScreenNotFound);
      final List<String> notFoundText = _screenText(tester);

      await pumpPreview(tester, orderSummaryScreenNetworkFailure);
      final List<String> networkText = _screenText(tester);

      // Body first, app bar last — `Scaffold` paints its body below the bar in
      // the tree. Three strings is the WHOLE card: an icon, one sentence and a
      // button.
      expect(
        notFoundText,
        <String>[_kGenericError, 'Refresh now', 'Order summary'],
      );
      expect(
        networkText,
        notFoundText,
        reason: 'two different typed failures, one indistinguishable card',
      );
      // Neither card names its own failure, so neither can advise the user:
      // the 404 offers a Retry that cannot succeed, and the offline case never
      // mentions the connection.
      for (final String word in const <String>[
        'not found',
        'Not found',
        'connection',
        'Connection',
        'offline',
        'network',
      ]) {
        expect(_inScreen(find.textContaining(word)), findsNothing, reason: word);
      }
    });

    testWidgets('Retry re-fails in place, with no spinner and no new copy', (
      WidgetTester tester,
    ) async {
      // The finding, pinned. The CTA calls `refresh()`, which — unlike `load()`
      // — never emits `loading`; it awaits the repository and on a second
      // failure emits `copyWith(error: …)` with the status still `failed`, i.e.
      // the frame already on screen. Nothing spins, nothing greys out, nothing
      // is said. On a 404 that is permanent.
      await pumpPreview(tester, orderSummaryScreenNotFound);
      final List<String> before = _screenText(tester);

      final Finder retry = find.text('Refresh now');
      await tester.tap(retry);
      // A single frame — this is where a `loading` emission would show.
      await tester.pump();
      expect(find.byType(OmdsLoadingState), findsNothing);

      await tester.pumpAndSettle();
      expect(find.byType(OmdsLoadingState), findsNothing);
      expect(_screenText(tester), before);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the minimal payload prints 0.00 USD as if it were a price', (
      WidgetTester tester,
    ) async {
      // The finding, pinned. `DioOrderSummaryRepository` null-coalesces `price`
      // to `0.0` and `currency` to `'USD'` INDEPENDENTLY, so a thin delivery row
      // renders an authoritative zero in a currency nobody chose — directly
      // above "Pay cash on delivery".
      await pumpPreview(tester, orderSummaryScreenMinimalPayload);

      expect(_factText(tester, 'order_summary_price'), 'Price|0.00 USD');
      expect(find.text('Pay cash on delivery'), findsOneWidget);
      // The two cells that DO have an honest placeholder for the same payload.
      expect(_factText(tester, 'order_summary_tier'), 'Tier|Pending');
      expect(_factText(tester, 'order_summary_eta'), 'ETA|ETA pending');
      // …and the ones that drop out entirely rather than fabricate.
      expect(find.bySemanticsIdentifier('order_summary_item'), findsNothing);
      expect(find.byType(FittedBox), findsNothing); // no rating chip (D6)
    });

    testWidgets('a uuid can stand where the jeeber name goes', (
      WidgetTester tester,
    ) async {
      // Same fixture, second finding: `jeeberName: … ?? (jeeberId ?? '')`, and
      // all three enrichment reads that could have supplied a name are
      // swallowed by design.
      await pumpPreview(tester, orderSummaryScreenMinimalPayload);

      expect(
        _factText(tester, 'order_summary_jeeber_name'),
        kOrderSummaryScreenJeeberId,
      );
      // Clipped at paint only — the whole uuid is what the widget was handed.
      final Text name = tester.widget<Text>(
        find.descendant(
          of: find.bySemanticsIdentifier('order_summary_jeeber_name'),
          matching: find.byType(Text),
        ),
      );
      expect(name.maxLines, 1);
      expect(name.overflow, TextOverflow.ellipsis);
    });

    testWidgets('an unconfigured DI graph renders a FABRICATED order', (
      WidgetTester tester,
    ) async {
      // The finding, pinned. This is the one preview that hands the screen
      // nothing — exactly what production does — so the assertion starts by
      // proving there is no injected repository to explain the card away.
      expect(OrderSummaryScreenFixtures.unconfiguredDi.repository, isNull);

      await pumpPreview(tester, orderSummaryScreenUnconfiguredDi);

      // `_resolveRepository()` fell through `sl.isRegistered<…>()` to
      // `FakeOrderSummaryRepository()`, whose built-in default answers ANY id.
      expect(find.text('Kamal Hajj'), findsOneWidget);
      expect(_factText(tester, 'order_summary_price'), 'Price|9.00 USD');
      expect(find.text('Pay cash on delivery'), findsOneWidget);
      // Nothing marks it as unreal: no error, no banner, no placeholder — the
      // card is indistinguishable from the loaded one above.
      expect(find.text(_kGenericError), findsNothing);
      for (final String word in const <String>[
        'Sample',
        'sample',
        'Demo',
        'demo',
        'Preview',
        'Unavailable',
      ]) {
        expect(_inScreen(find.textContaining(word)), findsNothing, reason: word);
      }
    });

    testWidgets('the longest content wraps rather than clipping', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, orderSummaryScreenLongestContent);

      expect(find.text('Abdulrahman Al-Muhandis Al-Trabulsi'), findsOneWidget);
      expect(_factText(tester, 'order_summary_price'), 'Price|1234567.89 SYP');
      // The longest tier label the resolver has, and a four-hour ETA.
      expect(_factText(tester, 'order_summary_tier'), 'Tier|On-the-way');
      expect(_factText(tester, 'order_summary_eta'), 'ETA|240 min');
      expect(
        _factText(tester, 'order_summary_item'),
        'Item|$kOrderSummaryScreenLongItem',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the 320 pt frame survives the reference card in EN and AR, '
        'measured through the real faces', (WidgetTester tester) async {
      // Measured through `withGoldenTestFonts`, so the Arabic here is Noto Sans
      // Arabic rather than the 1-em test face. The card is the only thing on
      // the screen and it lives in a `ListView`, so the narrow frame costs reach
      // rather than layout — but the header Row (avatar + name + price pill) is
      // rigid in both directions and is what would break first.
      await _pumpWithFonts(tester, orderSummaryScreenCompact);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(OrderSummaryScreen)).width, 320);
      expect(find.text('Pay cash on delivery'), findsOneWidget);

      await _pumpWithFonts(
        tester,
        orderSummaryScreenCompact,
        locale: const Locale('ar'),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(OrderSummaryScreen)).width, 320);
      // The AR copy is longer in every cell of this card.
      expect(find.text('ادفع نقداً عند التسليم'), findsOneWidget);
      expect(_factText(tester, 'order_summary_tier'), 'الفئة|إكسبرس');
    });
  });
}
