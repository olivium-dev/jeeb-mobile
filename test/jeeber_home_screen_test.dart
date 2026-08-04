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
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/availability_card.dart';
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
    // E3's illustration loops ∞ (02-STUDY-NOTES M0-4): `pumpAndSettle` only
    // terminates under reduce motion, which is also the capture rest frame.
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: BlocProvider<AvailabilityCubit>.value(
      value: cubit,
      child: const JeeberHomeScreen(),
    ),
  );
}

void main() {
  testWidgets('cold-start renders the offline availability card and switch', (
    tester,
  ) async {
    final ticker = StreamController<DateTime>.broadcast();
    addTearDown(ticker.close);
    final cubit = AvailabilityCubit(
      gateway: InMemoryAvailabilityGateway(),
      tickerFactory: () => ticker.stream,
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(_host(cubit));
    await tester.pumpAndSettle();

    expect(find.byKey(AvailabilityCard.toggleKey), findsOneWidget);
    expect(find.bySemanticsIdentifier('availability_card'), findsOneWidget);
    expect(find.bySemanticsIdentifier('availability_switch'), findsOneWidget);
    expect(find.text("You're offline"), findsOneWidget);
    // The simplified dashboard deliberately removed the legacy supporting
    expect(find.byKey(AvailabilityStatusBlock.rootKey), findsNothing);
    expect(
      find.byKey(AvailabilityStatusBlock.activeDeliveriesKey),
      findsNothing,
    );
  });

  testWidgets('tap on the toggle goes online and renders the compact switch', (
    tester,
  ) async {
    final gateway = InMemoryAvailabilityGateway()..setActiveDeliveryCount(2);
    final ticker = StreamController<DateTime>.broadcast();
    addTearDown(ticker.close);
    final cubit = AvailabilityCubit(
      gateway: gateway,
      tickerFactory: () => ticker.stream,
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(_host(cubit));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AvailabilityCard.toggleKey));
    await tester.pumpAndSettle();

    expect(cubit.state.status.isOnline, isTrue);
    expect(cubit.state.status.activeDeliveryCount, 2);
    expect(find.bySemanticsIdentifier('availability_switch'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    // WP-B intentionally collapsed the settled online card to a two-line
    expect(
      find.byKey(AvailabilityStatusBlock.activeDeliveriesKey),
      findsNothing,
    );
    expect(find.text('2 active deliveries'), findsNothing);
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
    gateway.setError(true);
    await tester.tap(find.byKey(AvailabilityCard.toggleKey));
    await tester.pump(); // let the snackbar enqueue
    await tester.pump(const Duration(milliseconds: 50));

    // Targeted by the snackbar's localized content rather than a Key, so the
    final l10n = AppLocalizations.of(
      tester.element(find.byType(JeeberHomeScreen)),
    );
    expect(
      find.widgetWithText(SnackBar, l10n.availabilityToggleErrorBody),
      findsOneWidget,
    );
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

  testWidgets('inactivity ticker raises the warning banner and CTA clears it', (
    tester,
  ) async {
    final ticker = StreamController<DateTime>.broadcast();
    addTearDown(ticker.close);
    // Zero-threshold policy: the first tick after going online raises the
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

    await tester.tap(find.byKey(AvailabilityCard.toggleKey));
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
  testWidgets(
    'unregistered path mounts without an AvailabilityCubit and renders the '
    'upsell root (screen 19)',
    (tester) async {
      await tester.pumpWidget(_unregisteredHost());
      await tester.pump();

      // No exception was thrown bringing the screen up.
      expect(tester.takeException(), isNull);
      // The unregistered upsell root actually rendered.
      expect(find.byKey(JeeberUnregisteredView.rootKey), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('jeeber_unregistered_root'),
        findsOneWidget,
        reason:
            'The unregistered upsell screen must mount and surface its '
            'root identifier without an AvailabilityCubit provider.',
      );
      // Sanity: the registered-only retry view is absent.
      expect(find.byKey(JeeberHomeScreen.loadErrorRetryKey), findsNothing);
    },
  );

  // JM-036: the DELIVERY-tab gate passes `registerCtaIdentifier:
  testWidgets(
    'register prompt exposes delivery_register_now_cta alongside the W0 id '
    'and forwards the tap (JM-036)',
    (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _unregisteredHost(
          registerCtaIdentifier: 'delivery_register_now_cta',
          onRegister: () => tapped = true,
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      // W0 widget id preserved (screen-19 flow).
      expect(
        find.bySemanticsIdentifier('jeeber_unregistered_register_button'),
        findsOneWidget,
        reason:
            'The W0 register-button id must remain queryable for screen-19.',
      );
      // JM-036 coined CTA id surfaces as its own node.
      expect(
        find.bySemanticsIdentifier('delivery_register_now_cta'),
        findsOneWidget,
        reason:
            'The JM-036 coined register-now CTA id must surface for the '
            'delivery-tab-gate flow.',
      );
      // Tapping the coined CTA forwards to onRegister (→ onboarding wizard).
      await tester.tap(find.byKey(JeeberUnregisteredView.registerButtonKey));
      await tester.pump();
      expect(tapped, isTrue);
    },
  );
}

/// Hosts `JeeberHomeScreen` on the UNREGISTERED path with NO availability
/// cubit provider — exactly the `DashboardTab` `jeeb.home_tab=unregistered`
Widget _unregisteredHost({
  String? registerCtaIdentifier,
  VoidCallback? onRegister,
}) {
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
    // E3's illustration loops ∞ (02-STUDY-NOTES M0-4): `pumpAndSettle` only
    // terminates under reduce motion, which is also the capture rest frame.
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: JeeberHomeScreen(
      isRegistered: false,
      profileName: 'Kamal',
      registerCtaIdentifier: registerCtaIdentifier,
      onRegister: onRegister,
    ),
  );
}
