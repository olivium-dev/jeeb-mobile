import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_omds_tokens.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_display_clock.dart';
import 'package:jeeb_mobile/features/home_client/presentation/widgets/client_home_greeting.dart';
import 'package:jeeb_mobile/features/home_client/presentation/widgets/client_home_request_hero.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:omds/omds.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

enum _Period { morning, afternoon, evening }

(String, String) _copy(AppLocalizations l10n, _Period period) =>
    switch (period) {
      _Period.morning => (
        l10n.homeGreetingEyebrowMorning,
        l10n.homeHeroPromptMorning,
      ),
      _Period.afternoon => (
        l10n.homeGreetingEyebrowAfternoon,
        l10n.homeHeroPromptAfternoon,
      ),
      _Period.evening => (
        l10n.homeGreetingEyebrowEvening,
        l10n.homeHeroPromptEvening,
      ),
    };

_Period _devicePeriod(DateTime time) => time.hour < 12
    ? _Period.morning
    : time.hour < 17
    ? _Period.afternoon
    : _Period.evening;

Widget _copies({Key? key}) => Column(
  key: key,
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: const [
    ClientHomeGreeting(name: null),
    ClientHomeRequestHero(showCapsule: false),
  ],
);

Widget _harness(Locale locale, Widget child) => OmdsColorTokensProvider(
  tokens: jeebMidnightOmdsTokens,
  child: MaterialApp(
    theme: AppTheme.midnight(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void _expectCopy(WidgetTester tester, Finder scope, _Period period) {
  final expected = _copy(AppLocalizations.of(tester.element(scope)), period);
  expect(
    find.descendant(of: scope, matching: find.text(expected.$1)),
    findsOneWidget,
  );
  expect(
    find.descendant(of: scope, matching: find.text(expected.$2)),
    findsOneWidget,
  );
}

void main() {
  test('the default display clock reads current device time', () {
    final clock = ClientHomeDisplayClock();
    final before = DateTime.now();
    final actual = clock.now();
    final after = DateTime.now();
    expect(actual.isBefore(before), isFalse);
    expect(actual.isAfter(after), isFalse);
    expect(actual.isUtc, isFalse);
  });

  for (final language in ['en', 'ar']) {
    final locale = Locale(language);
    for (final boundary in [
      (0, 0, _Period.morning),
      (11, 59, _Period.morning),
      (12, 0, _Period.afternoon),
      (16, 59, _Period.afternoon),
      (17, 0, _Period.evening),
      (23, 59, _Period.evening),
    ]) {
      testWidgets('$language both widgets agree at $boundary', (tester) async {
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        useReduceMotion(tester);
        const key = ValueKey('clock-copy');
        await tester.pumpWidget(
          RepositoryProvider<ClientHomeDisplayClock>.value(
            value: ClientHomeDisplayClock(
              now: () => DateTime(2026, 9, 7, boundary.$1, boundary.$2),
            ),
            child: _harness(locale, _copies(key: key)),
          ),
        );
        await tester.pumpAndSettle();
        _expectCopy(tester, find.byKey(key), boundary.$3);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('$language clocks stay within their provider scopes', (
      tester,
    ) async {
      useReduceMotion(tester);
      const morning = ValueKey('morning-copy');
      const evening = ValueKey('evening-copy');
      await tester.pumpWidget(
        _harness(
          locale,
          Column(
            children: [
              RepositoryProvider<ClientHomeDisplayClock>.value(
                value: ClientHomeDisplayClock(
                  now: () => DateTime(2026, 9, 7, 8),
                ),
                child: _copies(key: morning),
              ),
              RepositoryProvider<ClientHomeDisplayClock>.value(
                value: ClientHomeDisplayClock(
                  now: () => DateTime(2026, 9, 7, 18),
                ),
                child: _copies(key: evening),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      _expectCopy(tester, find.byKey(morning), _Period.morning);
      _expectCopy(tester, find.byKey(evening), _Period.evening);
      expect(tester.takeException(), isNull);

      const device = ValueKey('device-copy');
      final before = DateTime.now();
      await tester.pumpWidget(_harness(locale, _copies(key: device)));
      await tester.pumpAndSettle();
      final after = DateTime.now();
      final l10n = AppLocalizations.of(tester.element(find.byKey(device)));
      final allowed = {_devicePeriod(before), _devicePeriod(after)};
      final greetings = allowed.map((period) => _copy(l10n, period).$1).toSet();
      final prompts = allowed.map((period) => _copy(l10n, period).$2).toSet();
      expect(
        find.descendant(
          of: find.byType(ClientHomeGreeting),
          matching: find.byWidgetPredicate(
            (widget) => widget is Text && greetings.contains(widget.data),
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(ClientHomeRequestHero),
          matching: find.byWidgetPredicate(
            (widget) => widget is Text && prompts.contains(widget.data),
          ),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
