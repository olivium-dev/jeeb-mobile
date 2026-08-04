import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_state.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_request.dart';
import 'package:jeeb_mobile/features/home_client/presentation/client_home_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

/// Repository whose snapshots are scripted per-call so a test c
class _ScriptedRepo implements ClientHomeRepository {
  _ScriptedRepo(this._script);

  final List<ClientHomeSnapshot> _script;
  int calls = 0;

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async {
    final snapshot =
        _script[calls < _script.length ? calls : _script.length - 1];
    calls += 1;
    return snapshot;
  }
}

const _order = ClientHomeRequest(
  id: 'ip-1',
  title: 'Kamal Hajj',
  destinationLabel: '1 kilo potato',
  status: ClientRequestStatus.enRoute,
  tier: ClientRequestTier.flash,
  progressStep: 3,
);

class _SyncDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncDelegate(this._arbByTag);
  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arbByTag[locale.languageCode]!);

  @override
  bool shouldReload(_SyncDelegate old) => false;
}

late _SyncDelegate _syncDelegate;

void _loadArbs() {
  final en = File('lib/l10n/app_en.arb').readAsStringSync();
  final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  _syncDelegate = _SyncDelegate({'en': en, 'ar': ar});
}

Widget _harness(ClientHomeCubit cubit) => MaterialApp(
  theme: AppTheme.light(),
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: [
    _syncDelegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  // Midnight primitives loop ∞ (02-STUDY-NOTES M0-4): `pumpAndSettle` only
  // terminates under reduce motion.
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child!,
  ),
  home: Scaffold(
    body: BlocProvider.value(value: cubit, child: const ClientHomeScreen()),
  ),
);

void main() {
  setUpAll(_loadArbs);

  group('ClientHomeCubit 429 tolerance', () {
    test('a cold rate-limited load lands on READY, never FAILED', () async {
      final repo = _ScriptedRepo([
        const ClientHomeSnapshot(
          rateLimited: true,
          retryAfter: Duration(seconds: 30),
        ),
      ]);
      final cubit = ClientHomeCubit(
        repository: repo,
        greetingNameProvider: () => 'Sami',
      );
      addTearDown(cubit.close);

      await cubit.load();

      expect(
        cubit.state.status,
        ClientHomeStatus.ready,
        reason:
            'a 429 must degrade to a usable (empty) home, never the '
            'full-screen connection error',
      );
    });

    test(
      'a rate-limited REFRESH keeps the previously-loaded data on screen',
      () async {
        final repo = _ScriptedRepo([
          const ClientHomeSnapshot(inProgress: [_order]), // clean first load
          const ClientHomeSnapshot(rateLimited: true), // throttled refresh
        ]);
        final cubit = ClientHomeCubit(
          repository: repo,
          greetingNameProvider: () => 'Sami',
        );
        addTearDown(cubit.close);

        await cubit.load();
        expect(cubit.state.inProgress, hasLength(1));

        await cubit.refresh();

        expect(cubit.state.status, ClientHomeStatus.ready);
        expect(
          cubit.state.inProgress,
          hasLength(1),
          reason: 'a throttled refresh must not blank the cached data',
        );
      },
    );

    test('Retry-After backs the poll off — a refresh inside the window is a '
        'no-op (no extra repository read)', () async {
      final repo = _ScriptedRepo([
        const ClientHomeSnapshot(
          inProgress: [_order],
          rateLimited: true,
          retryAfter: Duration(minutes: 5),
        ),
      ]);
      final cubit = ClientHomeCubit(
        repository: repo,
        greetingNameProvider: () => 'Sami',
      );
      addTearDown(cubit.close);

      await cubit.load();
      expect(repo.calls, 1);

      await cubit.refresh();
      expect(
        repo.calls,
        1,
        reason: 'refresh must honor the open Retry-After backoff window',
      );
    });
  });

  group('ClientHomeScreen 429 tolerance (widget)', () {
    testWidgets('a cold 429 keeps the top plus and empty-state CTA reachable — '
        'without the removed FAB', (tester) async {
      final repo = _ScriptedRepo([const ClientHomeSnapshot(rateLimited: true)]);
      final cubit = ClientHomeCubit(
        repository: repo,
        greetingNameProvider: () => 'Sami',
      );
      addTearDown(cubit.close);

      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness(cubit));
      await cubit.load();
      await tester.pumpAndSettle();

      expect(cubit.state.status, ClientHomeStatus.ready);

      expect(
        find.bySemanticsIdentifier('orders_create_request_button'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('_request_empty_state_new_order_button'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('orders_home_new_order_fab'),
        findsNothing,
      );
      handle.dispose();
      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });
}
