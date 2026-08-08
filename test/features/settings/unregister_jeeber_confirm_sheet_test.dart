// F3 — Unregister-as-Jeeber confirm ceremony.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/settings/application/settings_cubit.dart';
import 'package:jeeb_mobile/features/settings/application/settings_state.dart';
import 'package:jeeb_mobile/features/settings/domain/jeeber_unregister_service.dart';
import 'package:jeeb_mobile/features/settings/presentation/widgets/unregister_jeeber_confirm_sheet.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/settings_fakes.dart';
import '../../support/sync_app_localizations.dart';

Widget _harness(Widget child) {
  return MaterialApp(
    theme: ThemeData.light(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: child),
  );
}

SettingsCubit _cubit(FakeJeeberUnregisterService service) {
  return SettingsCubit(
    profileRepository: InMemoryProfileRepository(),
    accountService: const FakeAccountService(),
    jeeberUnregisterService: service,
  );
}

void main() {
  testWidgets('confirm calls the cubit exactly once and completes on '
      'success', (tester) async {
    final service = FakeJeeberUnregisterService();
    final cubit = _cubit(service);
    addTearDown(cubit.close);
    var completed = 0;

    await tester.pumpWidget(_harness(UnregisterJeeberConfirmSheet(
      cubit: cubit,
      onCompleted: () => completed++,
    )));
    await tester.pump();

    await tester.tap(find.bySemanticsIdentifier('unregister_jeeber_confirm_cta'));
    await tester.pump(); // in-flight
    await tester.pump(); // resolves

    expect(service.calls, 1);
    expect(completed, 1);
    expect(cubit.state.banner, SettingsBanner.jeeberUnregistered);
  });

  testWidgets('a 502-mapped outcome still completes (closes the sheet) — '
      'the honest message is the settings screen banner, not this sheet',
      (tester) async {
    final service =
        FakeJeeberUnregisterService(outcome: JeeberUnregisterOutcome.unavailable);
    final cubit = _cubit(service);
    addTearDown(cubit.close);
    var completed = 0;

    await tester.pumpWidget(_harness(UnregisterJeeberConfirmSheet(
      cubit: cubit,
      onCompleted: () => completed++,
    )));
    await tester.pump();

    await tester.tap(find.bySemanticsIdentifier('unregister_jeeber_confirm_cta'));
    await tester.pump();
    await tester.pump();

    expect(completed, 1);
    expect(cubit.state.banner, SettingsBanner.jeeberUnregisterUnavailable);
    expect(cubit.state.jeeberUnregistered, isFalse);
  });

  testWidgets('cancel never calls the cubit', (tester) async {
    final service = FakeJeeberUnregisterService();
    final cubit = _cubit(service);
    addTearDown(cubit.close);
    var cancelled = 0;
    var completed = 0;

    await tester.pumpWidget(_harness(UnregisterJeeberConfirmSheet(
      cubit: cubit,
      onCompleted: () => completed++,
      onCancelled: () => cancelled++,
    )));
    await tester.pump();

    await tester.tap(find.bySemanticsIdentifier('unregister_jeeber_cancel_cta'));
    await tester.pump();

    expect(service.calls, 0);
    expect(cancelled, 1);
    expect(completed, 0);
  });
}
