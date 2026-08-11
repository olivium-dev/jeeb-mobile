// Render tests for the LogoutDeleteConfirmSheet previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/settings/domain/account_deletion_policy.dart';
import 'package:jeeb_mobile/features/settings/presentation/widgets/logout_delete_confirm_sheet.dart';

import '../preview_test_harness.dart';

/// The three CTAs the JM-062 AC names by id.
const List<String> _confirmIds = <String>[
  'logout_confirm_cta',
  'delete_confirm_cta',
];
const String _cancelId = 'logout_delete_cancel_cta';

/// The delete body, verbatim from `lib/l10n/app_en.arb` — the longest copy this
/// widget lays out and the E20 (JEBV4-215) purge contract in prose.
const String _deleteBody =
    'Your account will be deactivated now and permanently deleted after '
    '$kAccountPurgeGraceDays days. Any active orders must be completed first. '
    'Sign in again before then to cancel and keep your account.';

void main() {
  setUpAll(loadPreviewArbs);

  // Every preview except `Clearing session` — see the dedicated group below.
  testPreviewsRender(
    'LogoutDeleteConfirmSheet',
    const <String, Widget Function()>{
      'Sign out': logoutDeleteConfirmSheetLogout,
      'Delete account': logoutDeleteConfirmSheetDelete,
      'Sign out + delete': logoutDeleteConfirmSheetBoth,
      'Narrow phone · 320 pt': logoutDeleteConfirmSheetNarrowPhone,
    },
    expectedText: const <String, String>{
      // The sign-out title — a question about a pending act, and the string the
      'Sign out': 'Sign out of Jeeb?',
      // Pinned whole: if the grace window drifts from the gateway purge-worker
      'Delete account': _deleteBody,
      // `both` is the only 390 pt state carrying the delete CTA under the
      'Sign out + delete': 'Delete account',
      // The sign-out body, which delete mode replaces wholesale.
      'Narrow phone · 320 pt':
          "You'll need to sign in again to place or accept deliveries.",
    },
  );

  // `_inFlight` swaps every CTA label for `OmdsButtonLoading`, i.e. an
  group('LogoutDeleteConfirmSheet previews · Clearing session', () {
    Future<void> pumpInFlight(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(
        previewCanvas(logoutDeleteConfirmSheetInFlight, locale),
      );
      await tester.pump(); // localizations resolve → the sheet is built
      await tester.pump(); // the post-frame confirm tap latches _inFlight
      await tester.pump(const Duration(milliseconds: 300)); // switcher settles
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Clearing session · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpInFlight(tester, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Clearing session renders its own state', (
      WidgetTester tester,
    ) async {
      await pumpInFlight(tester);

      // Still the sign-out sheet (`both` mode keeps the sign-out title)…
      expect(find.text('Sign out of Jeeb?'), findsOneWidget);
      // …but BOTH confirm labels have been replaced by spinners. That triple is
      expect(find.text('Sign out'), findsNothing);
      expect(find.text('Delete account'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
    });

    testWidgets(
        'the sheet spins the CTA the user did NOT choose '
        '(_confirmCta shares isLoading)', (WidgetTester tester) async {
      await pumpInFlight(tester);

      // The preview fires `logout-confirm-cta` only, yet `_confirmCta` passes
      expect(
        find.descendant(
          of: find.byKey(const Key('delete-confirm-cta')),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
    });

    testWidgets('every CTA is inert while the session clear is in flight', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpInFlight(tester);

      // A live tap target here is how a user double-fires the clear, or tears
      for (final String id in <String>[..._confirmIds, _cancelId]) {
        expect(
          tester.getSemantics(find.bySemanticsIdentifier(id)),
          isSemantics(identifier: id, isButton: true, hasTapAction: false),
          reason: '$id must be inert while the clear is in flight',
        );
      }
      handle.dispose();
    });
  });

  group('LogoutDeleteConfirmSheet preview specifics', () {
    testWidgets('Sign out offers ONLY the reversible action', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, logoutDeleteConfirmSheetLogout);

      expect(find.bySemanticsIdentifier('logout_confirm_cta'), findsOneWidget);
      // NEGATIVE control: the irreversible action must not be reachable from
      expect(find.bySemanticsIdentifier('delete_confirm_cta'), findsNothing);
      expect(find.text('Delete account'), findsNothing);
      expect(find.textContaining('permanently deleted'), findsNothing);
    });

    testWidgets('Delete account states the E20 purge SLA and its reversal', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, logoutDeleteConfirmSheetDelete);

      // The number the user is told must be the one the gateway purge worker
      expect(find.textContaining('$kAccountPurgeGraceDays days'), findsOneWidget);
      expect(find.textContaining('Sign in again'), findsOneWidget);
      // Delete mode is delete-only: no sign-out escape hatch on this sheet.
      expect(find.bySemanticsIdentifier('logout_confirm_cta'), findsNothing);
      expect(find.text('Sign out of Jeeb?'), findsNothing);
    });

    testWidgets('Sign out + delete surfaces both terminal actions at once', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, logoutDeleteConfirmSheetBoth);

      for (final String id in _confirmIds) {
        expect(find.bySemanticsIdentifier(id), findsOneWidget, reason: id);
      }
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.text('Delete account'), findsOneWidget);
      // …under the SIGN-OUT title and body. The delete warning is nowhere on
      expect(find.text('Sign out of Jeeb?'), findsOneWidget);
      expect(find.textContaining('permanently deleted'), findsNothing);
    });

    // The guard against every preview in this file rendering at one width: the
    testWidgets('Narrow phone pins 320 pt, the 390 pt states pin 390', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, logoutDeleteConfirmSheetNarrowPhone);
      expect(
        tester.getSize(find.byType(LogoutDeleteConfirmSheet)).width,
        320,
      );
    });

    for (final MapEntry<String, Widget Function()> entry
        in <String, Widget Function()>{
      'Sign out': logoutDeleteConfirmSheetLogout,
      'Delete account': logoutDeleteConfirmSheetDelete,
      'Sign out + delete': logoutDeleteConfirmSheetBoth,
    }.entries) {
      testWidgets('${entry.key} renders at phone width, idle', (
        WidgetTester tester,
      ) async {
        await pumpPreview(tester, entry.value);

        expect(
          tester.getSize(find.byType(LogoutDeleteConfirmSheet)).width,
          390,
        );
        // Idle: no clear in flight, so the labels are on screen and the cancel
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('Cancel'), findsOneWidget);
      });
    }
  });
}
