// Render tests for the JeeberTabEmptyState previews.

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
      'Dashboard tab · non-jeeber': 'Become a Jeeber',
      'Earnings tab · non-jeeber': 'Earn money delivering with Jeeb',
      // The CTA is the child the compact state clips at 200% text, so pinning
      'Compact 320pt phone': 'Start now',
      // The two override states carry copy of their own and are genuinely
      'KYC resubmit copy': _resubmitBody,
      'KYC pending · short body': 'Submission received',
    },
  );

  group('JeeberTabEmptyState preview specifics', () {
    // The two production states are pixel-identical apart from the icon, so
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
