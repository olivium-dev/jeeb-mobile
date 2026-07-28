// N3 (b02 polling→push). F3's original claim was "the 10s home poll must PAUSE
// while backgrounded and RESUME with one immediate refresh". Half of that
// survives and half is obsolete:
//
//   * PAUSE is now trivially true and is asserted the strong way — the home
//     summary issues zero reads across a five-minute FOREGROUND window too,
//     not merely while hidden. A poll that only stopped when hidden would pass
//     the old case and fail this one.
//   * RESUME is the half that still matters, and it matters MORE now: with the
//     clock gone, the resume one-shot is one of only three things that can
//     refresh this surface, and it is the backstop for a dropped push. It is
//     kept verbatim.
//
// `_CountingRepo` counts /requests + /deliveries + /v1/offers snapshots — the
// seven-read fan-out F3 was written about.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_state.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/presentation/client_home_screen.dart';
import 'package:jeeb_mobile/features/shell/tab_visibility.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

/// Counts every snapshot pull so we can prove polling ticks (or does not) under
/// each lifecycle state.
class _CountingRepo implements ClientHomeRepository {
  int calls = 0;

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async {
    calls += 1;
    return const ClientHomeSnapshot();
  }
}

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

Widget _harness({required _CountingRepo repo}) {
  return MaterialApp(
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
      body: BlocProvider(
        create: (_) => ClientHomeCubit(
          repository: repo,
          greetingNameProvider: () => 'Sami',
        ),
        // JEBV4-298: the 10s live-refresh poll is a property of the
        // In-Progress live-tracking surface, which was relocated off the
        // default Requests view (now Pending/Replies). Pin the In-Progress
        // tab so this test still exercises the poll lifecycle machinery.
        child: const TabVisibility(
          isVisible: true,
          child: ClientHomeScreen(initialTab: ClientHomeTab.inProgress),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(_loadArbs);

  testWidgets(
      'the home summary reads NOTHING on a clock — foreground or backgrounded '
      '— and still refreshes exactly once on return to the foreground',
      (tester) async {
    final repo = _CountingRepo();
    await tester.pumpWidget(_harness(repo: repo));
    await tester.pumpAndSettle();

    // Mount one-shot.
    expect(repo.calls, greaterThanOrEqualTo(1));
    final afterMount = repo.calls;

    // FOREGROUND + VISIBLE + In-Progress selected: every condition the retired
    // 10 s poll needed, held for thirty of its intervals. Pre-fix this adds ~30.
    await tester.pump(const Duration(minutes: 5));
    await tester.pump();
    expect(repo.calls, afterMount,
        reason: 'a foregrounded, visible In-Progress tab must not tick');

    // Backgrounded: still nothing (the weaker half of the original claim).
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    final atPause = repo.calls;
    await tester.pump(const Duration(minutes: 5));
    await tester.pump();
    expect(repo.calls, atPause, reason: 'a backgrounded app must not read');

    // Foreground again → EXACTLY ONE refresh. This is the backstop for a
    // dropped push and is also this file's positive control: without it, the
    // two zeros above would be indistinguishable from a screen that was never
    // mounted or a repository nobody holds.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle(const Duration(milliseconds: 10));
    expect(repo.calls, atPause + 1,
        reason: 'resume must trigger exactly one immediate refresh');
  });
}
