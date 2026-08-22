// Two layout defects the owner caught on a real SM-S921B, both measured.
//
// 1. THE HEADER ATE A THIRD OF THE SCREEN. `_scrollChildren` mounted the
//    312px prompt hero ("What do you need tonight?" + tagline) unconditionally.
//    Top of content to top of the first card measured 798px of 2340 — 34% —
//    on a screen that already carries a pinned create dock at the bottom and a
//    greeting that says the same time-of-day line.
// 2. THE CARDS SHRANK TO THEIR TEXT. Three nested Columns left
//    crossAxisAlignment at its default (.center), which hands children LOOSE
//    width; each card sized to its own longest line and centred. Measured
//    616px on a 1080px screen where the gutter allows 936px.
//
// Both are pinned here by GEOMETRY, not by widget identity, because both
// regress silently: the tree stays valid and only the pixels are wrong.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_state.dart';
import 'package:jeeb_mobile/features/home_client/data/in_memory_client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_request.dart';
import 'package:jeeb_mobile/features/home_client/presentation/client_home_screen.dart';
import 'package:jeeb_mobile/features/home_client/presentation/widgets/client_home_request_hero.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

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

late _SyncDelegate _delegate;

/// The S24 the defects were measured on, in logical pixels (1080/3, 2340/3).
const Size _s24 = Size(360, 780);

ClientHomeRequest _pending(String id) => ClientHomeRequest(
  id: id,
  title: 'ORD-9F40FC',
  status: ClientRequestStatus.searching,
  destinationLabel: 'Current location',
  itemsSummary: 'Filter UX validation',
  displayId: 'ORD-9F40FC',
  tier: ClientRequestTier.flash,
);

Widget _harness(ClientHomeRepository repo) => MaterialApp(
  theme: AppTheme.light(),
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: [
    _delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child!,
  ),
  home: Scaffold(
    body: BlocProvider(
      create: (_) => ClientHomeCubit(
        repository: repo,
        greetingNameProvider: () => 'nour',
      ),
      child: const ClientHomeScreen(initialTab: ClientHomeTab.all),
    ),
  ),
);

/// The prompt HALF only. The pinned bottom dock mounts the same widget with
/// `showPrompt: false`, so a bare byType finder always matches and proves
/// nothing.
final Finder _promptHero = find.byWidgetPredicate(
  (w) => w is ClientHomeRequestHero && w.showPrompt,
);

Future<void> _pump(WidgetTester tester, ClientHomeRepository repo) async {
  tester.view.physicalSize = _s24 * tester.view.devicePixelRatio;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = _s24;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_harness(repo));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    _delegate = _SyncDelegate({
      'en': File('lib/l10n/app_en.arb').readAsStringSync(),
      'ar': File('lib/l10n/app_ar.arb').readAsStringSync(),
    });
  });

  group('populated home', () {
    ClientHomeRepository repo() =>
        InMemoryClientHomeRepository.fromSnapshot(
          ClientHomeSnapshot(pending: [_pending('p-1')]),
        );

    testWidgets('the prompt hero is dropped once there is a list', (
      tester,
    ) async {
      await _pump(tester, repo());
      expect(
        _promptHero,
        findsNothing,
        reason: 'the 312px prompt is what pushed content to 34% down the page',
      );
    });

    testWidgets('chrome above the first card stays under a quarter of the '
        'viewport', (tester) async {
      await _pump(tester, repo());

      final double cardTop = tester
          .getTopLeft(find.bySemanticsIdentifier('orders_home_request_row_0'))
          .dy;
      // 34% before the fix. A quarter leaves room for a longer greeting or a
      // filter pill row without re-opening the defect.
      expect(
        cardTop / _s24.height,
        lessThan(0.25),
        reason: 'chrome above the first card grew back: ${cardTop.round()}dp '
            'of ${_s24.height.round()}dp',
      );
    });

    testWidgets('the card fills the gutter instead of hugging its text', (
      tester,
    ) async {
      await _pump(tester, repo());

      final Size card = tester.getSize(
        find.bySemanticsIdentifier('orders_home_request_row_0'),
      );
      final Size header = tester.getSize(
        find.byKey(const Key('client-home-requests-header')),
      );
      // Same gutter as the section header above it — that alignment is the
      // whole point, and it survives a font change that a fixed width wouldn't.
      expect(
        card.width,
        closeTo(header.width, 1),
        reason: 'card ${card.width}dp vs header ${header.width}dp: the card is '
            'shrink-wrapping to its own text again',
      );
    });
  });

  testWidgets('an empty home keeps the prompt hero at full size', (
    tester,
  ) async {
    await _pump(tester, InMemoryClientHomeRepository.fromSnapshot(
      const ClientHomeSnapshot(),
    ));
    expect(
      _promptHero,
      findsOneWidget,
      reason: 'with nothing to list the prompt IS the screen',
    );
  });
}
