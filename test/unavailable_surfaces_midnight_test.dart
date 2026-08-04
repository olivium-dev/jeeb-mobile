// MIDNIGHT M3-39/40/41 — the three "this thing is not available" surfaces.
// None has a tile; all three derive from E4, whose caption reads "Empty ≠
// dead". These screens are the dead case, so they draw E4's box at ERROR
// status: the same composition, run on the danger ink instead of the accent.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/router/profile_unavailable_screen.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_top_bar.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/presentation/jeeber_request_unavailable_screen.dart';
import 'package:jeeb_mobile/features/request_summary/presentation/request_summary_unavailable_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'support/sync_app_localizations.dart';

/// Token sheet §1, spelled out rather than read off the implementation.
const Color _orange = Color(0xFFD73B00);
const Color _danger = Color(0xFFFF5252);

/// `_parcelGlowAlpha` — the alpha the kit gives E4's centre glow.
const double _glowAlpha = 0.22;

/// The three rows, by their report ids.
final Map<String, Widget> _screens = <String, Widget>{
  'M3-39 jeeber request': JeeberRequestUnavailableScreen(
    requestId: 'req-dead-001',
    onBack: () {},
  ),
  'M3-40 request summary': const RequestSummaryUnavailableScreen(),
  'M3-41 profile': const ProfileUnavailableScreen(),
};

/// Frozen QA hooks on the back circle — the block re-homing must not swallow
/// them, which is what the root `Semantics` container flags are guarding.
const Map<String, String> _backIdentifiers = <String, String>{
  'M3-39 jeeber request': 'jeeber_request_unavailable_back',
  'M3-40 request summary': 'request_summary_unavailable_back',
  'M3-41 profile': 'profile_unavailable_back',
};

void main() {
  // `disableAnimations` must ride the SAME MediaQuery the scale does: a nested
  // `MediaQueryData()` replaces the lot and the ∞ loops never settle.
  Widget harness(
    Widget screen, {
    Locale locale = const Locale('en'),
    double textScale = 1,
  }) =>
      MaterialApp(
        theme: AppTheme.midnight(),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          SyncAppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: TextScaler.linear(textScale),
            ),
            child: screen,
          ),
        ),
      );

  /// E4's centre glow is the one `RadialGradient` the parcel illustration
  /// builds as a widget; every other layer is a `CustomPaint`.
  Gradient parcelGlowOf(WidgetTester tester) {
    final Iterable<BoxDecoration> radial = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(JeebEmptyState),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((DecoratedBox box) => box.decoration)
        .whereType<BoxDecoration>()
        .where((BoxDecoration d) => d.gradient is RadialGradient);
    expect(radial, hasLength(1), reason: 'E4 draws exactly one centre glow');
    return radial.single.gradient!;
  }

  group('every unavailable surface lands on ONE treatment', () {
    _screens.forEach((String id, Widget screen) {
      testWidgets('$id · E4 box at error status on the content field',
          (WidgetTester tester) async {
        await tester.pumpWidget(harness(screen));
        await tester.pumpAndSettle();

        final JeebEmptyState state = tester.widget<JeebEmptyState>(
          find.byType(JeebEmptyState),
        );
        expect(state.variant, JeebEmptyStateVariant.parcel);
        expect(state.status, JeebEmptyStateStatus.error);

        final JeebMidnightField field = tester.widget<JeebMidnightField>(
          find.byType(JeebMidnightField),
        );
        expect(field.variant, JeebFieldVariant.content);
        expect(field.animateDecor, isFalse,
            reason: 'M3 ships no motion beyond what kit widgets animate');
        expect(field.washPlacement, isNull,
            reason: 'wash is PERIWINKLE and a separate layer — none of the '
                'three derives one');
      });

      testWidgets('$id · the dead-end illustration spends NO orange',
          (WidgetTester tester) async {
        await tester.pumpWidget(harness(screen));
        await tester.pumpAndSettle();

        final RadialGradient glow = parcelGlowOf(tester) as RadialGradient;
        expect(glow.colors.first, _danger.withValues(alpha: _glowAlpha),
            reason: 'error status re-inks E4 accent → colorScheme.error');
        expect(glow.colors.last, _danger.withValues(alpha: 0));
        for (final Color c in glow.colors) {
          expect(Color(c.toARGB32()).withValues(alpha: 1), isNot(_orange),
              reason: 'a surface with nothing to act on may not draw the '
                  'rationed accent (master plan §2.2)');
        }
      });

      testWidgets('$id · the headline prints exactly once, under a title-less '
          'back bar', (WidgetTester tester) async {
        await tester.pumpWidget(harness(screen));
        await tester.pumpAndSettle();

        final JeebEmptyState state = tester.widget<JeebEmptyState>(
          find.byType(JeebEmptyState),
        );
        expect(find.text(state.headline), findsOneWidget);
        expect(tester.widget<JeebTopBar>(find.byType(JeebTopBar)).title, isNull);
        expect(
          find.bySemanticsIdentifier(_backIdentifiers[id]!),
          findsOneWidget,
        );
      });

      testWidgets('$id · the block scrolls, so 200% text cannot overflow it',
          (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(harness(screen, textScale: 2));
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byType(JeebEmptyState),
            matching: find.byType(Scrollable),
          ),
          findsNothing,
          reason: 'the viewport is ABOVE the block, never inside it',
        );
        expect(find.byType(Scrollable), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('$id · mirrors under ar without overflowing',
          (WidgetTester tester) async {
        await tester.pumpWidget(harness(screen, locale: const Locale('ar')));
        await tester.pumpAndSettle();

        expect(
          Directionality.of(tester.element(find.byType(JeebEmptyState))),
          TextDirection.rtl,
        );
        expect(tester.takeException(), isNull);
      });
    });
  });

  testWidgets('the three read as ONE app: identical variant, status and field',
      (WidgetTester tester) async {
    final Set<Object?> shapes = <Object?>{};
    for (final Widget screen in _screens.values) {
      await tester.pumpWidget(harness(screen));
      await tester.pumpAndSettle();

      final JeebEmptyState state = tester.widget<JeebEmptyState>(
        find.byType(JeebEmptyState),
      );
      final JeebMidnightField field = tester.widget<JeebMidnightField>(
        find.byType(JeebMidnightField),
      );
      shapes.add(
        Object.hash(
          state.variant,
          state.status,
          field.variant,
          field.washPlacement,
          field.animateDecor,
        ),
      );
    }
    expect(shapes, hasLength(1),
        reason: 'M3-39/40/41 shipped three different apps; this pins the one '
            'treatment they now share');
  });
}
