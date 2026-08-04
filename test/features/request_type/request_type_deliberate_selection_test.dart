// MIDNIGHT · R9 (doc-13 P0-3/P0-4): the picker rows are the COMPACT radio
// variant again — `checked`, not `selected` — and the board loads with the
// recommended tier already lit, so "nothing is chosen until the customer taps"
// is retired. What survives: exactly one row is ever chosen, a tap moves the
// choice, and the choice survives a back-return.
import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/features/request_type/presentation/request_type_screen.dart';
import 'package:jeeb_mobile/features/tier_selection/data/tier_repository.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

void main() {
  testWidgets(
    'loads with the recommended tier lit and preserves a tap on back-return',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/request-type',
        routes: [
          GoRoute(
            path: '/request-type',
            builder: (_, _) =>
                const RequestTypeScreen(repository: FakeTierRepository()),
          ),
          GoRoute(
            path: '/client-location',
            name: 'client-location',
            builder: (_, _) => const _ReturnScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(_harness(router));
      await tester.pumpAndSettle();

      for (final id in _tierSemanticsIds) {
        expect(
          tester
              .getSemantics(find.bySemanticsIdentifier(id))
              .flagsCollection
              .isChecked,
          id == 'request_type_standard_radio'
              ? CheckedState.isTrue
              : CheckedState.isFalse,
          reason: '$id: only the recommended tier is lit on first paint',
        );
      }
      // R9 loads ready to advance.
      expect(_continueButton(tester).isEnabled, isTrue);

      final express = find.bySemanticsIdentifier('request_type_express_radio');
      await tester.tap(express);
      await tester.pump();

      expect(
        tester.getSemantics(express).flagsCollection.isChecked,
        CheckedState.isTrue,
      );
      expect(
        tester
            .getSemantics(
              find.bySemanticsIdentifier('request_type_standard_radio'),
            )
            .flagsCollection
            .isChecked,
        CheckedState.isFalse,
      );
      expect(_continueButton(tester).isEnabled, isTrue);

      await tester.tap(find.bySemanticsIdentifier('request_type_continue_cta'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('return-to-request-type')), findsOneWidget);

      await tester.tap(find.byKey(const Key('return-to-request-type')));
      await tester.pumpAndSettle();

      expect(find.byType(RequestTypeScreen), findsOneWidget);
      expect(
        tester
            .getSemantics(
              find.bySemanticsIdentifier('request_type_express_radio'),
            )
            .flagsCollection
            .isChecked,
        CheckedState.isTrue,
      );
      expect(_continueButton(tester).isEnabled, isTrue);
    },
  );
}

const _tierSemanticsIds = [
  'request_type_flash_radio',
  'request_type_express_radio',
  'request_type_standard_radio',
  'request_type_on_the_way_radio',
  'request_type_eco_radio',
];

// The redesign swaps the footer CTA to the frozen kit's `JeebCtaButton`, which
// paints its own pill rather than composing `OmdsPrimaryButton`. The assertion
// is unchanged — `isEnabled` read off the widget behind the same frozen Key.
JeebCtaButton _continueButton(WidgetTester tester) => tester
    .widget<JeebCtaButton>(find.byKey(const Key('request-type-continue')));

Widget _harness(GoRouter router) => MaterialApp.router(
  theme: AppTheme.midnight(),
  routerConfig: router,
  localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
    SyncAppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
);

class _ReturnScreen extends StatelessWidget {
  const _ReturnScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: OmdsPrimaryButton(
          key: const Key('return-to-request-type'),
          text: 'Back',
          onTap: () => context.pop(),
        ),
      ),
    );
  }
}
