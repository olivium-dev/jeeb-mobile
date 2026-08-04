// M3-25 — the row's finding, pinned.
//
// `NotificationPreferencesScreen` (settings/screens, 31 LOC) is a provider
// wrapper: it owns NO chrome. The visible surface is
// `notification_prefs/presentation/notification_prefs_screen.dart`, which is
// M3-24's row. Restyling here would paint the same screen twice, so this row
// ships zero product diff and this guard is its evidence: if a later lane adds
// a field, a scaffold or a top bar to the wrapper, the duplication is caught
// the moment it appears rather than at a visual review.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_top_bar.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/notification_preferences_screen_fixtures.dart';
import 'package:jeeb_mobile/features/notification_prefs/application/notification_prefs_cubit.dart';
import 'package:jeeb_mobile/features/notification_prefs/presentation/notification_prefs_screen.dart';
import 'package:jeeb_mobile/features/settings/presentation/screens/notification_preferences_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// Chrome the wrapper must never grow: each of these is the delegate's to own.
const List<Type> _forbiddenBetween = <Type>[
  JeebMidnightField,
  JeebTopBar,
  Scaffold,
  AppBar,
];

Widget _harness() {
  return MaterialApp(
    theme: AppTheme.midnight(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<Object?>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: const NotificationPreferencesScreen(
      repository: NotificationPreferencesScreenFakeRepository(
        prefs: notificationPreferencesScreenDefaultPrefs,
      ),
    ),
  );
}

/// The widget types mounted strictly between the wrapper and its delegate.
List<Type> _chainBetween(WidgetTester tester) {
  final chain = <Type>[];
  tester.element(find.byType(NotificationPrefsScreen)).visitAncestorElements(
    (element) {
      if (element.widget is NotificationPreferencesScreen) return false;
      chain.add(element.widget.runtimeType);
      return true;
    },
  );
  return chain;
}

void main() {
  testWidgets('the wrapper renders the real notification-prefs surface',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.byType(NotificationPrefsScreen), findsOneWidget);
  });

  testWidgets('it provides the cubit the delegate reads', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(NotificationPrefsScreen));
    expect(context.read<NotificationPrefsCubit>(), isNotNull);
  });

  testWidgets('it contributes no chrome of its own', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    final chain = _chainBetween(tester);
    // Sanity: the walk really did stop at the wrapper, not at the root.
    expect(chain, isNotEmpty);
    for (final Type forbidden in _forbiddenBetween) {
      expect(
        chain,
        isNot(contains(forbidden)),
        reason: '$forbidden between the wrapper and the delegate would double '
            "M3-24's chrome",
      );
    }
  });
}
