// F3 (offers-polling storm — home path 429 tolerance).
//
// A 429 while loading the customer home must degrade GRACEFULLY: it must never
// paint the full-screen "Couldn't reach Jeeb" connection error, must keep any
// already-rendered data, and must leave the New Order create-flow reachable.
//
// These tests pin that behaviour at the cubit + screen seam:
//   1. a COLD load that is rate-limited lands on READY (not FAILED), so the
//      empty-state hero + New Order CTA render — the full-screen error never
//      shows;
//   2. a rate-limited background REFRESH keeps the previously-loaded data on
//      screen (no blank, no error) and honors Retry-After by skipping the next
//      poll tick.

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

/// Repository whose snapshots are scripted per-call so a test can drive a clean
/// first load followed by a throttled (429) refresh, and count calls.
class _ScriptedRepo implements ClientHomeRepository {
  _ScriptedRepo(this._script);

  final List<ClientHomeSnapshot> _script;
  int calls = 0;

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async {
    final snapshot = _script[calls < _script.length ? calls : _script.length - 1];
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
      home: Scaffold(
        body: BlocProvider.value(
          value: cubit,
          child: const ClientHomeScreen(),
        ),
      ),
    );

void main() {
  setUpAll(_loadArbs);

  group('ClientHomeCubit 429 tolerance', () {
    test('a cold rate-limited load lands on READY, never FAILED', () async {
      final repo = _ScriptedRepo([
        const ClientHomeSnapshot(rateLimited: true, retryAfter: Duration(seconds: 30)),
      ]);
      final cubit = ClientHomeCubit(
        repository: repo,
        greetingNameProvider: () => 'Sami',
      );
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.status, ClientHomeStatus.ready,
          reason: 'a 429 must degrade to a usable (empty) home, never the '
              'full-screen connection error');
    });

    test('a rate-limited REFRESH keeps the previously-loaded data on screen',
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
      expect(cubit.state.inProgress, hasLength(1),
          reason: 'a throttled refresh must not blank the cached data');
    });

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

      // Inside the 5-minute Retry-After window: refresh must be skipped.
      await cubit.refresh();
      expect(repo.calls, 1,
          reason: 'refresh must honor the open Retry-After backoff window');
    });
  });

  group('ClientHomeScreen 429 tolerance (widget)', () {
    testWidgets(
        'a cold 429 renders the empty home with a reachable New Order FAB — '
        'never the full-screen connection error', (tester) async {
      final repo = _ScriptedRepo([
        const ClientHomeSnapshot(rateLimited: true),
      ]);
      final cubit = ClientHomeCubit(
        repository: repo,
        greetingNameProvider: () => 'Sami',
      );
      addTearDown(cubit.close);

      await tester.pumpWidget(_harness(cubit));
      await cubit.load();
      await tester.pumpAndSettle();

      // The status never regressed to the full-screen failure state.
      expect(cubit.state.status, ClientHomeStatus.ready);

      // The New Order create-flow entry (FAB) is present and tappable — a 429
      // must never block reaching New Order.
      final fab = find.bySemanticsLabel(
        AppLocalizations.of(tester.element(find.byType(ClientHomeScreen)))
            .homeNewOrderCta,
      );
      expect(fab, findsWidgets,
          reason: 'the New Order entry must stay reachable after a 429');
    });
  });
}
