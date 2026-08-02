// Render tests for the JeeberUnregisteredView previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. See `test/previews/preview_test_harness.dart`.
//
// The greeting line is the only copy that differs between these five states —
// headline, subtitle and CTA are identical in all of them — so it is what
// `expectedText` pins. That is the whole point of pinning: a suite that only
// asked "did something render?" would pass with all five previews wired to the
// same function.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/jeeber_unregistered_view.dart';
import 'package:jeeb_mobile/previews/jeeber_home/jeeber_unregistered_view_preview.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'JeeberUnregisteredView',
    const <String, Widget Function()>{
      'Cold start · no name': jeeberUnregisteredViewColdStart,
      'Named jeeber': jeeberUnregisteredViewNamed,
      'JM-036 gate CTA id': jeeberUnregisteredViewGateCta,
      'Long name · 320pt phone': jeeberUnregisteredViewLongNameCompact,
      'Short body (420pt)': jeeberUnregisteredViewShortBody,
    },
    expectedText: const <String, String>{
      'Cold start · no name': 'Welcome back',
      'Named jeeber': 'Hello, Kamal',
      'JM-036 gate CTA id': 'Hello, Zeina',
      'Long name · 320pt phone': 'Hello, Abdulrahman',
      'Short body (420pt)': 'Hello, Nour',
    },
  );

  group('JeeberUnregisteredView preview specifics', () {
    testWidgets('every state carries the localized upsell copy, not literals', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberUnregisteredViewNamed);

      expect(find.text('Register as a delivery man'), findsOneWidget);
      expect(find.text('Start earning money'), findsOneWidget);
      expect(find.text('Register now'), findsOneWidget);
    });

    testWidgets('the same state renders Arabic copy under RTL', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        jeeberUnregisteredViewNamed,
        locale: const Locale('ar'),
      );

      expect(
        Directionality.of(
          tester.element(find.text('سجّل كموصِّل')),
        ),
        TextDirection.rtl,
      );
      expect(find.text('سجّل الآن'), findsOneWidget);
      // JEEB-66: no English literal may survive the locale switch.
      expect(find.text('Register as a delivery man'), findsNothing);
      expect(find.text('Register now'), findsNothing);
    });

    // CAP-3, from the preview side. The gate preview passes the JM-036
    // identifier, which wraps the CTA in a SECOND Semantics node. If the root's
    // `explicitChildNodes: true` ever regresses, the outer node merges the
    // subtree and the W0 `jeeber_unregistered_register_button` id disappears —
    // exactly the swallow 8b81dc1 fixed. Both flows tap this one button by
    // different ids, so both must stay addressable.
    testWidgets('gate preview keeps BOTH CTA identifiers queryable', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, jeeberUnregisteredViewGateCta);

      expect(
        find.bySemanticsIdentifier('jeeber_unregistered_root'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('delivery_register_now_cta'),
        findsOneWidget,
        reason: 'The JM-036 gate flow taps the CTA by its coined screen id.',
      );
      expect(
        find.bySemanticsIdentifier('jeeber_unregistered_register_button'),
        findsOneWidget,
        reason: 'Maestro flow 19 taps the same CTA by the W0 widget id; the '
            'extra JM-036 wrapper must not swallow it.',
      );

      handle.dispose();
    });

    // The non-gate previews are how `JeeberHomeScreen` builds the view (no
    // ctaIdentifier). The coined id must NOT leak into them, or the JM-036
    // flow's "gate branch is showing" assertion would pass on the plain
    // screen-19 surface too.
    testWidgets('non-gate previews carry only the W0 CTA id', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, jeeberUnregisteredViewNamed);

      expect(
        find.bySemanticsIdentifier('jeeber_unregistered_register_button'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('delivery_register_now_cta'),
        findsNothing,
      );

      handle.dispose();
    });

    testWidgets('the CTA is wired in every state', (WidgetTester tester) async {
      for (final Widget Function() preview in <Widget Function()>[
        jeeberUnregisteredViewColdStart,
        jeeberUnregisteredViewNamed,
        jeeberUnregisteredViewGateCta,
        jeeberUnregisteredViewLongNameCompact,
        jeeberUnregisteredViewShortBody,
      ]) {
        await pumpPreview(tester, preview);
        await tester.tap(
          find.byKey(JeeberUnregisteredView.registerButtonKey),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });

    // The long-name state is the only one that is genuinely narrow: the width
    // is baked into the tree, not just declared to the canvas, so the state is
    // compact in this suite too rather than only in the preview tool.
    testWidgets('the compact state really is 320pt wide', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberUnregisteredViewLongNameCompact);

      expect(
        tester.getSize(find.byKey(JeeberUnregisteredView.rootKey)).width,
        320.0,
      );
    });

    // Greeting the first name only is what keeps this state readable at 320pt;
    // the full three-part name would be truncated mid-word.
    testWidgets('greets the first name only, even at 320pt', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberUnregisteredViewLongNameCompact);

      expect(find.text('Hello, Abdulrahman'), findsOneWidget);
      expect(find.textContaining('Trabulsi'), findsNothing);
    });
  });
}
