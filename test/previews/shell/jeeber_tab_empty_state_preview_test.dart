// Render tests for the JeeberTabEmptyState previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. See `test/previews/preview_test_harness.dart`.
//
// Pinning content is awkward for this widget on purpose: the two production
// states render IDENTICAL copy — one become-a-jeeber funnel, two tabs — so
// `expectedText` alone cannot tell them apart. Each default-copy state
// therefore pins a different one of the three ARB strings, and the real
// discriminators (screen-level Semantics id, icon, baked width) are asserted
// below. Without that second half a suite would happily pass with all five
// previews wired to the same function.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/shell/widgets/jeeber_tab_empty_state.dart';

import '../preview_test_harness.dart';

/// The longest English string the previews render, kept verbatim from
/// `lib/l10n/app_en.arb` so a copy edit fails here rather than drifting.
const String _resubmitBody =
    'We need you to update part of your submission and send it again. '
    'Fix the items below, then resubmit.';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'JeeberTabEmptyState',
    const <String, Widget Function()>{
      'Dashboard tab · non-jeeber': jeeberTabEmptyStateDashboard,
      'Earnings tab · non-jeeber': jeeberTabEmptyStateEarnings,
      'Compact 320pt phone': jeeberTabEmptyStateCompactPhone,
      'KYC resubmit copy': jeeberTabEmptyStateKycResubmit,
      'KYC pending · short body': jeeberTabEmptyStateKycPendingShortBody,
    },
    expectedText: const <String, String>{
      // The three default-copy states share one ARB triple, so each pins a
      // different member of it: title, subtitle, CTA.
      'Dashboard tab · non-jeeber': 'Become a Jeeber',
      'Earnings tab · non-jeeber': 'Earn money delivering with Jeeb',
      // The CTA is the child the compact state clips at 200% text, so pinning
      // it here is not arbitrary — if the button ever stops rendering, this is
      // the assertion that notices.
      'Compact 320pt phone': 'Start now',
      // The two override states carry copy of their own and are genuinely
      // distinguishable by text.
      'KYC resubmit copy': _resubmitBody,
      'KYC pending · short body': 'Submission received',
    },
  );

  group('JeeberTabEmptyState preview specifics', () {
    // The two production states are pixel-identical apart from the icon, so
    // this is the only thing that proves each preview rendered ITS OWN tab.
    // QA keys Maestro / adb ui-tree assertions off these ids to prove which
    // jeeber tab a non-jeeber landed on; one copy-pasted id would make the two
    // flows indistinguishable while looking perfect on screen.
    testWidgets('each tab preview carries its own screen id and icon', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpPreview(tester, jeeberTabEmptyStateDashboard);
      expect(
        find.bySemanticsIdentifier(JeeberTabEmptyState.dashboardIdentifier),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier(JeeberTabEmptyState.earningsIdentifier),
        findsNothing,
      );
      expect(find.byIcon(Icons.two_wheeler_outlined), findsOneWidget);

      await pumpPreview(tester, jeeberTabEmptyStateEarnings);
      expect(
        find.bySemanticsIdentifier(JeeberTabEmptyState.earningsIdentifier),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier(JeeberTabEmptyState.dashboardIdentifier),
        findsNothing,
      );
      expect(find.byIcon(Icons.payments_outlined), findsOneWidget);

      handle.dispose();
    });

    // The compact state is the only one that is genuinely narrow: the width is
    // baked into the tree, not just declared to the canvas, so the state is
    // 320pt here too rather than only in the preview tool.
    testWidgets('the compact state really is 320pt wide', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberTabEmptyStateCompactPhone);

      expect(
        tester.getSize(find.byType(JeeberTabEmptyState)).width,
        320.0,
      );
    });

    testWidgets('the production states use localized ARB copy, not literals', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberTabEmptyStateDashboard);

      expect(find.text('Become a Jeeber'), findsOneWidget);
      expect(find.text('Earn money delivering with Jeeb'), findsOneWidget);
      expect(find.text('Start now'), findsOneWidget);
    });

    testWidgets('the same state renders Arabic copy under RTL', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        jeeberTabEmptyStateDashboard,
        locale: const Locale('ar'),
      );

      expect(
        Directionality.of(tester.element(find.text('كن جِيبراً'))),
        TextDirection.rtl,
      );
      expect(find.text('ابدأ الآن'), findsOneWidget);
      // JEEB-66: no English literal may survive the locale switch.
      expect(find.text('Become a Jeeber'), findsNothing);
      expect(find.text('Start now'), findsNothing);
    });

    // The override states resolve their copy through a Builder rather than a
    // raw String precisely so the AR RTL pane of the canvas stays meaningful.
    // If someone "simplifies" that back to a literal, the canvas would show
    // English in the Arabic pane and nothing else would complain.
    testWidgets('override states localize too — no hardcoded English', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        jeeberTabEmptyStateKycPendingShortBody,
        locale: const Locale('ar'),
      );

      expect(find.text('تم استلام الطلب'), findsOneWidget);
      expect(find.text('Submission received'), findsNothing);

      await pumpPreview(
        tester,
        jeeberTabEmptyStateKycResubmit,
        locale: const Locale('ar'),
      );

      expect(find.text('أعد إرسال مستنداتك'), findsOneWidget);
      expect(find.text(_resubmitBody), findsNothing);
    });

    // The CTA routes with `GoRouter.maybeOf(context)?.goNamed(...)`, which is
    // what lets the widget be previewed at all: a preview has no router, so
    // every state must survive a tap as a no-op rather than throwing. If that
    // guard is ever tightened to `GoRouter.of`, the whole canvas dies on the
    // first click and this is what says so.
    testWidgets('the CTA is a safe no-op in every router-less state', (
      WidgetTester tester,
    ) async {
      for (final Widget Function() preview in <Widget Function()>[
        jeeberTabEmptyStateDashboard,
        jeeberTabEmptyStateEarnings,
        jeeberTabEmptyStateCompactPhone,
        jeeberTabEmptyStateKycResubmit,
        jeeberTabEmptyStateKycPendingShortBody,
      ]) {
        await pumpPreview(tester, preview);
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  });
}
