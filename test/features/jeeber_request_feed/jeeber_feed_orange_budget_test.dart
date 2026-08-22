// MIDNIGHT M6 — the jeeber feed's orange budget, read off the rendered widget.
//
// Under Midnight `colorScheme.primary` IS `#D73B00`, so every pass-1 site that
// treated it as a cool ink now paints the accent. Goldens cannot catch this
// (the comparator tolerates 5% and these are small elements), so each assertion
// below reads the painted colour from the built tree.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_midnight_palette.dart';
import 'package:jeeb_mobile/features/jeeber_home/application/availability_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/entities/availability_status.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/services/availability_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/jeeber_feed_tab_view.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/cubit/request_feed_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/cubit/request_feed_state.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_models.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_repository.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/presentation/jeeber_feed_card.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/presentation/request_card.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/presentation/request_feed_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

const _request = DeliveryRequest(
  id: 'r-1',
  pickup: RequestLocation(label: 'Hamra', latitude: 0, longitude: 0),
  dropoff: RequestLocation(label: 'Achrafieh', latitude: 0, longitude: 0),
  tier: JeeberRequestTier.standard,
  estimatedDistanceKm: 3.4,
  potentialEarnings: 8.5,
  currency: 'USD',
  expiresAt: null,
);

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.midnight(),
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const <LocalizationsDelegate<Object?>>[
    SyncAppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(body: child),
);

Future<void> _pumpCard(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    _host(
      RequestCard(
        request: _request,
        actionStatus: RequestActionStatus.idle,
        secondsRemaining: 42,
        onAccept: () {},
        onDecline: () {},
      ),
    ),
  );
  await tester.pump();
}

Color _iconInk(WidgetTester tester, IconData glyph) =>
    tester.widget<Icon>(find.byIcon(glyph)).color!;

Color _textInk(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).style!.color!;

void main() {
  group('RequestCard spends NO orange', () {
    testWidgets('both location pins are muted ink, not the accent', (
      tester,
    ) async {
      await _pumpCard(tester);

      // Two rows, two glyphs — the strongest instance of the leak in the app.
      expect(_iconInk(tester, Icons.adjust), JeebMidnight.inkMuted);
      expect(
        _iconInk(tester, Icons.location_on_outlined),
        JeebMidnight.inkMuted,
      );
      expect(_iconInk(tester, Icons.adjust), isNot(JeebMidnight.orange));
      expect(
        _iconInk(tester, Icons.location_on_outlined),
        isNot(JeebMidnight.orange),
      );
    });

    testWidgets('the earnings figure and its glyph read onSurface', (
      tester,
    ) async {
      await _pumpCard(tester);

      final ink = _textInk(tester, const Key('requestFeed.card.earnings'));
      expect(ink, JeebMidnight.ink);
      expect(ink, isNot(JeebMidnight.orange));
      // The glyph shares the figure's ink: a white number beside an orange coin
      // would still spend the budget.
      expect(_iconInk(tester, Icons.payments_outlined), JeebMidnight.ink);
    });

    testWidgets('money outranks distance — the two meta halves differ', (
      tester,
    ) async {
      await _pumpCard(tester);

      expect(
        _textInk(tester, const Key('requestFeed.card.earnings')),
        isNot(_textInk(tester, const Key('requestFeed.card.distance'))),
      );
      expect(
        _textInk(tester, const Key('requestFeed.card.distance')),
        JeebMidnight.inkMuted,
      );
    });

    testWidgets('the card paints the accent nowhere at all', (tester) async {
      await _pumpCard(tester);

      final orangeGlyphs = tester
          .widgetList<Icon>(find.byType(Icon))
          .where((icon) => icon.color == JeebMidnight.orange);
      expect(orangeGlyphs, isEmpty);

      final orangeText = tester
          .widgetList<Text>(find.byType(Text))
          .where((text) => text.style?.color == JeebMidnight.orange);
      expect(orangeText, isEmpty);
    });
  });

  // The OMDS-INTERNAL class: these widgets reference `colorScheme.primary`
  // inside the package, so no grep of this repo can see them. Both were found
  // by looking at a capture, which is why each now has an assertion.
  group('OMDS defaults do not smuggle the accent in', () {
    testWidgets('the accepted-card action pill fills periwinkle', (
      tester,
    ) async {
      // Wide: the accepted row's meta line overflows a 390dp card at this
      // label length, which is a layout question another lane owns.
      await tester.binding.setSurfaceSize(const Size(520, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _host(
          const JeeberFeedCard(
            request: DeliveryRequest(
              id: 'a-1',
              pickup: RequestLocation(label: 'Hamra', latitude: 0, longitude: 0),
              dropoff: RequestLocation(label: 'Mar M', latitude: 0, longitude: 0),
              tier: JeeberRequestTier.standard,
              estimatedDistanceKm: 1.2,
              potentialEarnings: 5,
              currency: 'USD',
              expiresAt: null,
              itemsSummary: 'Pharmacy run',
              feedStatus: JeeberFeedItemStatus.accepted,
              nextDeliveryAction: JeeberDeliveryAction.orderPicked,
            ),
          ),
        ),
      );
      await tester.pump();

      final button = tester.widget<OmdsLoadingButton>(
        find.byType(OmdsLoadingButton),
      );
      expect(button.backgroundColor, JeebMidnight.inkMuted);
      expect(button.backgroundColor, isNot(JeebMidnight.orange));
      expect(button.textColor, isNot(JeebMidnight.orange));
    });

    testWidgets('every feed pull-to-refresh indicator is periwinkle', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final feed = RequestFeedCubit(
        repository: SeededRequestFeedRepository(const <DeliveryRequest>[]),
      );
      addTearDown(feed.close);
      await tester.pumpWidget(_host(RequestFeedScreen(cubit: feed)));
      await feed.refresh();
      await tester.pump();

      final indicators = tester.widgetList<OmdsPullToRefresh>(
        find.byType(OmdsPullToRefresh),
      );
      expect(indicators, isNotEmpty);
      for (final indicator in indicators) {
        expect(indicator.color, JeebMidnight.inkMuted);
        expect(indicator.color, isNot(JeebMidnight.orange));
      }
    });
  });

  // L9: `OmdsSearchBar` inks its focused border from `colorScheme.primary`,
  // which app_theme's periwinkle `focusedBorder` cannot reach.
  testWidgets('the feed search bar focuses periwinkle, not orange', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final availability = AvailabilityCubit(
      gateway: InMemoryAvailabilityGateway(
        initial: AvailabilityStatus.initial.copyWith(
          state: AvailabilityState.online,
        ),
      ),
      tickerFactory: () => const Stream<DateTime>.empty(),
    );
    addTearDown(availability.close);
    final feed = RequestFeedCubit(
      repository: SeededRequestFeedRepository(const <DeliveryRequest>[]),
    );
    addTearDown(feed.close);
    await availability.load();

    await tester.pumpWidget(
      _host(
        MultiBlocProvider(
          providers: [
            BlocProvider<AvailabilityCubit>.value(value: availability),
            BlocProvider<RequestFeedCubit>.value(value: feed),
          ],
          child: const JeeberFeedTabView(),
        ),
      ),
    );
    await feed.refresh();
    await tester.pump();

    // The bar is a facet of the filter sheet now; the disc opens it. Timed
    // pumps, not pumpAndSettle: the availability strip animates forever.
    await tester.tap(find.bySemanticsIdentifier('jeeber_feed_filter_open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(JeeberFeedTabView.searchBarKey),
        matching: find.byType(TextField),
      ),
    );
    final ring = (field.decoration!.focusedBorder! as OutlineInputBorder)
        .borderSide
        .color;

    expect(ring, JeebMidnight.inkMuted);
    expect(ring, isNot(JeebMidnight.orange));
  });
}
