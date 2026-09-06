import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/locale/language_preference_repository.dart';
import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/features/language/presentation/screens/language_settings_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'support/sync_app_localizations.dart';

/// MIDNIGHT token sheet §1/§3, the same constants
/// `test/core/widgets/jeeb/jeeb_segmented_toggle_test.dart` pins.
const Color _white = Color(0xFFFFFFFF);
const Color _navyInk = Color(0xFF0B1351);
const Color _inkSoft = Color(0xFFB9C0F0);

Widget _harness(LocaleCubit cubit) {
  return BlocProvider.value(
    value: cubit,
    child: BlocBuilder<LocaleCubit, Locale>(
      builder: (context, locale) => MaterialApp(
        // Midnight is the only scheme; an unthemed host renders Material's
        // default purple, which is what pinned the pre-Midnight assertions.
        theme: AppTheme.midnight(),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          SyncAppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const LanguageSettingsScreen(),
      ),
    ),
  );
}

/// The selected segment of a [JeebSegmentedToggle] is a **fill swap**, not a
/// trailing glyph (redesign-2026-08 §5 #19), so selection is read off the
/// segment's own [DecoratedBox] — the nearest one above its frozen key.
BoxDecoration _segmentDecoration(WidgetTester tester, Key key) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find
        .ancestor(of: find.byKey(key), matching: find.byType(DecoratedBox))
        .first,
  );
  return box.decoration as BoxDecoration;
}

/// The segment's own label style — the other half of the fill swap.
TextStyle _segmentTextStyle(WidgetTester tester, Key key) => tester
    .widget<Text>(
      find.descendant(of: find.byKey(key), matching: find.byType(Text)),
    )
    .style!;

/// Asserts the ratified Midnight segmented-active treatment: the selected pill
/// is a WHITE fill with navy w700 ink, the other stays transparent with
/// `inkSoft` w600 (kit ruling 3 / token sheet §1, §3). It is deliberately NOT
/// `colorScheme.primary` — under Midnight that slot is the `#D73B00` CTA
/// orange, and spending it on a language switch is an orange-budget leak.
void _expectMidnightSelection(
  WidgetTester tester, {
  required Key selected,
  required Key unselected,
}) {
  expect(_segmentDecoration(tester, selected).color, _white);
  expect(_segmentTextStyle(tester, selected).color, _navyInk);
  expect(_segmentTextStyle(tester, selected).fontWeight, FontWeight.w700);

  expect(_segmentDecoration(tester, unselected).color, Colors.transparent);
  expect(_segmentTextStyle(tester, unselected).color, _inkSoft);
  expect(_segmentTextStyle(tester, unselected).fontWeight, FontWeight.w600);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('renders both language segments with the active one filled',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final cubit = LocaleCubit(
      prefs: prefs,
      deviceLocaleProvider: () => const Locale('en'),
    );

    await tester.pumpWidget(_harness(cubit));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('language-row-en')), findsOneWidget);
    expect(find.byKey(const Key('language-row-ar')), findsOneWidget);

    _expectMidnightSelection(
      tester,
      selected: const Key('language-row-en'),
      unselected: const Key('language-row-ar'),
    );
  });

  testWidgets('tapping Arabic flips strings, RTL, and persists the choice',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final cubit = LocaleCubit(
      prefs: prefs,
      deviceLocaleProvider: () => const Locale('en'),
    );

    await tester.pumpWidget(_harness(cubit));
    await tester.pumpAndSettle();

    // Sanity: starts in English, LTR.
    expect(find.text('Language'), findsWidgets);

    await tester.tap(find.byKey(const Key('language-row-ar')));
    await tester.pumpAndSettle();

    // Strings are now Arabic and the directionality is RTL.
    expect(find.text('اللغة'), findsWidgets);
    final direction = Directionality.of(
      tester.element(find.byKey(const Key('language-settings-list'))),
    );
    expect(direction, TextDirection.rtl);

    // Persistence: the cubit wrote the choice to shared_preferences so the
    // next cold start picks it up (verified separately in
    // locale_switching_test.dart's "Persisted locale wins over device locale"
    // case).
    expect(prefs.getString('app.locale.languageCode'), 'ar');

    // The white fill moved to the Arabic segment.
    _expectMidnightSelection(
      tester,
      selected: const Key('language-row-ar'),
      unselected: const Key('language-row-en'),
    );
  });

  testWidgets('tapping the already-selected language is a no-op',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final cubit = LocaleCubit(
      prefs: prefs,
      deviceLocaleProvider: () => const Locale('en'),
    );

    await tester.pumpWidget(_harness(cubit));
    await tester.pumpAndSettle();

    final localeBefore = cubit.state;
    await tester.tap(find.byKey(const Key('language-row-en')));
    await tester.pump();

    // No emission means no state change — the cubit reference is stable.
    expect(identical(cubit.state, localeBefore), isTrue);
    // The pref must not have been written either — re-tapping English when it
    // was the device fallback would otherwise clobber resetToDeviceLocale's
    // contract.
    expect(prefs.getString('app.locale.languageCode'), isNull);
  });

  testWidgets('mounts R22\'s content field: orange glow topEnd, board-still',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final cubit = LocaleCubit(
      prefs: prefs,
      deviceLocaleProvider: () => const Locale('en'),
    );

    await tester.pumpWidget(_harness(cubit));
    await tester.pumpAndSettle();

    final JeebMidnightField field = tester.widget<JeebMidnightField>(
      find.byType(JeebMidnightField),
    );
    expect(field.variant, JeebFieldVariant.content);
    // R22 declares `radial-gradient(480px 380px at 88% -6%)` and NO periwinkle
    // wash, so the orange glow anchors topEnd and no wash layer is requested.
    expect(field.glowPlacement, JeebFieldGlowPlacement.topEnd);
    expect(field.washPlacement, isNull);
    expect(field.animateDecor, isFalse);

    // The field is the background; a painted Scaffold would cover it.
    final Scaffold scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, Colors.transparent);
  });

  // LANG-01: a local switch the server has not caught up with must say so —
  // the alternative is a silent drift the user cannot see or act on.
  group('the pending-push note', () {
    testWidgets('is absent while the remote copy is in step', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final LocaleCubit cubit = LocaleCubit(
        prefs: await SharedPreferences.getInstance(),
        deviceLocaleProvider: () => const Locale('en'),
        remote: _PushFailingRemote(fail: false),
      );
      addTearDown(cubit.close);

      await tester.pumpWidget(_harness(cubit));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('language_sync_pending_note'),
        findsNothing,
      );
    });

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('renders after a failed push (${locale.languageCode})',
          (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final LocaleCubit cubit = LocaleCubit(
          prefs: await SharedPreferences.getInstance(),
          deviceLocaleProvider: () => locale,
          remote: _PushFailingRemote(fail: true),
        );
        addTearDown(cubit.close);

        await tester.pumpWidget(_harness(cubit));
        await tester.pumpAndSettle();

        await cubit.setLocale(
          Locale(locale.languageCode == 'ar' ? 'en' : 'ar'),
        );
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsIdentifier('language_sync_pending_note'),
          findsOneWidget,
        );
      });
    }
  });
}

/// A remote whose `save` fails on demand, so the pending flag can be driven.
class _PushFailingRemote implements LanguagePreferenceRepository {
  _PushFailingRemote({required this.fail});

  final bool fail;

  @override
  Future<String?> fetch() async => null;

  @override
  Future<void> save(String languageCode) async {
    if (fail) {
      throw const LanguagePreferenceException(
        LanguagePreferenceFailure.network,
      );
    }
  }
}
