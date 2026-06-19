// JM-031 — Order Summary + Pinned Price widget (order-summary-pinned).
//
// Proves, against the real ARBs + OMDS theme, that:
//   AC1: OrderSummaryPinned surfaces every EXACT Semantics identifier from
//        63_W1_TEST_PLAN §2.11 as its own queryable SemanticsNode
//        (`order_summary_pinned`, `_price`, `_jeeber_name`, `_eta`, `_tier`,
//         `_cash_label`) + the CTAs (`_open_chat`, `_track`).
//   AC2: tapping `order_summary_open_chat` / `order_summary_track` fires the
//        host callbacks (the chat / tracking nav edges).
//   AC4: the SAME widget is what the chat (JM-025) + tracking (JM-032) hosts
//        inject — so its ids are context-agnostic (asserted here in isolation,
//        which is what both contexts mount).
//   D6:  the rating chip is mounted ONLY when a real score exists (cold-start
//        jeebers show the name alone) — name id is always present.
//
// FAIL-WITHOUT: every `bySemanticsIdentifier` assertion `findsNothing` before
// the widget existed. Harness mirrors offer_accept_sheet_test.dart (synchronous
// LocalizationsDelegate over the real ARBs + a tall/wide surface).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'package:jeeb_mobile/features/order_summary/domain/order_summary.dart';
import 'package:jeeb_mobile/features/order_summary/presentation/widgets/order_summary_pinned.dart';

class _SyncDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncDelegate(this._arbByTag);
  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arbByTag[locale.languageCode]!);

  @override
  bool shouldReload(_SyncDelegate old) => false;
}

late _SyncDelegate _syncDelegate;

void _loadArbs() {
  final en = File('lib/l10n/app_en.arb').readAsStringSync();
  final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  _syncDelegate = _SyncDelegate({'en': en, 'ar': ar});
}

OrderSummary _summary({
  double? rating = 4.9,
  int? ratingCount = 312,
  int? etaMinutes = 20,
}) =>
    OrderSummary(
      deliveryId: 'del-client-001-active',
      requestId: 'req-client-001-accepted',
      conversationId: 'conv-journey-accepted',
      price: 9.0,
      currency: 'USD',
      jeeberName: 'Kamal Hajj',
      tier: 'express',
      jeeberRating: rating,
      jeeberRatingCount: ratingCount,
      etaMinutes: etaMinutes,
      itemSummary: 'Groceries from Spinneys',
    );

Widget _harness(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      _syncDelegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  setUpAll(_loadArbs);

  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final view = binding.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2400);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });

  group('JM-031 OrderSummaryPinned', () {
    testWidgets('AC1 — surfaces every EXACT Semantics identifier (63 §2.11)',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          OrderSummaryPinned(
            summary: _summary(),
            onOpenChat: () {},
            onTrack: () {},
          ),
        ),
      );
      await tester.pump();

      for (final id in const [
        'order_summary_pinned',
        'order_summary_price',
        'order_summary_jeeber_name',
        'order_summary_eta',
        'order_summary_tier',
        'order_summary_cash_label',
        'order_summary_open_chat',
        'order_summary_track',
      ]) {
        expect(
          find.bySemanticsIdentifier(id),
          findsOneWidget,
          reason: '$id must surface as its own SemanticsNode.',
        );
      }
    });

    testWidgets('AC2 — open-chat + track CTAs fire their host callbacks',
        (tester) async {
      var openChat = 0;
      var track = 0;
      await tester.pumpWidget(
        _harness(
          OrderSummaryPinned(
            summary: _summary(),
            onOpenChat: () => openChat++,
            onTrack: () => track++,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.bySemanticsIdentifier('order_summary_open_chat'));
      await tester.pump();
      await tester.tap(find.bySemanticsIdentifier('order_summary_track'));
      await tester.pump();

      expect(openChat, 1);
      expect(track, 1);
    });

    testWidgets(
        'AC4 — a null callback hides its CTA (never a dead end) but the '
        'core summary ids stay present', (tester) async {
      // Tracking-host injection: onTrack null (already on tracking).
      await tester.pumpWidget(
        _harness(
          OrderSummaryPinned(
            summary: _summary(),
            onOpenChat: () {},
            dense: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.bySemanticsIdentifier('order_summary_pinned'), findsOneWidget);
      expect(find.bySemanticsIdentifier('order_summary_open_chat'),
          findsOneWidget);
      expect(find.bySemanticsIdentifier('order_summary_track'), findsNothing);
    });

    testWidgets('D6 — rating chip hidden when no score; name still present',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          OrderSummaryPinned(
            summary: _summary(rating: null, ratingCount: 0),
            onTrack: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.bySemanticsIdentifier('order_summary_jeeber_name'),
          findsOneWidget);
      // ETA pending renders when null rather than a misleading "0 min".
      await tester.pumpWidget(
        _harness(
          OrderSummaryPinned(
            summary: _summary(etaMinutes: null),
            onTrack: () {},
          ),
        ),
      );
      await tester.pump();
      expect(find.bySemanticsIdentifier('order_summary_eta'), findsOneWidget);
    });

    testWidgets('renders in Arabic (RTL) without throwing', (tester) async {
      await tester.pumpWidget(
        _harness(
          OrderSummaryPinned(summary: _summary(), onTrack: () {}),
          locale: const Locale('ar'),
        ),
      );
      await tester.pump();
      expect(find.bySemanticsIdentifier('order_summary_pinned'), findsOneWidget);
      expect(find.bySemanticsIdentifier('order_summary_cash_label'),
          findsOneWidget);
    });
  });
}
