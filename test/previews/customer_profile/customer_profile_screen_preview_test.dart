// Render tests for the CustomerProfileScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// Two of the six states — the cold start and the failed cold read — render the
// SAME pixels by design (see the preview section: the screen never looks at
// `state.error`), so `expectedText` alone cannot tell them apart. The
// `preview specifics` group carries that weight instead: it pins each card on
// its cubit's status and typed failure, which is the only thing that actually
// differs. If that ever stops being true, the screen grew an error affordance
// and these tests should be rewritten around it.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/customer_profile/application/customer_profile_cubit.dart';
import 'package:jeeb_mobile/features/customer_profile/application/customer_profile_state.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_repository.dart';
import 'package:jeeb_mobile/features/customer_profile/presentation/customer_profile_screen.dart';
import 'package:jeeb_mobile/features/customer_profile/presentation/widgets/customer_profile_row.dart';

import '../preview_test_harness.dart';

/// The state of the cubit the previewed screen built for itself.
///
/// `CustomerProfileScreen` owns its `BlocProvider`, so this is the only way to
/// observe which lifecycle a card is parked in — and for the two empty states
/// it is the ONLY difference between them.
CustomerProfileState _state(WidgetTester tester) => tester
    .element(find.byKey(CustomerProfileScreen.rootKey))
    .read<CustomerProfileCubit>()
    .state;

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'CustomerProfileScreen',
    const <String, Widget Function()>{
      'Client · verified + rated': customerProfileScreenClient,
      'Jeeber · register row hidden': customerProfileScreenJeeber,
      'Cold start · getMe in flight': customerProfileScreenColdStart,
      'Failed read · network, empty seed': customerProfileScreenFailedColdRead,
      'Stale after 401 · route extra':
          customerProfileScreenStaleAfterUnauthorized,
      'Longest content · compact 320': customerProfileScreenLongestContent,
    },
    expectedText: const <String, String>{
      // Each populated state is pinned on its own account holder — the rows are
      // identical in every state, so the header copy is the only discriminator.
      'Client · verified + rated': 'Sami Fawaz',
      'Jeeber · register row hidden': 'Kamal Hajj',
      'Stale after 401 · route extra': 'Nadia Client',
      'Longest content · compact 320': 'Abdulrahman Al-Muhandis Al-Trabulsi',
      // The two empty states have no header copy to be pinned on. These strings
      // are distinct but weak on purpose; the specifics below do the real work.
      'Cold start · getMe in flight': 'No reviews yet',
      'Failed read · network, empty seed': 'Register as a delivery',
    },
  );

  group('CustomerProfileScreen preview specifics', () {
    testWidgets('the client card carries all 8 rows and a rated header', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, customerProfileScreenClient);

      expect(find.byType(CustomerProfileRow), findsNWidgets(8));
      expect(find.text('kamalhaaj@gmail.com'), findsOneWidget);
      expect(find.text('No reviews yet'), findsNothing);
      expect(
        find.bySemanticsIdentifier('customer_profile_register_delivery_row'),
        findsOneWidget,
      );
      // Shell-owned ids must NOT be painted by the screen (duplicate-id guard).
      expect(
        find.bySemanticsIdentifier('customer_profile_wallet_chip'),
        findsNothing,
      );
      handle.dispose();
    });

    testWidgets('the jeeber card drops the register row entirely (JM-035 AC2)',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, customerProfileScreenJeeber);

      expect(find.byType(CustomerProfileRow), findsNWidgets(7));
      expect(find.text('Register as a delivery'), findsNothing);
      expect(
        find.bySemanticsIdentifier('customer_profile_register_delivery_row'),
        findsNothing,
      );
      // Unrated, so the chip keeps its id and swaps to the cold-start copy.
      expect(find.text('No reviews yet'), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('customer_profile_rating'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('the compact preview really is 320 pt wide under test', (
      WidgetTester tester,
    ) async {
      // The render harness pumps an 800 pt surface. If the width were left to
      // the canvas `size:`, this state would lay out at 800 pt here and stop
      // being a compact-device state at all.
      await pumpPreview(tester, customerProfileScreenLongestContent);
      expect(tester.getSize(find.byType(CustomerProfileScreen)).width, 320.0);

      await pumpPreview(tester, customerProfileScreenClient);
      expect(tester.getSize(find.byType(CustomerProfileScreen)).width, 390.0);
    });

    testWidgets('the long name wraps instead of ellipsizing, growing the header',
        (WidgetTester tester) async {
      // `_NameText` passes no `maxLines`, so the ceiling state costs vertical
      // space that the account rows below it pay for.
      await pumpPreview(tester, customerProfileScreenLongestContent);
      final double tall =
          tester.getSize(find.text('Abdulrahman Al-Muhandis Al-Trabulsi'))
              .height;

      await pumpPreview(tester, customerProfileScreenClient);
      final double short = tester.getSize(find.text('Sami Fawaz')).height;

      expect(tall, greaterThan(short * 2));
    });

    testWidgets('cold start is still loading and carries no failure', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, customerProfileScreenColdStart);

      final CustomerProfileState state = _state(tester);
      expect(state.status, CustomerProfileStatus.loading);
      expect(state.error, isNull);
      // Nothing is known about the user yet, and nothing says so.
      expect(find.text('No reviews yet'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // Every row is painted and tappable while the read is in flight.
      expect(find.byType(CustomerProfileRow), findsNWidgets(8));
    });

    testWidgets(
        'DEFECT: the failed cold read is indistinguishable from the loading one',
        (WidgetTester tester) async {
      // Pinned, not desired. `_Body` reads `state.data` and nothing else, so a
      // network failure paints exactly the frame the tab opened with — no
      // banner, no message, no retry. DELETE this test when the screen grows an
      // error affordance (it will start failing, which is the point).
      await pumpPreview(tester, customerProfileScreenColdStart);
      final List<String> loadingCopy = tester
          .widgetList<Text>(find.byType(Text))
          .map((Text t) => t.data ?? '')
          .toList();

      await pumpPreview(tester, customerProfileScreenFailedColdRead);
      final List<String> failedCopy = tester
          .widgetList<Text>(find.byType(Text))
          .map((Text t) => t.data ?? '')
          .toList();

      expect(failedCopy, loadingCopy);

      // The failure IS recorded — it just has no renderer and no retry.
      final CustomerProfileState state = _state(tester);
      expect(state.status, CustomerProfileStatus.loaded);
      expect(state.error, CustomerProfileFailure.network);
    });

    testWidgets('DEFECT: a 401 leaves the seeded profile on screen unmarked', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, customerProfileScreenStaleAfterUnauthorized);

      final CustomerProfileState state = _state(tester);
      expect(state.error, CustomerProfileFailure.unauthorized);
      // The session is gone and the previous read model is still rendered in
      // full, with nothing marking it as stale.
      expect(find.text('Nadia Client'), findsOneWidget);
      expect(find.text('nadia.client@jeeb.dev'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsNothing);
      expect(find.textContaining('again'), findsNothing);
    });
  });
}
