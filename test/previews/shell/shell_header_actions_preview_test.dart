// Render tests for the ShellHeaderActions previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/shell/widgets/shell_header_actions.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'ShellHeaderActions',
    const <String, Widget Function()>{
      'Actions only': shellHeaderActionsBareRow,
      'Requests tab': shellHeaderActionsRequestsTab,
      'Requests tab · narrow + long name':
          shellHeaderActionsRequestsNarrowLongName,
      'Jeeber dashboard': shellHeaderActionsJeeberDashboard,
      'Profile tab': shellHeaderActionsProfileTab,
    },
    expectedText: const <String, String>{
      'Actions only': 'Actions only · 2 × Ø44',
      'Requests tab': 'Requests tab · orders_home',
      'Requests tab · narrow + long name': 'Requests tab · long name at 320 dp',
      'Jeeber dashboard': 'Jeeber dashboard · delivery_tab',
      'Profile tab': 'Profile tab · customer_profile',
    },
  );

  group('ShellHeaderActions preview specifics', () {
    /// The `idPrefix` contract: one shared widget, per-screen ids, so the two
    /// headers never emit duplicate Semantics identifiers. Asserting BOTH the
    Future<void> expectScopedIds(
      WidgetTester tester,
      Widget Function() preview, {
      required String present,
      required String absent,
    }) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, preview);

      expect(find.bySemanticsIdentifier('${present}_wallet_chip'),
          findsOneWidget);
      expect(find.bySemanticsIdentifier('${present}_bell'), findsOneWidget);
      expect(find.bySemanticsIdentifier('${absent}_wallet_chip'), findsNothing);
      expect(find.bySemanticsIdentifier('${absent}_bell'), findsNothing);

      handle.dispose();
    }

    testWidgets('Requests tab scopes its ids to orders_home', (
      WidgetTester tester,
    ) async {
      await expectScopedIds(
        tester,
        shellHeaderActionsRequestsTab,
        present: 'orders_home',
        absent: 'customer_profile',
      );
    });

    testWidgets('Profile tab scopes its ids to customer_profile', (
      WidgetTester tester,
    ) async {
      await expectScopedIds(
        tester,
        shellHeaderActionsProfileTab,
        present: 'customer_profile',
        absent: 'orders_home',
      );
    });

    testWidgets('Jeeber dashboard scopes its ids to delivery_tab', (
      WidgetTester tester,
    ) async {
      await expectScopedIds(
        tester,
        shellHeaderActionsJeeberDashboard,
        present: 'delivery_tab',
        absent: 'orders_home',
      );
    });

    testWidgets('every state renders exactly one wallet chip and one bell', (
      WidgetTester tester,
    ) async {
      // The overlay is stacked on top of a real host header, and two of those
      for (final Widget Function() preview in <Widget Function()>[
        shellHeaderActionsBareRow,
        shellHeaderActionsRequestsTab,
        shellHeaderActionsRequestsNarrowLongName,
        shellHeaderActionsJeeberDashboard,
        shellHeaderActionsProfileTab,
      ]) {
        await pumpPreview(tester, preview);
        expect(find.byIcon(Icons.account_balance_wallet_outlined),
            findsOneWidget);
        expect(find.byIcon(Icons.notifications_none_outlined), findsOneWidget);
      }
    });

    testWidgets('the actions center on the greeting avatar line', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, shellHeaderActionsRequestsTab);

      expect(
        tester
            .getCenter(
              find.bySemanticsIdentifier('orders_home_wallet_chip'),
            )
            .dy,
        closeTo(
          tester
              .getCenter(find.byKey(const Key('client-home-greeting-avatar')))
              .dy,
          1,
        ),
      );
      handle.dispose();
    });

    testWidgets('both actions are opaque blur-free glass circles', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, shellHeaderActionsRequestsTab);

      final actions = find.byType(ShellHeaderActions);
      final materials = tester.widgetList<Material>(
        find.descendant(of: actions, matching: find.byType(Material)),
      ).where((material) => material.shape != null);
      expect(materials, hasLength(2));
      for (final material in materials) {
        expect(material.shape, isA<CircleBorder>());
        expect(material.color?.a, 1);
      }
      expect(
        find.descendant(of: actions, matching: find.byType(BackdropFilter)),
        findsNothing,
      );
    });

    testWidgets('the labels are localized, not hardcoded English', (
      WidgetTester tester,
    ) async {
      // Both affordances are icon-only, so their ARB labels
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(
        tester,
        shellHeaderActionsRequestsTab,
        locale: const Locale('ar'),
      );

      expect(
        tester
            .getSemantics(find.bySemanticsIdentifier('orders_home_wallet_chip'))
            .label,
        'المحفظة',
      );
      expect(
        tester.getSemantics(find.bySemanticsIdentifier('orders_home_bell'))
            .label,
        'الإشعارات',
      );

      handle.dispose();
    });
  });
}
