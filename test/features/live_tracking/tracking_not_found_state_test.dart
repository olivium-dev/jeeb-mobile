import 'dart:async';
// S9 live-tracking defect fix (T-S9-APP-TRACK).
//
// PROVES a genuine 404 ("Delivery not found") renders a distinct OMDS
// error/empty state with a retry — NOT a crash and NOT the generic
// "Server error" the live defect showed.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_cubit.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/live_tracking_repository.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/live_tracking_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _MockRepo extends Mock implements LiveTrackingRepository {}

Widget _harness(LiveTrackingCubit cubit) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: BlocProvider<LiveTrackingCubit>.value(
        value: cubit,
        child: const LiveTrackingScreen(deliveryId: 'req-123', useLiveMap: false),
      ),
    );

void main() {
  testWidgets(
      '404 renders the OMDS error state with a distinct "Delivery not found" '
      'heading and a retry — no crash, no "Server error"', (tester) async {
    final repo = _MockRepo();
    when(() => repo.fetchDeliveryStatus(deliveryId: any(named: 'deliveryId')))
        .thenThrow(const LiveTrackingException(LiveTrackingErrorKind.notFound));
    final cubit = LiveTrackingCubit(
      repository: repo,
      deliveryId: 'req-123',
      refreshSignals: const Stream<void>.empty(),
    );

    await tester.pumpWidget(_harness(cubit));
    await tester.pumpAndSettle();

    // OMDS error state (not raw Material), keyed for QA targeting.
    expect(find.byType(OmdsErrorState), findsOneWidget);
    expect(find.byKey(const Key('live-tracking-error-state')), findsOneWidget);
    expect(find.text('Delivery not found'), findsOneWidget);
    // Retry affordance present; generic "Server error" absent.
    expect(find.text('Refresh now'), findsOneWidget);
    expect(find.textContaining('Server error'), findsNothing);

    await cubit.close();
  });
}
