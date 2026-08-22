import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/jeeber_home/application/availability_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/entities/availability_status.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/services/availability_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/jeeber_feed_tab_view.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/cubit/request_feed_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_models.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_repository.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// The narrow phone the board actually broke on (SM-S921B logical width).
const Size _sm921bViewport = Size(360, 800);

DeliveryRequest _req(String id, JeeberFeedItemStatus status) =>
    DeliveryRequest(
      id: id,
      pickup: const RequestLocation(
        label: 'Pickup',
        latitude: 33.8,
        longitude: 35.5,
      ),
      dropoff: const RequestLocation(
        label: 'Dropoff',
        latitude: 33.9,
        longitude: 35.6,
      ),
      tier: JeeberRequestTier.flash,
      estimatedDistanceKm: 1.2,
      potentialEarnings: 5.0,
      currency: 'USD',
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      feedStatus: status,
    );

Future<AppLocalizations> _pumpBoard(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = _sm921bViewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final ticker = StreamController<DateTime>.broadcast();
  addTearDown(ticker.close);
  final avCubit = AvailabilityCubit(
    gateway: InMemoryAvailabilityGateway(
      initial: AvailabilityStatus.initial.copyWith(
        state: AvailabilityState.online,
      ),
    ),
    tickerFactory: () => ticker.stream,
  );
  addTearDown(avCubit.close);
  // Two-digit counts on every tab: the widest the labels ever get.
  final feedCubit = RequestFeedCubit(
    repository: SeededRequestFeedRepository([
      for (var i = 0; i < 12; i += 1)
        _req('incoming-$i', JeeberFeedItemStatus.incoming),
      for (var i = 0; i < 11; i += 1)
        _req('pending-$i', JeeberFeedItemStatus.pendingResponse),
      for (var i = 0; i < 10; i += 1)
        _req('accepted-$i', JeeberFeedItemStatus.accepted),
    ]),
  );
  addTearDown(feedCubit.close);
  await avCubit.load();

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
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
      home: Scaffold(
        body: MultiBlocProvider(
          providers: [
            BlocProvider<AvailabilityCubit>.value(value: avCubit),
            BlocProvider<RequestFeedCubit>.value(value: feedCubit),
          ],
          child: const JeeberFeedTabView(),
        ),
      ),
    ),
  );
  await tester.pump();
  await feedCubit.refresh();
  await tester.pumpAndSettle();

  return AppLocalizations.of(tester.element(find.byType(JeeberFeedTabView)));
}

List<String> _stageLabels(AppLocalizations l10n) => [
  l10n.jeeberFeedNearbyCount(12),
  l10n.jeeberFeedPendingCount(11),
  l10n.jeeberFeedRepliesCount(10),
];

void main() {
  group('Jeeber board stage strip', () {
    testWidgets('renders all three labels in full at 360dp — no truncation', (
      tester,
    ) async {
      final l10n = await _pumpBoard(tester);

      expect(tester.takeException(), isNull);
      for (final label in _stageLabels(l10n)) {
        final text = find.text(label);
        expect(text, findsOneWidget, reason: '"$label" must be on the board');
        final paragraph = tester.renderObject<RenderParagraph>(text);
        expect(
          paragraph.didExceedMaxLines,
          isFalse,
          reason: '"$label" is ellipsized — the chip clipped it',
        );
      }
    });

    testWidgets('the strip fits its row without scrolling', (tester) async {
      await _pumpBoard(tester);

      final strip = find.byKey(JeeberFeedTabView.tabStripKey);
      expect(strip, findsOneWidget);
      expect(
        find.descendant(of: strip, matching: find.byType(Scrollable)),
        findsNothing,
        reason: 'a scroller parks the third stage tab off-screen',
      );

      // 360dp minus the two Spacing.xLarge gutters, the filter disc and its gap.
      expect(tester.getSize(strip).width, lessThanOrEqualTo(360 - 2 * 24));
    });

    testWidgets('Arabic keeps every label whole too', (tester) async {
      final l10n = await _pumpBoard(tester, locale: const Locale('ar'));

      expect(tester.takeException(), isNull);
      for (final label in _stageLabels(l10n)) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(label),
        );
        expect(paragraph.didExceedMaxLines, isFalse, reason: label);
      }
    });
  });
}
