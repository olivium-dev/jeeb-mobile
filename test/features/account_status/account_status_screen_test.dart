// Widget tests for AccountStatusScreen (JM-066, D5). Proves:
//   - the EXACT Semantics identifiers render off an injected repository
//     (account_status_root, account_status_support_cta, account_status_signout_cta,
//      account_status_banner, account_status_reason) — 30_BACKLOG JM-066;
//   - the D30 4-state machine (loading → failed(retry) → loaded);
//   - the banner distinguishes suspended vs locked (D5 status branch);
//   - a server-supplied reason wins over the localized default;
//   - the two exit CTAs land on the REGISTERED targets (support-ticket / settings).
//
// A minimal GoRouter with stub destination screens (each carrying a *_root id)
// backs the CTA nav assertions, since context.goNamed needs a router. This test
// imports ONLY the account_status feature (not app_router), so it is independent
// of sibling W4 screens.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jeeb_mobile/features/account_status/domain/account_status.dart';
import 'package:jeeb_mobile/features/account_status/domain/account_status_repository.dart';
import 'package:jeeb_mobile/features/account_status/presentation/account_status_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _ScriptedRepository implements AccountStatusRepository {
  _ScriptedRepository(this._info, {this.fetchThrows});

  final AccountStatusInfo _info;
  final AccountStatusFailure? fetchThrows;
  int calls = 0;

  @override
  Future<AccountStatusInfo> fetchStatus() async {
    calls++;
    final f = fetchThrows;
    if (f != null) throw AccountStatusRepositoryException(f);
    return _info;
  }
}

/// A repo that throws once then succeeds — drives the retry assertion.
class _FlakyRepository implements AccountStatusRepository {
  _FlakyRepository(this._info);
  final AccountStatusInfo _info;
  int calls = 0;

  @override
  Future<AccountStatusInfo> fetchStatus() async {
    calls++;
    if (calls == 1) {
      throw const AccountStatusRepositoryException(AccountStatusFailure.network);
    }
    return _info;
  }
}

Widget _stub(String id) => Semantics(
      identifier: id,
      container: true,
      child: const Scaffold(body: SizedBox.expand()),
    );

Widget _harness(AccountStatusRepository repo, {Locale locale = const Locale('en')}) {
  final router = GoRouter(
    initialLocation: '/account-status',
    routes: [
      GoRoute(
        path: '/account-status',
        name: 'account-status',
        builder: (context, state) => AccountStatusScreen(repository: repo),
      ),
      GoRoute(
        path: '/support',
        name: 'support-ticket',
        builder: (context, state) => _stub('support_ticket_root'),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => _stub('settings_root'),
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
  );
}

void main() {
  Future<void> pump(WidgetTester tester, AccountStatusRepository repo,
      {Locale locale = const Locale('en')}) async {
    await tester.pumpWidget(_harness(repo, locale: locale));
    await tester.pumpAndSettle();
  }

  testWidgets('renders root + banner + reason + both CTA ids (suspended)',
      (tester) async {
    await pump(
      tester,
      _ScriptedRepository(
        const AccountStatusInfo(value: AccountStatusValue.suspended),
      ),
    );

    expect(find.bySemanticsIdentifier('account_status_root'), findsOneWidget);
    expect(find.bySemanticsIdentifier('account_status_banner'), findsOneWidget);
    expect(find.bySemanticsIdentifier('account_status_reason'), findsOneWidget);
    expect(find.bySemanticsIdentifier('account_status_support_cta'),
        findsOneWidget);
    expect(find.bySemanticsIdentifier('account_status_signout_cta'),
        findsOneWidget);
    // suspended-state banner copy.
    expect(find.text('Your account is suspended'), findsOneWidget);
  });

  testWidgets('locked status renders the locked banner', (tester) async {
    await pump(
      tester,
      _ScriptedRepository(
        const AccountStatusInfo(value: AccountStatusValue.locked),
      ),
    );
    expect(find.text('Your account is locked'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
  });

  testWidgets('server-supplied reason wins over the localized default',
      (tester) async {
    await pump(
      tester,
      _ScriptedRepository(
        const AccountStatusInfo(
          value: AccountStatusValue.suspended,
          reason: 'Multiple chargeback disputes',
        ),
      ),
    );
    expect(find.text('Multiple chargeback disputes'), findsOneWidget);
  });

  testWidgets('cold-load failure renders the error state', (tester) async {
    await pump(
      tester,
      _ScriptedRepository(
        const AccountStatusInfo(value: AccountStatusValue.suspended),
        fetchThrows: AccountStatusFailure.network,
      ),
    );
    expect(find.bySemanticsIdentifier('account_status_root'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    // No body CTAs while failed.
    expect(find.bySemanticsIdentifier('account_status_support_cta'),
        findsNothing);
  });

  testWidgets('retry after failure recovers to the loaded body', (tester) async {
    final repo = _FlakyRepository(
      const AccountStatusInfo(value: AccountStatusValue.locked),
    );
    await pump(tester, repo);

    // First load failed → error state with retry.
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(repo.calls, 2);
    expect(find.bySemanticsIdentifier('account_status_banner'), findsOneWidget);
    expect(find.text('Your account is locked'), findsOneWidget);
  });

  testWidgets('support CTA → support-ticket', (tester) async {
    await pump(
      tester,
      _ScriptedRepository(
        const AccountStatusInfo(value: AccountStatusValue.suspended),
      ),
    );
    await tester.tap(find.bySemanticsIdentifier('account_status_support_cta'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsIdentifier('support_ticket_root'), findsOneWidget);
  });

  testWidgets('signout CTA → logout/delete confirm sheet (both actions)',
      (tester) async {
    // W4 restructure (JM-066 AC3): the signout CTA no longer routes to a
    // `/settings` host — it opens the shared `LogoutDeleteConfirmSheet` in
    // `both` mode directly (the same sheet JM-062's profile row raises). The
    // on-device jm-066 flow asserts `logout_delete_sheet` here; the confirm CTAs
    // then clear the session → splash → /login (D5). Assert the sheet + both
    // terminal CTAs open, matching the live behaviour.
    await pump(
      tester,
      _ScriptedRepository(
        const AccountStatusInfo(value: AccountStatusValue.suspended),
      ),
    );
    await tester.tap(find.bySemanticsIdentifier('account_status_signout_cta'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsIdentifier('logout_delete_sheet'), findsOneWidget);
    expect(find.bySemanticsIdentifier('logout_confirm_cta'), findsOneWidget);
    expect(find.bySemanticsIdentifier('delete_confirm_cta'), findsOneWidget);
  });
}
