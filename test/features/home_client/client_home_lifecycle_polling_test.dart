// F3 (offers polling storm): the 10s home poll must PAUSE while the app is
// backgrounded and RESUME (with one immediate refresh) when it returns to the
// foreground. A hidden app that keeps polling /requests + /deliveries +
// /v1/offers is pure waste and a fast path to a 429.

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
          pollInterval: const Duration(milliseconds: 40),
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
      'the home poll pauses while backgrounded and resumes with an immediate '
      'refresh on return to foreground', (tester) async {
    final repo = _CountingRepo();
    await tester.pumpWidget(_harness(repo: repo));
    await tester.pumpAndSettle();

    // Initial load + polling active on the In-Progress tab.
    expect(repo.calls, greaterThanOrEqualTo(1));
    await tester.pump(const Duration(milliseconds: 45));
    await tester.pump(const Duration(milliseconds: 45));
    final whileForeground = repo.calls;
    expect(whileForeground, greaterThan(1),
        reason: 'polling must tick while foreground + visible');

    // Background the app → polling must STOP: no further pulls across several
    // poll intervals.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    final atPause = repo.calls;
    await tester.pump(const Duration(milliseconds: 45));
    await tester.pump(const Duration(milliseconds: 45));
    await tester.pump(const Duration(milliseconds: 45));
    expect(repo.calls, atPause,
        reason: 'a backgrounded app must not poll');

    // Foreground again → exactly one immediate refresh, then polling resumes.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle(const Duration(milliseconds: 10));
    expect(repo.calls, greaterThan(atPause),
        reason: 'resume must trigger an immediate refresh');

    // Drain any pending poll timer so the test tears down clean.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
  });
}
