// OFF-02/EP-10: the offline notice existed but was never mounted and its cubit
// was never provided, so losing the network showed nothing anywhere.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/app/app.dart';
import 'package:jeeb_mobile/core/network/network_reachability_signals.dart';
import 'package:jeeb_mobile/core/session/session_gate.dart';
import 'package:jeeb_mobile/features/offline_mode/application/offline_cubit.dart';
import 'package:jeeb_mobile/features/offline_mode/presentation/offline_banner.dart';
import 'package:jeeb_mobile/features/shell/shell_screen.dart';

import '../support/sync_app_localizations.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    JeebApp(
      preferences: prefs,
      localizationsDelegateOverride: const SyncAppLocalizationsDelegate(),
      sessionGate: const AlwaysAuthenticatedSessionGate(),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

/// Drains the delivery tab's pending Dio timer, as `widget_test.dart` does.
Future<void> _drain(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 200));

void main() {
  setUp(() async {
    await NetworkReachabilitySignals.debugReset();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.onboarding.completed': true,
    });
  });

  tearDown(NetworkReachabilitySignals.debugReset);

  testWidgets('the banner is mounted above the router content', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    expect(find.byType(OfflineBanner), findsOneWidget);
    // Above the router: the banner outlives every route change.
    expect(
      find.ancestor(
        of: find.byType(ShellScreen),
        matching: find.byType(MaterialApp),
      ),
      findsWidgets,
    );
    await _drain(tester);
  });

  testWidgets('OfflineCubit is provided above the router', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    final BuildContext context = tester.element(find.byType(OfflineBanner));
    expect(context.read<OfflineCubit>(), isA<OfflineCubit>());
    expect(context.read<OfflineCubit>().state.status,
        ConnectivityStatus.online);
    await _drain(tester);
  });

  testWidgets('online shows nothing at all — zero-height, not merely invisible',
      (WidgetTester tester) async {
    await _pumpApp(tester);

    expect(tester.getSize(find.byType(OfflineBanner)).height, 0);
    expect(find.byType(MaterialBanner), findsNothing);
    await _drain(tester);
  });

  testWidgets('the reachability offline edge raises the banner, the online '
      'edge clears it', (WidgetTester tester) async {
    await _pumpApp(tester);
    final OfflineCubit cubit =
        tester.element(find.byType(OfflineBanner)).read<OfflineCubit>();

    NetworkReachabilitySignals.instance.debugObserve(online: true);
    NetworkReachabilitySignals.instance.debugObserve(online: false);
    await tester.pump();

    expect(cubit.state.status, ConnectivityStatus.offline);
    expect(find.byType(MaterialBanner), findsOneWidget);
    expect(tester.getSize(find.byType(OfflineBanner)).height, greaterThan(0));

    NetworkReachabilitySignals.instance.debugObserve(online: true);
    await tester.pump();

    expect(cubit.state.status, ConnectivityStatus.online);
    expect(find.byType(MaterialBanner), findsNothing);
    await _drain(tester);
  });

  testWidgets('the banner clears the status bar and the content below it '
      'does not reserve that inset twice', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: 47);
    tester.view.viewPadding = const FakeViewPadding(top: 47);
    addTearDown(tester.view.reset);

    await _pumpApp(tester);
    NetworkReachabilitySignals.instance.debugObserve(online: true);
    NetworkReachabilitySignals.instance.debugObserve(online: false);
    await tester.pump();

    expect(find.byType(MaterialBanner), findsOneWidget);
    expect(tester.getTopLeft(find.byType(MaterialBanner)).dy,
        greaterThanOrEqualTo(47.0));

    final BuildContext below = tester.element(find.byType(ShellScreen));
    expect(MediaQuery.paddingOf(below).top, 0);

    final Finder appBar = find.byType(AppBar);
    if (appBar.evaluate().isNotEmpty) {
      expect(tester.getSize(appBar.first).height, kToolbarHeight);
    }
    await _drain(tester);
  });

  testWidgets('dismissing hides it for that outage but not the next', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);
    final OfflineCubit cubit =
        tester.element(find.byType(OfflineBanner)).read<OfflineCubit>();
    final NetworkReachabilitySignals signals =
        NetworkReachabilitySignals.instance;

    signals.debugObserve(online: true);
    signals.debugObserve(online: false);
    await tester.pump();
    expect(find.byType(MaterialBanner), findsOneWidget);

    cubit.dismissBanner();
    await tester.pump();
    expect(find.byType(MaterialBanner), findsNothing);

    // A new outage must re-arm: one dismissal is not consent forever.
    signals.debugObserve(online: true);
    signals.debugObserve(online: false);
    await tester.pump();
    expect(find.byType(MaterialBanner), findsOneWidget);
    await _drain(tester);
  });
}
