import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/jeeber_home/application/availability_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/availability_inactivity_policy.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/services/availability_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/jeeber_home_screen.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/availability_status_block.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/availability_toggle.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/inactivity_warning_banner.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/jeeber_unregistered_view.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'support/sync_app_localizations.dart';

Widget _host(AvailabilityCubit cubit) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: BlocProvider<AvailabilityCubit>.value(
      value: cubit,
      child: const JeeberHomeScreen(),
    ),
  );
}

void main() {
  testWidgets('cold-start renders the offline toggle and the status block',
      (tester) async {
    final ticker = StreamController<DateTime>.broadcast();
    addTearDown(ticker.close);
    final cubit = AvailabilityCubit(
      gateway: InMemoryAvailabilityGateway(),
      tickerFactory: () => ticker.stream,
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(_host(cubit));
    await tester.pumpAndSettle();

    expect(find.byKey(AvailabilityToggle.rootKey), findsOneWidget);
    expect(find.byKey(AvailabilityStatusBlock.rootKey), findsOneWidget);
    // Active-delivery line only renders when online.
    expect(find.byKey(AvailabilityStatusBlock.activeDeliveriesKey),
        findsNothing);
  });

  testWidgets('tap on the toggle goes online and surfaces the deliveries line',
      (tester) async {
    final gateway = InMemoryAvailabilityGateway()
      ..setActiveDeliveryCount(2);
    final ticker = StreamController<DateTime>.broadcast();
    addTearDown(ticker.close);
    final cubit = AvailabilityCubit(
      gateway: gateway,
      tickerFactory: () => ticker.stream,
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(_host(cubit));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AvailabilityToggle.rootKey));
    await tester.pumpAndSettle();

    expect(cubit.state.status.isOnline, isTrue);
    expect(find.byKey(AvailabilityStatusBlock.activeDeliveriesKey),
        findsOneWidget);
    expect(find.text('2 active deliveries'), findsOneWidget);
  });

  testWidgets('toggle error surfaces a snackbar', (tester) async {
    final gateway = InMemoryAvailabilityGateway()..respondWithError = false;
    final ticker = StreamController<DateTime>.broadcast();
    addTearDown(ticker.close);
    final cubit = AvailabilityCubit(
      gateway: gateway,
      tickerFactory: () => ticker.stream,
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(_host(cubit));
    await tester.pumpAndSettle();

    // Cold-start fetch succeeded; flip the gateway into error mode and
    // tap the toggle to drive the failure path.
    gateway.setError(true);
    await tester.tap(find.byKey(AvailabilityToggle.rootKey));
    await tester.pump(); // let the snackbar enqueue
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(JeeberHomeScreen.toggleErrorSnackbarKey), findsOneWidget);
  });

  testWidgets('cold-start error surfaces the retry view', (tester) async {
    final ticker = StreamController<DateTime>.broadcast();
    addTearDown(ticker.close);
    final cubit = AvailabilityCubit(
      gateway: InMemoryAvailabilityGateway(respondWithError: true),
      tickerFactory: () => ticker.stream,
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(_host(cubit));
    await tester.pumpAndSettle();

    expect(find.byKey(JeeberHomeScreen.loadErrorRetryKey), findsOneWidget);
  });

  testWidgets('inactivity ticker raises the warning banner and CTA clears it',
      (tester) async {
    final ticker = StreamController<DateTime>.broadcast();
    addTearDown(ticker.close);
    // Zero-threshold policy: the first tick after going online raises the
    // warning, so we don't need a fake clock that runs 7h30 forward.
    const policy = AvailabilityInactivityPolicy(
      warnAfter: Duration.zero,
      autoOfflineAfter: Duration(days: 365),
    );
    final cubit = AvailabilityCubit(
      gateway: InMemoryAvailabilityGateway(),
      policy: policy,
      tickerFactory: () => ticker.stream,
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(_host(cubit));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AvailabilityToggle.rootKey));
    await tester.pumpAndSettle();
    expect(cubit.state.status.isOnline, isTrue);

    ticker.add(DateTime.now().add(const Duration(minutes: 1)));
    await tester.pumpAndSettle();

    expect(find.byKey(InactivityWarningBanner.rootKey), findsOneWidget);

    await tester.tap(find.byKey(InactivityWarningBanner.ctaKey));
    await tester.pumpAndSettle();
    expect(cubit.state.warningVisible, isFalse);
    expect(find.byKey(InactivityWarningBanner.rootKey), findsNothing);
  });

  // Screen-19 crash regression. The unregistered home-tab seam path mounts
  // `JeeberHomeScreen(isRegistered: false)` with NO `BlocProvider<
  // AvailabilityCubit>` ancestor (the upsell view never reads the cubit). On
  // the pre-fix source `didChangeDependencies` called
  // `context.read<AvailabilityCubit>()` unconditionally and threw
  // `ProviderNotFound<AvailabilityCubit>` before the first frame painted, so
  // the upsell never rendered. (Verified: throws pre-fix → renders post-fix.)
  testWidgets(
      'unregistered path mounts without an AvailabilityCubit and renders the '
      'upsell root (screen 19)', (tester) async {
    await tester.pumpWidget(_unregisteredHost());
    await tester.pump();

    // No exception was thrown bringing the screen up.
    expect(tester.takeException(), isNull);
    // The unregistered upsell root actually rendered.
    expect(find.byKey(JeeberUnregisteredView.rootKey), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('jeeber_unregistered_root'),
      findsOneWidget,
      reason: 'The unregistered upsell screen must mount and surface its '
          'root identifier without an AvailabilityCubit provider.',
    );
    // Sanity: the registered-only retry view is absent.
    expect(find.byKey(JeeberHomeScreen.loadErrorRetryKey), findsNothing);
  });
}

/// Hosts `JeeberHomeScreen` on the UNREGISTERED path with NO availability
/// cubit provider — exactly the `DashboardTab` `jeeb.home_tab=unregistered`
/// seam condition that crashed before the didChangeDependencies guard.
Widget _unregisteredHost() {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: const JeeberHomeScreen(isRegistered: false, profileName: 'Kamal'),
  );
}
