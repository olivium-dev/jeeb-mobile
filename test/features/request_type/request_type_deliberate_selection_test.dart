import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/request_type/presentation/request_type_screen.dart';
import 'package:jeeb_mobile/features/tier_selection/data/tier_repository.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

void main() {
  testWidgets(
    'requires a deliberate tier tap and preserves it on back-return',
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
          CheckedState.isFalse,
          reason: '$id must not be selected on first paint',
        );
      }
      expect(_continueButton(tester).isEnabled, isFalse);

      final express = find.bySemanticsIdentifier('request_type_express_radio');
      await tester.tap(express);
      await tester.pump();

      expect(
        tester.getSemantics(express).flagsCollection.isChecked,
        CheckedState.isTrue,
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

OmdsPrimaryButton _continueButton(WidgetTester tester) => tester
    .widget<OmdsPrimaryButton>(find.byKey(const Key('request-type-continue')));

Widget _harness(GoRouter router) => MaterialApp.router(
  theme: AppTheme.light(),
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
