// MIDNIGHT E3 (`29-e3-empty-no-requests-nearby.png`) adoption pin.
//
// Every no-requests surface on the jeeber home draws the kit's `street`
// variant — the night street with the breathing streetlamp and the listening
// box. `balcony` was the M2-12 stand-in and draws a request bubble plus a
// `jDash` route E3 does not have; this file fails if any mount drifts back.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/features/jeeber_home/application/availability_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_home/application/availability_state.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/entities/availability_status.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/services/availability_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/jeeber_home_screen.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/jeeber_feed_tab_view.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/jeeber_no_requests_view.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/cubit/request_feed_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_models.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_repository.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// Never settles, so the screen stays on its cold-read `loading` branch.
class _HangingAvailabilityGateway implements AvailabilityGateway {
  @override
  Future<AvailabilityStatus> fetch() => Completer<AvailabilityStatus>().future;

  @override
  Future<AvailabilityStatus> toggle({required bool goOnline}) =>
      Completer<AvailabilityStatus>().future;
}

Widget _app(Widget home, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    // The illustration loops ∞ (02-STUDY-NOTES M0-4): `pumpAndSettle` only
    // terminates under reduce motion, which is also the capture rest frame.
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: home,
  );
}

Widget _boxed(Widget child, {Locale locale = const Locale('en')}) =>
    _app(Scaffold(body: child), locale: locale);

AvailabilityCubit _cubit(
  AvailabilityGateway gateway,
  StreamController<DateTime> ticker,
) => AvailabilityCubit(gateway: gateway, tickerFactory: () => ticker.stream);

/// Asserts every mounted empty state on the surface is E3's night street.
void _expectStreet(WidgetTester tester) {
  final mounted = tester
      .widgetList<JeebEmptyState>(find.byType(JeebEmptyState))
      .toList();
  expect(mounted, isNotEmpty, reason: 'no JeebEmptyState mounted');
  for (final state in mounted) {
    expect(
      state.variant,
      JeebEmptyStateVariant.street,
      reason:
          'E3 draws the night street; ${state.identifier ?? 'this mount'} '
          'is on ${state.variant.name}',
    );
  }
}

void main() {
  group('E3 · street variant adoption', () {
    testWidgets('the shared no-requests block draws street', (tester) async {
      await tester.pumpWidget(
        _boxed(const JeeberFeedEmptyBlock(onRefresh: null)),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(JeeberFeedEmptyBlock.rootKey), findsOneWidget);
      _expectStreet(tester);
    });

    testWidgets('the block keeps street under RTL', (tester) async {
      await tester.pumpWidget(
        _boxed(
          JeeberFeedEmptyBlock(onRefresh: () {}),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        Directionality.of(tester.element(find.byType(JeebEmptyState))),
        TextDirection.rtl,
      );
      _expectStreet(tester);
    });

    testWidgets('JeeberNoRequestsView mounts the street block', (tester) async {
      final ticker = StreamController<DateTime>.broadcast();
      addTearDown(ticker.close);
      final cubit = _cubit(InMemoryAvailabilityGateway(), ticker);
      addTearDown(cubit.close);
      await cubit.load();

      await tester.pumpWidget(
        _boxed(
          BlocBuilder<AvailabilityCubit, AvailabilityViewState>(
            bloc: cubit,
            builder: (context, state) => JeeberNoRequestsView(
              view: state,
              onToggle: () {},
              onExtendActivity: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(JeeberNoRequestsView.rootKey), findsOneWidget);
      _expectStreet(tester);
    });

    testWidgets('the offline feed empty body draws street', (tester) async {
      final ticker = StreamController<DateTime>.broadcast();
      addTearDown(ticker.close);
      final avCubit = _cubit(InMemoryAvailabilityGateway(), ticker);
      addTearDown(avCubit.close);
      final feedCubit = RequestFeedCubit(
        repository: SeededRequestFeedRepository(const <DeliveryRequest>[]),
      );
      addTearDown(feedCubit.close);
      await avCubit.load();

      await tester.pumpWidget(
        _boxed(
          MultiBlocProvider(
            providers: [
              BlocProvider<AvailabilityCubit>.value(value: avCubit),
              BlocProvider<RequestFeedCubit>.value(value: feedCubit),
            ],
            child: const JeeberFeedTabView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(avCubit.state.status.isOnline, isFalse);
      _expectStreet(tester);
    });

    testWidgets('the cold-read loading view draws street', (tester) async {
      final ticker = StreamController<DateTime>.broadcast();
      addTearDown(ticker.close);
      final cubit = _cubit(_HangingAvailabilityGateway(), ticker);
      addTearDown(cubit.close);
      unawaited(cubit.load());

      await tester.pumpWidget(
        _app(
          BlocProvider<AvailabilityCubit>.value(
            value: cubit,
            child: const JeeberHomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      _expectStreet(tester);
    });

    testWidgets('the cold-read error view draws street', (tester) async {
      final ticker = StreamController<DateTime>.broadcast();
      addTearDown(ticker.close);
      final cubit = _cubit(
        InMemoryAvailabilityGateway(respondWithError: true),
        ticker,
      );
      addTearDown(cubit.close);

      await tester.pumpWidget(
        _app(
          BlocProvider<AvailabilityCubit>.value(
            value: cubit,
            child: const JeeberHomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(JeeberHomeScreen.loadErrorRetryKey), findsOneWidget);
      _expectStreet(tester);
    });
  });
}
