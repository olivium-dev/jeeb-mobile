import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/app/jeeb_bootstrap.dart';
import 'package:jeeb_mobile/core/dev_flags.dart';
import 'package:jeeb_mobile/core/observability/session_trace/observability_config.dart';
import 'package:jeeb_mobile/devtool/shake/devtool_shake.dart';

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
        await tester.scrollUntilVisible(
          find.text(capability),
          80,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(capability), findsOne, reason: capability);
      }
      if (kObsCompiledIn) {
        await tester.scrollUntilVisible(
          find.text('Session Logs'),
          80,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Session Logs'), findsOne);
      } else {
        expect(find.text('Session Logs'), findsNothing);
      }
      expect(find.byKey(kDevToolShakeApplyKey), findsOne);
      expect(find.byKey(kDevToolShakeCloseKey), findsOne);
      expect(find.text('Apply & Restart'), findsOne);
      expect(find.text('Jeeb Internal QA'), findsNothing);
      expect(find.text('Build and environment'), findsNothing);

      if (kObsCompiledIn) {
        await tester.tap(find.text('Session Logs'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('obs-overlay-recording-switch')), findsOne);
        expect(find.byKey(const Key('obs-overlay-export')), findsOne);
      }
      expect(find.bySemanticsLabel('Session trace overlay'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
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
  'Server URL',
  'Clear Local Data',
  'Scenario Users',
];
