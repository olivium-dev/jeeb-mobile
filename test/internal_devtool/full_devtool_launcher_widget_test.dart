import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/app/jeeb_bootstrap.dart';
import 'package:jeeb_mobile/core/dev_flags.dart';
import 'package:jeeb_mobile/devtool/shake/devtool_shake.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../support/sync_app_localizations.dart';

void main() {
  test(
    'exact launcher route selects one pending full-Dev-Tool open',
    () {
      final devToolRoot = buildJeebRootForInitialRoute('/devtool') as JeebRoot;
      final productRoot = buildJeebRootForInitialRoute('/') as JeebRoot;

      expect(devToolRoot.devToolInitiallyPending, isTrue);
      expect(productRoot.devToolInitiallyPending, isFalse);
    },
    skip: !kDevToolEnabled,
  );

  testWidgets(
    'internal launcher displays the complete original Dev Tool menu',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            SyncAppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: DevToolShakeHost(
            initiallyOpen: true,
            shakeEnabled: false,
            child: SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Jeeber Dev Tool'), findsOne);
      for (final capability in _fullDevToolCapabilities) {
        if (find.text(capability).evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            find.text(capability),
            250,
            scrollable: find.byType(Scrollable).last,
          );
        }
        expect(find.text(capability), findsOne, reason: capability);
      }
      expect(find.byKey(kDevToolShakeApplyKey), findsOne);
      expect(find.byKey(kDevToolShakeCloseKey), findsOne);
      expect(find.text('Apply & Restart'), findsOne);
      expect(find.text('Jeeb Internal QA'), findsNothing);
      expect(find.text('Build and environment'), findsNothing);
    },
    skip: !kDevToolEnabled,
  );
}

const _fullDevToolCapabilities = <String>[
  'Gesture Logging',
  'Super Login',
  'Screen Catalog',
  'Actions',
  'Location Simulator',
  'Fund Jeeber wallet',
  'Server URL',
  'Clear Local Data',
  'Scenario Users',
];
