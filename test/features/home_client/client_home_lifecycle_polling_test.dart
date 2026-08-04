// N3 (b02 polling→push). F3's original claim was "the 10s home poll must PAUSE

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
    // Midnight primitives loop ∞ (02-STUDY-NOTES M0-4): `pumpAndSettle` only
    // terminates under reduce motion.
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: Scaffold(
      body: BlocProvider(
        create: (_) => ClientHomeCubit(
          repository: repo,
          greetingNameProvider: () => 'Sami',
        ),
        // JEBV4-298: the 10s live-refresh poll is a property of the
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
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle(const Duration(milliseconds: 10));
    expect(repo.calls, atPause + 1,
        reason: 'resume must trigger exactly one immediate refresh');
  });
}
