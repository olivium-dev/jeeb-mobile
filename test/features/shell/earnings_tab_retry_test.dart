// ES-11/EP-18 + SHELL-09: the fail-closed gate is no longer a dead screen, and
// the session read is memoised instead of re-run on every rebuild.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/features/shell/tabs/earnings_tab.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

/// Counts the keychain reads and can be made to throw.
class _CountingAuthTokenStore extends AuthTokenStore {
  _CountingAuthTokenStore({this.throws = false});

  final bool throws;

  int reads = 0;

  @override
  Future<String?> get userId async {
    reads++;
    if (throws) throw StateError('keychain unavailable');
    return null;
  }

  @override
  Future<String?> get accessToken async => null;

  @override
  Future<String?> get refreshToken async => null;

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
    String? userId,
  }) async {}

  @override
  Future<void> clear() async {}
}

Future<void> _pump(
  WidgetTester tester,
  Widget tab, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    wrapForTest(
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: tab,
        ),
      ),
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    if (sl.isRegistered<AuthTokenStore>()) sl.unregister<AuthTokenStore>();
  });

  tearDown(() {
    if (sl.isRegistered<AuthTokenStore>()) sl.unregister<AuthTokenStore>();
  });

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    testWidgets('${locale.languageCode}: no session id renders the gate WITH a '
        'body and both acts', (tester) async {
      useReduceMotion(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(
        tester,
        EarningsTab(sessionUserId: Future<String?>.value(null)),
        locale: locale,
      );

      expect(
        find.bySemanticsIdentifier(EarningsTab.unavailableIdentifier),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('earnings_tab_unavailable_error_body'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('earnings_tab_retry_cta'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('earnings_tab_signout_cta'),
        findsOneWidget,
      );

      handle.dispose();
    });
  }

  testWidgets('SHELL-09: the session future is MEMOISED — a forced rebuild '
      'does not re-read the keychain', (tester) async {
    useReduceMotion(tester);
    final store = _CountingAuthTokenStore();
    sl.registerSingleton<AuthTokenStore>(store);

    await _pump(tester, const EarningsTab());
    expect(store.reads, 1);

    // Force a rebuild of the whole subtree.
    await tester.pumpWidget(
      wrapForTest(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: const TextScaler.linear(1.1),
            ),
            child: const EarningsTab(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(store.reads, 1);
  });

  testWidgets('tapping retry re-reads the session exactly once', (tester) async {
    useReduceMotion(tester);
    final SemanticsHandle handle = tester.ensureSemantics();
    final store = _CountingAuthTokenStore();
    sl.registerSingleton<AuthTokenStore>(store);

    await _pump(tester, const EarningsTab());
    expect(store.reads, 1);

    await tester.tap(find.bySemanticsIdentifier('earnings_tab_retry_cta'));
    await tester.pumpAndSettle();

    expect(store.reads, 2);
    handle.dispose();
  });

  testWidgets('R6: a THROWING store renders the failure block, not the '
      '"no account" copy path', (tester) async {
    useReduceMotion(tester);
    final SemanticsHandle handle = tester.ensureSemantics();
    final store = _CountingAuthTokenStore(throws: true);
    sl.registerSingleton<AuthTokenStore>(store);

    await _pump(tester, const EarningsTab());

    expect(
      find.bySemanticsIdentifier(EarningsTab.unavailableIdentifier),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('earnings_tab_retry_cta'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    handle.dispose();
  });

  testWidgets('the loading arm still pins on a pending read', (tester) async {
    useReduceMotion(tester);
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pump(
      tester,
      EarningsTab(sessionUserId: Completer<String?>().future),
    );

    expect(
      find.bySemanticsIdentifier(EarningsTab.loadingIdentifier),
      findsOneWidget,
    );

    handle.dispose();
  });
}
