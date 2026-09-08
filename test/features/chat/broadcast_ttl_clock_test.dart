// X3 — the broadcasting captures must not read the wall clock.
//
// The catalog pins the offer cards at today 09:41, so the derived offer window
// closes at 09:46. `BroadcastTtlIndicator` used to subtract `DateTime.now()`,
// which made the chip's number — and its very presence — a function of the
// hour the suite ran: hidden after 09:46, and some arbitrary five-figure
// second count before it. These tests fix the rendered second count, so a
// wall-clock read is a failure rather than a coin flip.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jeeb_mobile/devtool/catalog/screen_catalog.dart';
import 'package:jeeb_mobile/features/chat/data/dev_chat_fixture_gateway.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/broadcast_ttl_indicator.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

/// The catalog capture path: pushed on top of a root route, exactly as
/// `test/tools/catalog_capture_test.dart` mounts every state.
const String _kPath = '/state';

GoRouter _router(WidgetBuilder builder) => GoRouter(
  initialLocation: _kPath,
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (_, _) => const Scaffold(),
      routes: <RouteBase>[
        GoRoute(
          path: _kPath.substring(1),
          builder: (BuildContext context, _) => builder(context),
        ),
      ],
    ),
  ],
);

CatalogState _catalogState(String feature, String screen, int index) {
  final CatalogEntry entry = kScreenCatalog.firstWhere(
    (CatalogEntry e) => e.feature == feature && e.screen == screen,
  );
  return entry.states[index];
}

Future<void> _pumpCatalogState(
  WidgetTester tester,
  CatalogState state,
) async {
  final GoRouter router = _router(state.builder);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object?>>[
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    ),
  );
  await pumpPastFakeLatency(tester);
}

void main() {
  // The fixture window is 5 minutes wide and the fixture clock sits 2 minutes
  // into it, so the chip must always read the same 180 seconds.
  const String expected = 'Offer window closes in 180s';

  testWidgets('chat catalog broadcasting state pins the TTL chip', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpCatalogState(
      tester,
      _catalogState('chat', 'chat_screen', 1),
    );

    expect(find.text(expected), findsOneWidget);
  });

  testWidgets('chat-detail catalog broadcasting state pins the TTL chip', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpCatalogState(
      tester,
      _catalogState('deep_link_targets', 'ChatDetailScreen', 1),
    );

    expect(find.text(expected), findsOneWidget);
  });

  testWidgets('the countdown reads the injected clock, not the device', (
    WidgetTester tester,
  ) async {
    final DateTime closesAt = DateTime(2026, 1, 1, 9, 46);
    await tester.pumpWidget(
      wrapForTest(
        Scaffold(
          body: BroadcastTtlIndicator(
            expiresAt: closesAt,
            now: () => closesAt.subtract(const Duration(seconds: 42)),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Offer window closes in 42s'), findsOneWidget);
  });

  testWidgets('an injected clock past the window hides the chip', (
    WidgetTester tester,
  ) async {
    final DateTime closesAt = DateTime(2026, 1, 1, 9, 46);
    await tester.pumpWidget(
      wrapForTest(
        Scaffold(
          body: BroadcastTtlIndicator(
            expiresAt: closesAt,
            now: () => closesAt.add(const Duration(seconds: 1)),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('broadcast-ttl-indicator')), findsNothing);
  });

  test('the fixture clock sits inside the fixture offer window', () {
    final DateTime offerSentAt = DevChatFixtureGateway.fixtureAnchor;
    final DateTime closesAt = offerSentAt.add(const Duration(minutes: 5));
    final int remaining = closesAt
        .difference(DevChatFixtureGateway.fixtureNow())
        .inSeconds;

    expect(remaining, 180);
  });
}
