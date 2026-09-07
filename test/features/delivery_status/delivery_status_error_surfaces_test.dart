// UX-26 — the no-gateway shell is a failure block, and a refused cancel is a
// snack the user can actually read. Neither had an identifier assertion.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jeeb_mobile/features/delivery_status/application/delivery_status_cubit.dart';
import 'package:jeeb_mobile/features/delivery_status/domain/delivery_address.dart';
import 'package:jeeb_mobile/features/delivery_status/domain/delivery_snapshot.dart';
import 'package:jeeb_mobile/features/delivery_status/domain/delivery_stage.dart';
import 'package:jeeb_mobile/features/delivery_status/domain/delivery_status_gateway.dart';
import 'package:jeeb_mobile/features/delivery_status/domain/delivery_tier.dart';
import 'package:jeeb_mobile/features/delivery_status/domain/jeeber_summary.dart';
import 'package:jeeb_mobile/features/delivery_status/presentation/delivery_status_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

DeliverySnapshot _snapshot() => DeliverySnapshot(
      id: 'd-1',
      stage: DeliveryStage.matched,
      lifecycle: DeliveryLifecycle.active,
      stageTimestamps: <DeliveryStage, DateTime>{
        DeliveryStage.matched: DateTime(2026, 5, 17, 10),
      },
      pickup: const DeliveryAddress(label: 'Hamra'),
      dropoff: const DeliveryAddress(label: 'Verdun'),
      tier: DeliveryTier.scooter,
      jeeber: const JeeberSummary(
        displayName: 'Karim H.',
        vehicleLabel: 'Scooter',
        phoneE164: '+96171000000',
        rating: 4.8,
      ),
    );

Widget _harness(Widget screen, Locale locale) {
  final GoRouter router = GoRouter(
    initialLocation: '/status',
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('home'))),
      GoRoute(path: '/status', builder: (_, _) => screen),
    ],
  );
  addTearDown(router.dispose);
  return MaterialApp.router(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<Object?>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    routerConfig: router,
  );
}

void main() {
  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String tag = locale.languageCode;

    testWidgets('[$tag] a refused cancel surfaces delivery_status_action_error',
        (WidgetTester tester) async {
      useReduceMotion(tester);
      await tester.pumpWidget(
        _harness(
          DeliveryStatusScreen(
            deliveryId: 'd-1',
            gateway: InMemoryDeliveryStatusGateway(
              seed: _snapshot(),
              cancelOutcome: CancellationOutcome.networkError,
            ),
          ),
          locale,
        ),
      );
      await tester.pump();

      // The CTA is behind a confirmation dialog and `contact` outranks it in
      // the footer, so the act is driven on the cubit the screen owns.
      final DeliveryStatusCubit cubit = BlocProvider.of<DeliveryStatusCubit>(
        tester.element(find.bySemanticsIdentifier('delivery_status_root')),
      );
      await cubit.cancel();
      await tester.pump();
      await tester.pump();

      expect(
        find.bySemanticsIdentifier('delivery_status_action_error'),
        findsOneWidget,
      );
    });

    testWidgets('[$tag] the no-gateway shell is a failure block with an exit',
        (WidgetTester tester) async {
      useReduceMotion(tester);
      await tester.pumpWidget(
        _harness(const DeliveryStatusScreen(deliveryId: 'd-1'), locale),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('delivery_status_error'),
        findsOneWidget,
      );
      // R6: never a block with no act at all.
      expect(
        find.bySemanticsIdentifier('delivery_status_exit_cta'),
        findsOneWidget,
      );

      await tester.tap(
        find.bySemanticsIdentifier('delivery_status_exit_cta'),
      );
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });
  }
}
