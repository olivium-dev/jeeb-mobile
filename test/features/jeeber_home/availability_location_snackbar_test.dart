// D2 availability cost: a jeeber whose go-online carried no coordinates is
// dropped from new-request fan-out. The drop used to be silent; these pins
// hold the user-visible surface that replaced it.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/jeeber_home/application/availability_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/entities/availability_status.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/services/availability_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/jeeber_home_screen.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/availability_card.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// Goes online exactly as the live gateway does when the GPS fix never lands.
class _NoFixAvailabilityGateway implements AvailabilityGateway {
  _NoFixAvailabilityGateway(this.outcome);

  final GoOnlineLocationOutcome outcome;
  int refreshCalls = 0;

  @override
  Future<AvailabilityStatus> fetch() async => AvailabilityStatus.initial;

  @override
  Future<AvailabilityToggleResult> toggle({required bool goOnline}) async =>
      AvailabilityToggleResult(
        status: AvailabilityStatus(
          state: goOnline ? AvailabilityState.online : AvailabilityState.offline,
          activeDeliveryCount: 0,
          lastActivityAt: DateTime(2026, 8, 11),
        ),
        location: goOnline ? outcome : GoOnlineLocationOutcome.notApplicable,
      );

  @override
  Future<GoOnlineLocationOutcome> refreshLocation() async {
    refreshCalls++;
    return GoOnlineLocationOutcome.attached;
  }
}

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

Future<AvailabilityCubit> _goOnline(
  WidgetTester tester,
  _NoFixAvailabilityGateway gateway,
) async {
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
  return cubit;
}

void main() {
  testWidgets('a failed fix warns the jeeber and offers a retry', (
    tester,
  ) async {
    final gateway =
        _NoFixAvailabilityGateway(GoOnlineLocationOutcome.fixFailed);

    final cubit = await _goOnline(tester, gateway);

    expect(cubit.state.status.isOnline, isTrue);
    expect(
      find.text(
        "We couldn't get your location. Nearby requests may not reach you.",
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(SnackBarAction, 'Retry'));
    await tester.pumpAndSettle();

    expect(gateway.refreshCalls, 1);
    expect(cubit.state.locationOutcome, GoOnlineLocationOutcome.attached);
  });

  testWidgets('a denied permission routes to Settings, not to a retry', (
    tester,
  ) async {
    final gateway =
        _NoFixAvailabilityGateway(GoOnlineLocationOutcome.permissionDenied);

    await _goOnline(tester, gateway);

    expect(
      find.text('Location permission is off. Nearby requests may not reach you.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(SnackBarAction, 'Settings'), findsOneWidget);
    expect(find.widgetWithText(SnackBarAction, 'Retry'), findsNothing);
  });

  testWidgets('an attached fix stays silent', (tester) async {
    final gateway = _NoFixAvailabilityGateway(GoOnlineLocationOutcome.attached);

    await _goOnline(tester, gateway);

    expect(find.byType(SnackBarAction), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });
}
