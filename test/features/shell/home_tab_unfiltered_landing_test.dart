// Regression guard for a defect found on a real SM-S921B, not in a test.
//
// THE DEFECT: the filter redesign merged Pending and Replies into one list and
// made `ClientHomeTab.all` the unfiltered default, but the SHELL still pinned
// `initialTab: ClientHomeTab.pendingRequests` — the pre-redesign default. Under
// the old segmented row that just preselected a chip. Under the new one a
// bucket IS an applied filter, so every cold start opened with an "Awaiting
// offers" pill, the filter disc in its active state, and a header count that
// disagreed with the list under it — a filter the user never applied.
//
// WHY HERE AND NOT client_home_screen_test.dart: that suite constructs
// ClientHomeScreen directly, so it only ever sees the screen's own (correct)
// default. Only driving the real HomeTab catches what the shell hands down.
//
// NO DevSeam override anywhere in this file, deliberately: the seam is what
// supplies `devTab`, and the defect lives in the `?? ` fallback beside it.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/dev_seam/dev_seam.dart';
import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_state.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_request.dart';
import 'package:jeeb_mobile/features/home_client/presentation/client_home_screen.dart';
import 'package:jeeb_mobile/features/shell/tabs/home_tab.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// One pending + one reply, so the filter chrome is required to render and
/// `findsNothing` below cannot pass just because the screen stayed empty.
class _PopulatedClientHomeRepository implements ClientHomeRepository {
  @override
  Future<ClientHomeSnapshot> loadSnapshot() async => ClientHomeSnapshot(
    pending: [_request('r-pending', 'ORD-PEND01')],
    replies: [_request('r-reply', 'ORD-REPL01', offerCount: 2)],
  );

  static ClientHomeRequest _request(
    String id,
    String displayId, {
    int offerCount = 0,
  }) => ClientHomeRequest(
    id: id,
    title: displayId,
    status: ClientRequestStatus.searching,
    destinationLabel: 'fixture destination',
    displayId: displayId,
    itemsSummary: 'fixture',
    offerCount: offerCount,
  );
}

GoRouter _router() => GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) =>
          Scaffold(body: HomeTab(repository: _PopulatedClientHomeRepository())),
    ),
  ],
);

Widget _app() => MaterialApp.router(
  routerConfig: _router(),
  theme: AppTheme.light(),
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    SyncAppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child!,
  ),
);

void main() {
  tearDown(() async {
    DevSeam.debugReset();
    await sl.reset();
  });

  testWidgets('the shell lands the client home UNFILTERED', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final ClientHomeScreen screen = tester.widget<ClientHomeScreen>(
      find.byType(ClientHomeScreen),
    );
    expect(
      screen.initialTab,
      ClientHomeTab.all,
      reason: 'a bucket here renders as a filter pill the user never applied',
    );
  });

  testWidgets('a populated landing shows the disc but NO applied pills', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Proves the screen really rendered, so the two findsNothing below are
    // load-bearing rather than vacuous.
    expect(find.bySemanticsIdentifier('orders_filter_open'), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('orders_filter_pill_bucket'),
      findsNothing,
      reason: 'the pill is the visible symptom the device screenshot caught',
    );
    expect(
      find.bySemanticsIdentifier('orders_filter_pill_status'),
      findsNothing,
    );
    handle.dispose();
  });
}
