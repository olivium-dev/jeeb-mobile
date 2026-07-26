// Widget tests for NotificationsListScreen (JM-057). Proves:
//   - the EXACT Semantics identifiers render off an injected repository
//     (notifications_root, typed notif_row_<id>) — 30_BACKLOG JM-057;
//   - the 4-state machine (loading → failed → loaded/empty, §3);
//   - mark-read flips the row's unread badge on tap;
//   - the D84 per-row deep-link DISPATCH lands on the right route
//     (tab kinds → shell; chat/wallet/kyc-rejected/waiting/receipt → their
//     routes; unknown/missing-ref → stays on the inbox).
//
// A minimal GoRouter with stub destination screens (each carrying a *_root id)
// backs the dispatch assertions, since context.goNamed needs a router.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/user_role.dart';
import 'package:jeeb_mobile/features/notifications/domain/notifications_repository.dart';
import 'package:jeeb_mobile/features/notifications/presentation/notifications_list_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:omds/omds.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/sync_app_localizations.dart';

class _ScriptedRepository implements NotificationsRepository {
  _ScriptedRepository(this._items, {this.fetchThrows});

  final List<NotificationItem> _items;
  final NotificationsFailure? fetchThrows;
  final List<String> markedRead = <String>[];

  @override
  Future<List<NotificationItem>> fetchNotifications() async {
    final f = fetchThrows;
    if (f != null) throw NotificationsRepositoryException(f);
    return _items;
  }

  @override
  Future<void> markRead(String id) async => markedRead.add(id);
}

NotificationItem _item(
  String id,
  NotificationKind kind, {
  String? ref,
  bool read = false,
}) => NotificationItem(
  id: id,
  kind: kind,
  title: 'title-$id',
  body: 'body-$id',
  timestamp: '2026-06-18T10:00:00Z',
  read: read,
  ref: ref,
);

// A tiny stub screen exposing a root id so the dispatch test can assert landing.
Widget _stub(String id) => Semantics(
  identifier: id,
  container: true,
  child: const Scaffold(body: SizedBox.expand()),
);

Widget _harness(
  NotificationsRepository repo,
  RoleCubit role, {
  Locale locale = const Locale('en'),
}) {
  final router = GoRouter(
    initialLocation: '/notifications',
    routes: [
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (_, _) => NotificationsListScreen(repository: repo),
      ),
      GoRoute(path: '/', name: 'shell', builder: (_, _) => _stub('shell_root')),
      GoRoute(
        path: '/wallet',
        name: 'wallet',
        builder: (_, _) => _stub('wallet_hub_root'),
      ),
      GoRoute(
        path: '/chat/:id',
        name: 'chat-detail',
        builder: (_, s) => _stub('order_chat_root_${s.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/kyc/rejected',
        name: 'kyc-rejected',
        builder: (_, _) => _stub('kyc_rejected_root'),
      ),
      GoRoute(
        path: '/requests/:id/waiting',
        name: 'waiting-no-coverage',
        builder: (_, s) =>
            _stub('waiting_no_coverage_root_${s.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/orders/:id/receipt',
        name: 'delivered-receipt',
        builder: (_, s) =>
            _stub('delivered_receipt_root_${s.pathParameters['id']}'),
      ),
      // G3: the new_request row routes through deepLinkForMessage — the SAME
      // resolver the push tap uses — which returns /jeeber/requests/:id.
      GoRoute(
        path: '/jeeber/requests/:id',
        name: 'jeeber-request-detail',
        builder: (_, s) =>
            _stub('jeeber_request_root_${s.pathParameters['id']}'),
      ),
      // P2/F4: the `offer` row now lands on the offer-review list, via the
      // SAME resolver the push tap uses (`/requests/:id/offers`).
      //
      // The stub id is `offer_review_list_root`, the REAL production signature
      // id (`client_offers_screen.dart:122`), not an invented one — a grep for
      // it leads to the product rather than to a test fiction. Registered
      // ONCE: two GoRoutes on the same path would leave the second unreachable.
      GoRoute(
        path: '/requests/:id/offers',
        name: 'offer-review',
        builder: (_, s) =>
            _stub('offer_review_list_root_${s.pathParameters['id']}'),
      ),
    ],
  );
  // P2/F5: the screen reads the LIVE role (`context.read<RoleCubit>()`) to
  // refuse a jeeber-scoped destination for a client, so the harness must
  // provide the cubit exactly as `app.dart` does.
  return BlocProvider<RoleCubit>.value(
    value: role,
    child: MaterialApp.router(
      routerConfig: router,
      // FM-1: injected, not pinned to 'en' — the Arabic RTL row test drives it.
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    ),
  );
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    NotificationsRepository repo, {
    Locale locale = const Locale('en'),
    UserRole role = UserRole.jeeber,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final roleCubit = RoleCubit(prefs: prefs, initialRole: role);
    addTearDown(roleCubit.close);
    await tester.pumpWidget(_harness(repo, roleCubit, locale: locale));
    await tester.pumpAndSettle();
  }

  testWidgets('renders notifications_root + typed notif_row_<id> rows', (
    tester,
  ) async {
    await pump(
      tester,
      _ScriptedRepository([
        _item('notif-001', NotificationKind.offer),
        _item('notif-005', NotificationKind.feeWon),
      ]),
    );

    expect(find.bySemanticsIdentifier('notifications_root'), findsOneWidget);
    expect(find.bySemanticsIdentifier('notif_row_notif-001'), findsOneWidget);
    expect(find.bySemanticsIdentifier('notif_row_notif-005'), findsOneWidget);
    expect(find.byType(OmdsPullToRefresh), findsOneWidget);
  });

  testWidgets(
    'AC-16 FM1 Arabic RTL row mirrors icon and unread dot without overflow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pump(
        tester,
        _ScriptedRepository([
          NotificationItem(
            id: 'rtl-offer',
            kind: NotificationKind.offer,
            title: 'New offer on your request',
            body: 'Tap to review.',
            timestamp: '2999-01-01T00:00:00Z',
            read: false,
            ref: 'req-rtl',
          ),
        ]),
        locale: const Locale('ar'),
      );

      final row = find.bySemanticsIdentifier('notif_row_rtl-offer');
      final icon = find.byIcon(Icons.local_offer_outlined);
      final unread = find.bySemanticsIdentifier(
        'notif_row_rtl-offer_unread_badge',
      );
      final rowRect = tester.getRect(row);

      expect(Directionality.of(tester.element(row)), TextDirection.rtl);
      expect(find.text('عرض جديد'), findsOneWidget);
      expect(find.text('الآن'), findsOneWidget);
      expect(tester.getRect(icon).center.dx, greaterThan(rowRect.center.dx));
      expect(tester.getRect(unread).center.dx, lessThan(rowRect.center.dx));
      expect(tester.takeException(), isNull);
    },
  );

  // P0-X08 regression: each row's eyebrow (category, derived from `kind`) must
  // be DISTINCT from its title (the payload headline) — never the same string
  // rendered twice (the "collapsed hierarchy" fixture bug). The `offer` kind
  // eyebrow is "New offer"; the title is "title-notif-001". Both must render,
  // and the eyebrow must NOT equal the title.
  testWidgets('row eyebrow (category) is distinct from the title (P0-X08)', (
    tester,
  ) async {
    await pump(
      tester,
      _ScriptedRepository([_item('notif-001', NotificationKind.offer)]),
    );

    // Eyebrow = the per-kind category label (independent of the payload title).
    expect(find.text('New offer'), findsOneWidget);
    // Title = the unique payload headline (NOT the category label).
    expect(find.text('title-notif-001'), findsOneWidget);
    // Body = the distinct payload body.
    expect(find.text('body-notif-001'), findsOneWidget);
    // The eyebrow string is never reused as the title (no duplicate render).
    expect(find.text('New offer'), findsOneWidget);
  });

  testWidgets('empty inbox shows the empty state (loaded sub-state)', (
    tester,
  ) async {
    await pump(tester, _ScriptedRepository(const []));
    expect(find.bySemanticsIdentifier('notifications_root'), findsOneWidget);
    // Empty is loaded + no rows — the OMDS empty illustration renders, no rows.
    expect(find.byIcon(Icons.notifications_none_outlined), findsOneWidget);
    expect(find.bySemanticsIdentifier('notif_row_notif-001'), findsNothing);
  });

  testWidgets('cold-load failure renders the error state', (tester) async {
    await pump(
      tester,
      _ScriptedRepository(const [], fetchThrows: NotificationsFailure.network),
    );
    expect(find.bySemanticsIdentifier('notifications_root'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('unknown row: tapping marks read in place + clears its badge', (
    tester,
  ) async {
    // `unknown` has no D84 target → no navigation, so the row stays mounted and
    // we can observe the optimistic badge clear on the SAME screen.
    final repo = _ScriptedRepository([
      _item('notif-x', NotificationKind.unknown),
    ]);
    await pump(tester, repo);

    expect(
      find.bySemanticsIdentifier('notif_row_notif-x_unread_badge'),
      findsOneWidget,
    );
    await tester.tap(find.bySemanticsIdentifier('notif_row_notif-x'));
    await tester.pumpAndSettle();

    expect(repo.markedRead, ['notif-x']);
    expect(
      find.bySemanticsIdentifier('notif_row_notif-x_unread_badge'),
      findsNothing,
    );
    // unknown → no fabricated nav: still on the inbox.
    expect(find.bySemanticsIdentifier('notifications_root'), findsOneWidget);
  });

  group('D84 deep-link dispatch', () {
    Future<void> tapKind(
      WidgetTester tester,
      NotificationKind kind, {
      String? ref,
      required String expectRootId,
      UserRole role = UserRole.jeeber,
    }) async {
      await pump(
        tester,
        _ScriptedRepository([_item('n', kind, ref: ref)]),
        role: role,
      );
      await tester.tap(find.bySemanticsIdentifier('notif_row_n'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsIdentifier(expectRootId), findsOneWidget);
    }

    // C10a (P2/F4): before P2 the inbox row went to `shell` while the push tap
    // went to `/orders/:id` — two different wrong answers for one event. Both
    // now consume the SAME resolver and land on the offer-review list.
    testWidgets('offer (ref) → offer-review list (P2/F4)', (tester) async {
      await tapKind(tester, NotificationKind.offer,
          ref: 'req-1', expectRootId: 'offer_review_list_root_req-1');
    });

    // C10b: no `ref` → the shell, as before (never a fabricated destination).
    testWidgets('offer with NO ref → shell (no fabricated destination)',
        (tester) async {
      await tapKind(tester, NotificationKind.offer, expectRootId: 'shell_root');
    });

    // FM-1's own binding of the same behaviour on its `req-88` fixture. Kept
    // (rather than folded into C10a) so the FM-1 acceptance-criteria name is
    // not silently dropped; retargeted to the real `offer_review_list_root`
    // stub id, since `offer_review_root` has 0 hits in `lib/`.
    testWidgets('FM1 offer with ref → offer-review', (tester) async {
      await tapKind(
        tester,
        NotificationKind.offer,
        ref: 'req-88',
        expectRootId: 'offer_review_list_root_req-88',
      );
    });

    // C10c (P2/F5): the FIX-REQUESTS 403 fix on the inbox surface — a CLIENT
    // tapping a `new_request` row must not reach `/jeeber/requests/:id`, whose
    // recovery path calls the jeeber-only `GET /v1/jeebers/me/feed`.
    testWidgets('new_request (ref) as a CLIENT → shell, never the jeeber '
        'request screen (F5)', (tester) async {
      await tapKind(tester, NotificationKind.newRequest,
          ref: 'req-1',
          role: UserRole.client,
          expectRootId: 'shell_root');
      expect(
        find.bySemanticsIdentifier('jeeber_request_root_req-1'),
        findsNothing,
      );
    });

    // C10d: fence — the guard must not over-refuse a real jeeber.
    testWidgets('new_request (ref) as a JEEBER → jeeber request screen (fence)',
        (tester) async {
      await tapKind(tester, NotificationKind.newRequest,
          ref: 'req-1',
          role: UserRole.jeeber,
          expectRootId: 'jeeber_request_root_req-1');
    });

    testWidgets('low_balance → wallet-hub', (tester) async {
      await tapKind(
        tester,
        NotificationKind.lowBalance,
        expectRootId: 'wallet_hub_root',
      );
    });

    testWidgets('fee_won → wallet-hub', (tester) async {
      await tapKind(
        tester,
        NotificationKind.feeWon,
        expectRootId: 'wallet_hub_root',
      );
    });

    testWidgets('topup → wallet-hub', (tester) async {
      await tapKind(
        tester,
        NotificationKind.topup,
        expectRootId: 'wallet_hub_root',
      );
    });

    testWidgets('refund_penalty → wallet-hub', (tester) async {
      await tapKind(
        tester,
        NotificationKind.refundPenalty,
        expectRootId: 'wallet_hub_root',
      );
    });

    testWidgets('offer_accepted (ref) → order-chat', (tester) async {
      await tapKind(
        tester,
        NotificationKind.offerAccepted,
        ref: 'conv-9',
        expectRootId: 'order_chat_root_conv-9',
      );
    });

    testWidgets('status (ref) → order-chat', (tester) async {
      await tapKind(
        tester,
        NotificationKind.status,
        ref: 'req-3',
        expectRootId: 'order_chat_root_req-3',
      );
    });

    testWidgets('kyc_approved → shell (jeeber feed tab)', (tester) async {
      await tapKind(
        tester,
        NotificationKind.kycApproved,
        expectRootId: 'shell_root',
      );
    });

    testWidgets('kyc_rejected → kyc-rejected', (tester) async {
      await tapKind(
        tester,
        NotificationKind.kycRejected,
        expectRootId: 'kyc_rejected_root',
      );
    });

    testWidgets('request_expired (ref) → waiting-no-coverage', (tester) async {
      await tapKind(
        tester,
        NotificationKind.requestExpired,
        ref: 'req-5',
        expectRootId: 'waiting_no_coverage_root_req-5',
      );
    });

    testWidgets('confirm_receipt (ref) → delivered-receipt', (tester) async {
      await tapKind(
        tester,
        NotificationKind.confirmReceipt,
        ref: 'dlv-7',
        expectRootId: 'delivered_receipt_root_dlv-7',
      );
    });

    testWidgets('marketing → shell (Requests tab)', (tester) async {
      await tapKind(
        tester,
        NotificationKind.marketing,
        expectRootId: 'shell_root',
      );
    });

    // G3: a dismissed new-request push keeps a persistent, TAPPABLE inbox
    // row that lands on the request screen — via the push-tap resolver
    // (deepLinkForMessage), never a re-mapped route.
    testWidgets('new_request (ref) → jeeber request screen (G3)', (
      tester,
    ) async {
      await tapKind(
        tester,
        NotificationKind.newRequest,
        ref: 'req-42',
        expectRootId: 'jeeber_request_root_req-42',
      );
    });

    testWidgets('new_request with NO ref → stays on the inbox (AP-9)', (
      tester,
    ) async {
      await tapKind(
        tester,
        NotificationKind.newRequest,
        expectRootId: 'notifications_root',
      );
    });

    testWidgets('new_request tap also marks the row read', (tester) async {
      final repo = _ScriptedRepository([
        _item('n-req', NotificationKind.newRequest, ref: 'req-9'),
      ]);
      await pump(tester, repo);
      await tester.tap(find.bySemanticsIdentifier('notif_row_n-req'));
      await tester.pumpAndSettle();
      expect(repo.markedRead, ['n-req']);
      expect(
        find.bySemanticsIdentifier('jeeber_request_root_req-9'),
        findsOneWidget,
      );
    });

    testWidgets('unknown kind → stays on the inbox (no fabricated nav)', (
      tester,
    ) async {
      await tapKind(
        tester,
        NotificationKind.unknown,
        expectRootId: 'notifications_root',
      );
    });

    testWidgets('offer_accepted with NO ref → shell fallback', (tester) async {
      await tapKind(
        tester,
        NotificationKind.offerAccepted,
        expectRootId: 'shell_root',
      );
    });

    testWidgets('confirm_receipt with NO ref → stays on the inbox', (
      tester,
    ) async {
      await tapKind(
        tester,
        NotificationKind.confirmReceipt,
        expectRootId: 'notifications_root',
      );
    });
  });
}
