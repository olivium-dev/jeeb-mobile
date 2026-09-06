// Critic A4: `load()` returned early unless `status == initial`, so the error
// rung's CTA was inert; `refresh()` flipped to `loading` and blanked the
// loaded banner (R6: a refresh NEVER flips to loading). UX-43: `state.value`
// defaulted to `suspended`, labelling every unloaded read as a ban.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/account_status/application/account_status_cubit.dart';
import 'package:jeeb_mobile/features/account_status/application/account_status_state.dart';
import 'package:jeeb_mobile/features/account_status/domain/account_status.dart';
import 'package:jeeb_mobile/features/account_status/domain/account_status_repository.dart';
import 'package:jeeb_mobile/features/account_status/presentation/account_status_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

const _info = AccountStatusInfo(
  value: AccountStatusValue.suspended,
  reason: 'A moderator paused this account.',
);

/// Answers once, then fails — the warm-refresh case.
class _RefreshFailingRepository implements AccountStatusRepository {
  int calls = 0;

  @override
  Future<AccountStatusInfo> fetchStatus() async {
    calls++;
    if (calls == 1) return _info;
    throw const AccountStatusRepositoryException(AccountStatusFailure.network);
  }
}

class _ThrowingRepository implements AccountStatusRepository {
  _ThrowingRepository(this.failure);

  final AccountStatusFailure failure;
  int calls = 0;

  @override
  Future<AccountStatusInfo> fetchStatus() async {
    calls++;
    throw AccountStatusRepositoryException(failure);
  }
}

Widget _harness(AccountStatusRepository repo, {Locale locale = const Locale('en')}) {
  final router = GoRouter(
    initialLocation: '/account-status',
    routes: <RouteBase>[
      GoRoute(
        path: '/account-status',
        name: 'account-status',
        builder: (context, state) => AccountStatusScreen(repository: repo),
      ),
      GoRoute(
        path: '/support',
        name: 'support-ticket',
        builder: (context, state) => const Scaffold(body: SizedBox.expand()),
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    locale: locale,
    theme: AppTheme.midnight(),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<Object>>[
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
}

void main() {
  test('refresh() from loaded keeps the banner and sets refreshError',
      () async {
    final repo = _RefreshFailingRepository();
    final cubit = AccountStatusCubit(repository: repo);
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.refresh();

    expect(cubit.state.status, AccountStatusScreenStatus.loaded);
    expect(cubit.state.info, _info);
    expect(cubit.state.refreshError, isA<NetworkFailure>());
    expect(cubit.state.error, isNull);
  });

  test('load() retries from failed — the old guard made the CTA inert',
      () async {
    final repo = _ThrowingRepository(AccountStatusFailure.network);
    final cubit = AccountStatusCubit(repository: repo);
    addTearDown(cubit.close);

    await cubit.load();
    expect(cubit.state.status, AccountStatusScreenStatus.failed);

    await cubit.load();

    expect(repo.calls, 2);
  });

  test('value is NULL until an authoritative read lands', () {
    const state = AccountStatusState();

    expect(state.value, isNull);
    expect(state.value, isNot(AccountStatusValue.suspended));
  });

  testWidgets('a null info renders NO suspended banner', (tester) async {
    useReduceMotion(tester);
    await tester.pumpWidget(
      _harness(_ThrowingRepository(AccountStatusFailure.serverError)),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsIdentifier('account_status_banner'), findsNothing);
    expect(find.bySemanticsIdentifier('account_status_reason'), findsNothing);
    expect(
      find.bySemanticsIdentifier(AccountStatusScreen.loadErrorIdentifier),
      findsOneWidget,
    );
  });

  testWidgets('a 403 is terminal: the EXIT act, never a Retry', (tester) async {
    useReduceMotion(tester);
    await tester.pumpWidget(
      _harness(_ThrowingRepository(AccountStatusFailure.forbidden)),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsIdentifier(AccountStatusScreen.retryIdentifier),
      findsNothing,
    );
    // `JeebFailureBlock` derives the exit id from the error id.
    expect(
      find.bySemanticsIdentifier('account_status_load_exit_cta'),
      findsOneWidget,
    );
  });

  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    testWidgets('${locale.languageCode} · a warm refresh failure renders the '
        'note OVER the banner', (tester) async {
      useReduceMotion(tester);
      final repo = _RefreshFailingRepository();
      await tester.pumpWidget(_harness(repo, locale: locale));
      await tester.pumpAndSettle();

      expect(find.bySemanticsIdentifier('account_status_banner'), findsOneWidget);

      // Nothing on the LOADED body triggers a re-read, so drive the warm
      // refresh through the cubit the screen hosts.
      final BuildContext context = tester.element(
        find.bySemanticsIdentifier('account_status_banner'),
      );
      await context.read<AccountStatusCubit>().refresh();
      await tester.pumpAndSettle();

      // The banner survives; the note appears above it.
      expect(find.bySemanticsIdentifier('account_status_banner'), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('account_status_refresh_failed_note'),
        findsOneWidget,
      );
    });
  }
}
