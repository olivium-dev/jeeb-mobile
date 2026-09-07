import 'dart:async';
// S9 live-tracking defect fix (T-S9-APP-TRACK).

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
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
      // JeebEmptyState's illustration loops ∞ (02-STUDY-NOTES M0-4):
      // `pumpAndSettle` only terminates under reduce motion.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: BlocProvider<LiveTrackingCubit>.value(
        value: cubit,
        child: const LiveTrackingScreen(deliveryId: 'req-123', useLiveMap: false),
      ),
    );

void main() {
  testWidgets(
      '404 renders the error rung with a distinct "not found" heading and an '
      'EXIT — never a Retry that cannot win', (tester) async {
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

    // MIDNIGHT error state (JeebEmptyState at `error` status), keyed for QA.
    expect(find.byType(JeebEmptyState), findsOneWidget);
    expect(
      tester
          .widget<JeebEmptyState>(find.byType(JeebEmptyState))
          .effectiveStatus,
      JeebEmptyStateStatus.error,
    );
    // The frozen key stays: `mb1` and QA both pin it.
    expect(find.byKey(const Key('live-tracking-error-state')), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('tracking_error_state'),
      findsOneWidget,
    );

    final l10n = AppLocalizations.of(
      tester.element(find.byType(JeebEmptyState)),
    );
    expect(find.text(l10n.errorNotFoundTitle), findsOneWidget);
    // Refetching a delivery that is not there cannot succeed: exit, not Retry.
    expect(
      find.bySemanticsIdentifier('tracking_error_state_exit_cta'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('tracking_error_state_retry_cta'),
      findsNothing,
    );
    expect(find.textContaining('Server error'), findsNothing);

    await cubit.close();
  });
}
