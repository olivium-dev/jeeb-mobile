// Regression cover for the Requests-screen state-gallery audit fixes
// (D2 · D3 · D4 · D6 · D7 · D8 · O10). B1 lives in
// `client_home_offline_cold_start_test.dart`; D5 and D9 in their own files.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/formatting/bidi_isolate.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/directional_icons.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_state.dart';
import 'package:jeeb_mobile/features/home_client/data/in_memory_client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_request.dart';
import 'package:jeeb_mobile/features/home_client/presentation/client_home_screen.dart';
import 'package:jeeb_mobile/features/home_client/presentation/tabs/pending_requests_tab.dart';
import 'package:jeeb_mobile/features/home_client/presentation/widgets/replies_card.dart';

import '../../support/sync_app_localizations.dart';

Widget _app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  theme: AppTheme.light(),
  locale: locale,
  supportedLocales: const [Locale('en'), Locale('ar')],
  localizationsDelegates: const [
    SyncAppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child!,
  ),
  home: Scaffold(body: child),
);

Widget _screen(
  ClientHomeRepository repo, {
  Locale locale = const Locale('en'),
  ClientHomeTab? initialTab,
  String? greetingName = 'Layla',
}) => _app(
  BlocProvider(
    create: (_) => ClientHomeCubit(
      repository: repo,
      greetingNameProvider: () => greetingName,
    )..load(),
    child: ClientHomeScreen(
      initialTab: initialTab ?? ClientHomeTab.pendingRequests,
    ),
  ),
  locale: locale,
);

ClientHomeRequest _pending({
  String id = 'pen-1',
  String? itemsSummary = '2 kg tomatoes and a bag of rice',
  DateTime? createdAt,
}) => ClientHomeRequest(
  id: id,
  displayId: 'ORD-98120',
  title: 'ORD-98120',
  status: ClientRequestStatus.searching,
  destinationLabel: 'Hamra, Beirut',
  itemsSummary: itemsSummary,
  tier: ClientRequestTier.express,
  createdAt: createdAt,
);

ClientHomeRequest _reply({String id = 'rep-1'}) => ClientHomeRequest(
  id: id,
  displayId: 'ORD-23470',
  title: 'ORD-23470',
  status: ClientRequestStatus.offersReceived,
  destinationLabel: 'Hamra, Beirut',
  itemsSummary:
      'a very long items summary that must be allowed to run onto a second '
      'rendered line just like the pending card already does',
  tier: ClientRequestTier.express,
  offerCount: 3,
  offerAvatarUrls: const ['a', 'b', 'c'],
);

void main() {
  group('D3 — DirectionalIcons never hand-mirrors', () {
    testWidgets('every helper returns the LTR glyph in both directions', (
      tester,
    ) async {
      late BuildContext ltr;
      late BuildContext rtl;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              ltr = context;
              return Directionality(
                textDirection: TextDirection.rtl,
                child: Builder(
                  builder: (context) {
                    rtl = context;
                    return const SizedBox.shrink();
                  },
                ),
              );
            },
          ),
        ),
      );

      for (final pair in <List<Object>>[
        [
          DirectionalIcons.back(ltr),
          DirectionalIcons.back(rtl),
          Icons.arrow_back,
        ],
        [
          DirectionalIcons.backIos(ltr),
          DirectionalIcons.backIos(rtl),
          Icons.arrow_back_ios,
        ],
        [
          DirectionalIcons.forward(ltr),
          DirectionalIcons.forward(rtl),
          Icons.arrow_forward,
        ],
        [
          DirectionalIcons.disclosure(ltr),
          DirectionalIcons.disclosure(rtl),
          Icons.chevron_right,
        ],
        [
          DirectionalIcons.disclosureIos(ltr),
          DirectionalIcons.disclosureIos(rtl),
          Icons.arrow_forward_ios,
        ],
      ]) {
        expect(pair[0], pair[2]);
        expect(
          pair[1],
          pair[2],
          reason: 'the framework mirrors these glyphs; the helper must not',
        );
      }
    });

    test('all five glyphs really declare matchTextDirection', () {
      for (final icon in const <IconData>[
        Icons.arrow_back,
        Icons.arrow_back_ios,
        Icons.arrow_forward,
        Icons.arrow_forward_ios,
        Icons.chevron_right,
      ]) {
        expect(icon.matchTextDirection, isTrue);
      }
    });
  });

  group('D3 — bidi isolate on user-authored text', () {
    test('bidiIsolate brackets non-empty text only', () {
      expect(bidiIsolate(''), '');
      expect(
        bidiIsolate('2 kg tomatoes'),
        '${kBidiIsolateStart}2 kg tomatoes$kBidiIsolateEnd',
      );
    });

    testWidgets('an ar pending card keeps the summary inside an isolate', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          PendingCountdownCard(request: _pending()),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(bidiIsolate('2 kg tomatoes and a bag of rice')),
        findsOneWidget,
      );
    });
  });

  group('D2 — the pending meta row never clips the age', () {
    testWidgets('the full "Created N minutes ago" string renders', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(
          PendingCountdownCard(
            request: _pending(
              createdAt: DateTime.now().subtract(const Duration(minutes: 3)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final age = find.byKey(const Key('pending-created-age'));
      expect(age, findsOneWidget);
      expect(find.text('Created 3 minutes ago'), findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(age);
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: 'the age line must never ellipsize',
      );
    });

    testWidgets('320dp at textScale 2.0 lays out without a RenderFlex break', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: _app(
            PendingCountdownCard(
              request: _pending(
                createdAt: DateTime.now().subtract(const Duration(minutes: 6)),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('D6 — the replies card has a real Accept button', () {
    testWidgets('card body opens offers; only the pill accepts', (
      tester,
    ) async {
      var checkOffers = 0;
      var accepts = 0;
      await tester.pumpWidget(
        _app(
          RepliesCard(
            request: _reply(),
            onCheckOffers: () => checkOffers++,
            onAccept: () => accepts++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('View offers'), findsOneWidget);

      // The card BODY must never be a money action.
      await tester.tap(find.byKey(const Key('replies-card-rep-1')));
      await tester.pumpAndSettle();
      expect(checkOffers, 1);
      expect(accepts, 0);

      await tester.tap(find.byKey(const Key('replies-accept-rep-1')));
      await tester.pumpAndSettle();
      expect(accepts, 1);
      expect(checkOffers, 1);
    });

    testWidgets('the summary wraps to two lines, like the pending card', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          RepliesCard(request: _reply(), onCheckOffers: () {}, onAccept: () {}),
        ),
      );
      await tester.pumpAndSettle();

      final summary = find.text(bidiIsolate(_reply().summaryLine));
      expect(summary, findsOneWidget);
      expect(tester.widget<Text>(summary).maxLines, 2);
    });
  });

  group('D7 — an applied filter can be cleared', () {
    testWidgets('the clear button appears, clears, and the sheet reopens', (
      tester,
    ) async {
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        ClientHomeSnapshot(
          pending: [_pending()],
          offerStatusRequests: [_reply()],
        ),
        latency: Duration.zero,
      );
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _screen(repo, initialTab: ClientHomeTab.pendingRequests),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('client-home-filter-clear')), findsNothing);

      await tester.tap(find.byKey(const Key('client-home-tab-more')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.bySemanticsIdentifier('offer_status_filter_submitted'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Submitted'), findsWidgets);
      expect(find.byKey(const Key('client-home-filter-clear')), findsOneWidget);
      expect(find.bySemanticsIdentifier('orders_filter_clear'), findsOneWidget);

      // Re-tapping the already-selected segment reopens the picker.
      await tester.tap(find.byKey(const Key('client-home-tab-more')));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsIdentifier('offer_status_info_sheet'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('offer-status-close')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('client-home-filter-clear')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('client-home-filter-clear')), findsNothing);
      expect(find.text('More'), findsOneWidget);
      handle.dispose();
    });
  });

  group('D8 — the filter segments fit a 320dp screen', () {
    testWidgets('"Pending" and "Replies" render in full at 320dp', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = InMemoryClientHomeRepository.fromSnapshot(
        ClientHomeSnapshot(pending: [_pending()]),
        latency: Duration.zero,
      );
      await tester.pumpWidget(
        _screen(repo, initialTab: ClientHomeTab.pendingRequests),
      );
      await tester.pumpAndSettle();

      // The segment box minus its label is 2x the horizontal inset: 8 each
      // side once the narrow-viewport rule fires, 18 at the roomy default.
      // (Widget-test fonts have square metrics, so an "is it ellipsized"
      // assertion here would measure the harness, not the layout.)
      final segment = find.byKey(const Key('client-home-tab-pendingRequests'));
      expect(
        tester.getSize(segment).width -
            tester.getSize(find.text('Pending')).width,
        closeTo(16, 0.5),
        reason: '320dp must take the tight segment inset',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a roomy viewport keeps the default segment inset', (
      tester,
    ) async {
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        ClientHomeSnapshot(pending: [_pending()]),
        latency: Duration.zero,
      );
      await tester.pumpWidget(
        _screen(repo, initialTab: ClientHomeTab.pendingRequests),
      );
      await tester.pumpAndSettle();

      final segment = find.byKey(const Key('client-home-tab-pendingRequests'));
      expect(
        tester.getSize(segment).width -
            tester.getSize(find.text('Pending')).width,
        closeTo(36, 0.5),
      );
    });
  });

  group('D4 — the empty body clears the pinned create capsule', () {
    testWidgets('at rest on a 411x914dp viewport, unscrolled', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1080 / 411;
      addTearDown(tester.view.reset);

      final repo = InMemoryClientHomeRepository.fromSnapshot(
        const ClientHomeSnapshot(),
        latency: Duration.zero,
      );
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _screen(repo, initialTab: ClientHomeTab.pendingRequests),
      );
      await tester.pumpAndSettle();

      final body = find.text(
        'No pending requests — say it, and offers from nearby Jeebers arrive '
        'in minutes.',
      );
      expect(body, findsOneWidget);
      final capsule = find.bySemanticsIdentifier(
        'orders_create_request_button',
      );
      expect(capsule, findsOneWidget);

      expect(
        tester.getRect(body).bottom,
        lessThanOrEqualTo(tester.getRect(capsule).top),
        reason: 'the empty-state body must not sit under the pinned capsule',
      );
      handle.dispose();
    });
  });

  group('O10 — the loading frame greets by name', () {
    testWidgets('the resolved profile name shows during load', (tester) async {
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        const ClientHomeSnapshot(),
        latency: const Duration(seconds: 5),
      );
      await tester.pumpWidget(_screen(repo));
      await tester.pump();

      expect(find.text('Hello, Layla'), findsOneWidget);
      expect(find.text('Welcome back'), findsNothing);

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });
  });
}
