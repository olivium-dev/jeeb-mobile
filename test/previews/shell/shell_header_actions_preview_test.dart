// Render tests for the ShellHeaderActions previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. See `test/previews/preview_test_harness.dart`.
//
// ShellHeaderActions renders no text of its own, so `expectedText` pins each
// preview's caption — the one string that differs per state. Without that, a
// suite of five identical icon pairs would pass even if every preview built the
// same composition. The specifics group below pins the half that is actually
// the widget's own contract: the `idPrefix` scoping of its Semantics ids.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/previews/shell/shell_header_actions_preview.dart';

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
      'Actions only': 'Actions only · 96 × 48 dp',
      'Requests tab': 'Requests tab · orders_home',
      'Requests tab · narrow + long name': 'Requests tab · long name at 320 dp',
      'Jeeber dashboard': 'Jeeber dashboard · delivery_tab',
      'Profile tab': 'Profile tab · customer_profile',
    },
  );

  group('ShellHeaderActions preview specifics', () {
    /// The `idPrefix` contract: one shared widget, per-screen ids, so the two
    /// headers never emit duplicate Semantics identifiers. Asserting BOTH the
    /// presence of this host's ids and the absence of the other host's is what
    /// distinguishes a real per-screen scope from a hardcoded prefix.
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
      // hosts (`ClientHomeGreeting`, `CustomerProfileHeader`) carry trailing
      // buttons of their own. A preview that accidentally painted the actions
      // twice — or a host that grew its own copy — would still look plausible
      // in the canvas, so count them.
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

    testWidgets('the labels are localized, not hardcoded English', (
      WidgetTester tester,
    ) async {
      // Both affordances are icon-only, so their ARB labels
      // (`shellWalletChipLabel` / `shellBellLabel`) are the ONLY thing a screen
      // reader has to go on. If either ever regressed to a literal, the Arabic
      // rendering of every preview above would quietly announce English.
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
