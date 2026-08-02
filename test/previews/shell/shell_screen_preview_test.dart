// Render tests for the ShellScreen previews.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/previews/jeeb_preview.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/shell/shell_screen.dart';
import 'package:jeeb_mobile/features/shell/widgets/jeeber_tab_empty_state.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/load_test_fonts.dart';
import '../../support/sync_app_localizations.dart';
import '../preview_test_harness.dart';

/// The unbounded free-text title of the longest-content preview, duplicated
/// from `ShellScreenPreviewFixtures.longestRequestTitle` on purpose: a preview
const String _kLongestTitle =
    'Pharmacy pickup on Rue Gouraud, then the bakery two streets down, then '
    'drop everything at the clinic on Independence Street before it closes';

/// The five destination labels, in declaration order. Present on every preview,
/// which is precisely why none of them can serve as a per-state pin.
const List<String> _kTabLabels = <String>[
  'Requests',
  'Delivery',
  'Dashboard',
  'Earnings',
  'Profile',
];

/// [previewCanvas] with the real font faces installed on the theme.
/// The shared canvas builds `AppTheme.light()` unmodified and the theme carries
Widget _shellScreenCanvas(Widget Function() preview, Locale locale) {
  return MaterialApp(
    theme: withGoldenTestFonts(AppTheme.light()),
    darkTheme: withGoldenTestFonts(AppTheme.dark()),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<Object?>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: jeebPreviewHost(preview()),
  );
}

/// Pumps a preview at the box its `@JeebPreview(size:)` declares, with the real
/// faces loaded — the only way the declared size stays honest. The shared suite
Future<void> _pumpAtBox(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
  Size size = const Size(390, 844),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(_shellScreenCanvas(preview, locale));
  await tester.pumpAndSettle();
}

/// The `shell_tab_<id>` semantics node, which is what QA and the dual-role
/// landing test both key on — locale-independent, unlike the labels.
Finder _tab(String id) => find.bySemanticsIdentifier('shell_tab_$id');

/// The five destination ids, in the order `_tabs()` declares them.
const List<String> _kTabIds = <String>[
  'requests',
  'delivery',
  'dashboard',
  'earnings',
  'profile',
];

/// What the five destinations ACTUALLY measure, summed.
/// `_JeebBottomBar` lays them out in a bare `Row` with
double _barIntrinsicWidth(WidgetTester tester) {
  double total = 0;
  for (final String id in _kTabIds) {
    total += tester.getSize(_tab(id)).width;
  }
  return total;
}

/// Pumps [preview] at [size] and [textScale] with the REAL faces installed,
/// collecting every framework error instead of letting the binding fail the
Future<List<String>> _errorsAt(
  WidgetTester tester,
  Widget Function() preview, {
  required Size size,
  required double textScale,
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  final List<String> captured = <String>[];
  final void Function(FlutterErrorDetails)? previous = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    captured.add(details.exception.toString().split('\n').first);
  };
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  try {
    await tester.pumpWidget(_shellScreenCanvas(preview, locale));
    await tester.pump(const Duration(milliseconds: 400));
  } finally {
    FlutterError.onError = previous;
  }
  return captured;
}

void main() {
  setUpAll(() async {
    await loadInterTestFont();
    loadPreviewArbs();
  });

  // Every preview whose surface settles. `Requests · cold load` holds an
  testPreviewsRender(
    'ShellScreen',
    const <String, Widget Function()>{
      'Client landing · populated': shellScreenClientLanding,
      'Client landing · empty everywhere': shellScreenClientEmpty,
      'Requests · load failed': shellScreenRequestsUnreachable,
      'Requests · longest content': shellScreenLongestRequest,
      'Dashboard badge · 12 unseen': shellScreenNewRequestBadge,
      'Jeeber landing · Dashboard': shellScreenJeeberLanding,
      'Bottom bar · 320 pt device': shellScreenCompactDevice,
    },
    expectedText: const <String, String>{
      // A pending row from `DevClientHomeFixtures`. Not a tab label and not a
      'Client landing · populated': 'ORD-23470',
      // `homePendingEmpty`, reachable only from a snapshot with nothing in it.
      'Client landing · empty everywhere':
          'No pending requests — broadcast a new one to get offers.',
      // `homeLoadFailedTitle`, which only a COLD failure can reach.
      'Requests · load failed': "Couldn't load your home",
      // The unbounded free-text title.
      'Requests · longest content': _kLongestTitle,
      // The badge count. `Badge.count` renders it as its own `Text`.
      'Dashboard badge · 12 unseen': '12',
      // `requestFeedEmptyTitle`, from the LIVE jeeber feed — a body no
      'Jeeber landing · Dashboard': 'No requests right now',
      // The replies-only snapshot's order id.
      'Bottom bar · 320 pt device': 'ORD-23495',
    },
  );

  // The cold-load preview. `OmdsLoadingState` wraps a `CircularProgressIndicator`
  group('ShellScreen previews · Requests · cold load', () {
    Future<void> pumpColdLoad(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(
        previewCanvas(shellScreenRequestsColdLoad, locale),
      );
      await tester.pump(); // localizations + the five tab bodies build
      await tester.pump(); // the cubits' first emit lands
      await tester.pump(const Duration(milliseconds: 16)); // one spinner frame
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Requests · cold load · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpColdLoad(tester, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('renders its own state: chrome up, body still loading', (
      WidgetTester tester,
    ) async {
      await pumpColdLoad(tester);

      // The shell's own chrome is painted and interactive before any content
      for (final String id in const <String>[
        'requests',
        'delivery',
        'dashboard',
        'earnings',
        'profile',
      ]) {
        expect(_tab(id), findsOneWidget);
      }
      // The landing body is the loading layout: the generic greeting over a
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.text('Welcome back'), findsOneWidget);
      // And none of the three settled surfaces is up. That combination is true
      expect(find.text('ORD-23470'), findsNothing);
      expect(find.text("Couldn't load your home"), findsNothing);
      expect(
        find.text('No pending requests — broadcast a new one to get offers.'),
        findsNothing,
      );
    });
  });

  group('ShellScreen previews · the landing tab (BUG-1)', () {
    // The decision that belongs to THIS screen and to nothing else:

    testWidgets('a client opens on Requests', (WidgetTester tester) async {
      await pumpPreview(tester, shellScreenClientLanding);

      expect(
        tester.getSemantics(_tab('requests')),
        isSemantics(isSelected: true),
      );
      expect(
        tester.getSemantics(_tab('dashboard')),
        isSemantics(isSelected: false),
      );
    });

    testWidgets('a dual-role jeeber opens on Dashboard', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, shellScreenJeeberLanding);

      expect(
        tester.getSemantics(_tab('dashboard')),
        isSemantics(isSelected: true),
      );
      expect(
        tester.getSemantics(_tab('requests')),
        isSemantics(isSelected: false),
      );
    });

    testWidgets('the tab SET is identical on both branches (UX LAW)', (
      WidgetTester tester,
    ) async {
      // S0-E2E-08: the jeeber surfaces are ADDITIVE tabs, never a mode the user
      await pumpPreview(tester, shellScreenClientEmpty);
      for (final String label in _kTabLabels) {
        expect(find.text(label), findsOneWidget, reason: 'client: $label');
      }
      // …and the two jeeber destinations carry their empty states, offstage in
      expect(
        find.byType(JeeberTabEmptyState, skipOffstage: false),
        findsNWidgets(2),
      );
    });

    testWidgets('the jeeber branch replaces the empty states with live bodies', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, shellScreenJeeberLanding);

      for (final String label in _kTabLabels) {
        expect(find.text(label), findsOneWidget, reason: 'jeeber: $label');
      }
      expect(
        find.byType(JeeberTabEmptyState, skipOffstage: false),
        findsNothing,
      );
      expect(
        find.byKey(const Key('dashboard-tab-root'), skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('the bottom bar is honest to tap — no Router needed', (
      WidgetTester tester,
    ) async {
      // `onTap` is a local `setState`, so switching destination is the one
      await pumpPreview(tester, shellScreenClientLanding);

      await tester.tap(_tab('profile'));
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(_tab('profile')),
        isSemantics(isSelected: true),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('ShellScreen previews · the Dashboard badge (G3)', () {
    testWidgets('twelve unseen requests render as a count on the icon', (
      WidgetTester tester,
    ) async {
      // G3: `BadgeCountCubit` was incremented on every push and rendered by
      await pumpPreview(tester, shellScreenNewRequestBadge);

      expect(find.bySemanticsIdentifier('shell_tab_dashboard_badge'),
          findsOneWidget);
      expect(find.text('12'), findsOneWidget);
    });

    testWidgets('the same shell with no unseen requests has no badge', (
      WidgetTester tester,
    ) async {
      // The control: identical fixtures, `newRequests: 0`. If this ever also
      await pumpPreview(tester, shellScreenClientLanding);

      expect(
        find.bySemanticsIdentifier('shell_tab_dashboard_badge'),
        findsNothing,
      );
    });
  });

  group('ShellScreen previews · at the declared canvas box', () {
    // Pumped at the box each preview declares, with the real faces loaded.

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Client landing · populated · ${locale.languageCode} · '
          '390x844', (WidgetTester tester) async {
        await _pumpAtBox(tester, shellScreenClientLanding, locale: locale);

        expect(tester.takeException(), isNull);
      });

      testWidgets('Bottom bar · 320 pt device · ${locale.languageCode} · '
          '320x568', (WidgetTester tester) async {
        await _pumpAtBox(
          tester,
          shellScreenCompactDevice,
          locale: locale,
          size: const Size(320, 568),
        );

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the replies-only snapshot lands on Replies, not Pending', (
      WidgetTester tester,
    ) async {
      // `ClientHomeScreen._resolveInitialTab` moves the chip on the frame after
      await _pumpAtBox(
        tester,
        shellScreenCompactDevice,
        size: const Size(320, 568),
      );

      expect(find.text('ORD-23495'), findsOneWidget);
      expect(
        find.text('No pending requests — broadcast a new one to get offers.'),
        findsNothing,
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('ShellScreen previews · the bottom bar', () {
    /// The intrinsic width of the five destinations, at 100% text, measured
    /// through the shipping faces. Latin is WIDER than Arabic here — `Dashboard`
    const double barWidthEn = 238.9;
    const double barWidthAr = 171.1;

    /// The same five at 200%. `_BarItem`'s `Text` has no `maxLines`, no
    /// `overflow` and nothing flexible above it, so the width scales with the
    const double barWidthEn200 = 469.7;
    const double barWidthAr200 = 342.1;

    for (final Size size in const <Size>[Size(390, 844), Size(320, 568)]) {
      for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
        testWidgets(
          'is clean at 100% on ${size.width.round()}pt · '
          '${locale.languageCode}',
          (WidgetTester tester) async {
            // The control for everything after it: at the default text scale
            final List<String> errors = await _errorsAt(
              tester,
              shellScreenCompactDevice,
              size: size,
              textScale: 1.0,
              locale: locale,
            );

            expect(errors, isEmpty);
            expect(
              _barIntrinsicWidth(tester),
              closeTo(
                locale.languageCode == 'en' ? barWidthEn : barWidthAr,
                1.0,
              ),
            );
          },
        );
      }
    }

    testWidgets('KNOWN: at 200% every destination overflows the fixed 56 dp '
        'bar height, in BOTH locales and on BOTH devices', (
      WidgetTester tester,
    ) async {
      // `_JeebBottomBar` pins its row to `SizedBox(height: Sizes.fiveXLarge)`,
      for (final Size size in const <Size>[Size(390, 844), Size(320, 568)]) {
        for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
          final List<String> errors = await _errorsAt(
            tester,
            shellScreenCompactDevice,
            size: size,
            textScale: 2.0,
            locale: locale,
          );

          expect(
            errors.where((String e) => e.contains('on the bottom')).length,
            5,
            reason: '${size.width.round()}pt · ${locale.languageCode}',
          );
          expect(tester.getSize(_tab('dashboard')).height, 56.0);
        }
      }
    });

    testWidgets('KNOWN: the labels cannot ellipsize, so the row overflows by '
        'exactly what they overrun', (WidgetTester tester) async {
      // The mechanism, pinned as a number rather than as a screenshot: the
      final List<String> errors = await _errorsAt(
        tester,
        shellScreenCompactDevice,
        size: const Size(390, 844),
        textScale: 1.75,
      );

      final double intrinsic = _barIntrinsicWidth(tester);
      expect(intrinsic, closeTo(412.0, 1.0));
      // 412.0 - 390 = 22. At this scale the bar is the ONLY thing on the
      expect(errors, <String>[
        'A RenderFlex overflowed by 22 pixels on the right.',
      ]);
    });

    testWidgets('the first horizontal break is ENGLISH, not Arabic', (
      WidgetTester tester,
    ) async {
      // Worth stating explicitly because it inverts the habit: on most Jeeb
      Future<double> intrinsicAt(double scale, Locale locale) async {
        await _errorsAt(
          tester,
          shellScreenCompactDevice,
          size: const Size(390, 844),
          textScale: scale,
          locale: locale,
        );
        return _barIntrinsicWidth(tester);
      }

      expect(await intrinsicAt(2.0, const Locale('en')),
          closeTo(barWidthEn200, 1.0));
      expect(await intrinsicAt(2.0, const Locale('ar')),
          closeTo(barWidthAr200, 1.0));

      // The 390 dp phone: English overruns it, Arabic does not.
      expect(barWidthEn200, greaterThan(390));
      expect(barWidthAr200, lessThan(390));
      // The 320 dp device: both overrun it, English by nearly seven times as
      expect(barWidthEn200 - 320, closeTo(149.7, 1.0));
      expect(barWidthAr200 - 320, closeTo(22.1, 1.0));
    });

    testWidgets('a 320 pt device breaks at 150% — a setting users reach', (
      WidgetTester tester,
    ) async {
      // Android's "Largest" font size and iOS's larger accessibility sizes both
      final List<String> errors = await _errorsAt(
        tester,
        shellScreenCompactDevice,
        size: const Size(320, 568),
        textScale: 1.5,
      );

      expect(_barIntrinsicWidth(tester), closeTo(354.3, 1.0));
      expect(
        errors,
        contains('A RenderFlex overflowed by 34 pixels on the right.'),
      );
      // …and the same frame in Arabic is completely clean, on the same device.
      final List<String> arabic = await _errorsAt(
        tester,
        shellScreenCompactDevice,
        size: const Size(320, 568),
        textScale: 1.5,
        locale: const Locale('ar'),
      );
      expect(arabic, isEmpty);
    });
  });
}
