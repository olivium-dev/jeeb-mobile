// MIDNIGHT R22 adoption instruments.
//
// Goldens are blind to a token re-point (the comparator tolerates 5% pixel
// diff), so every value this row moved is read back off the built widget here.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/diagnostics/diag.dart';
import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_accent_frame_card.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_navy_surface_card.dart';
import 'package:jeeb_mobile/features/settings/application/settings_cubit.dart';
import 'package:jeeb_mobile/features/settings/presentation/screens/settings_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/load_test_fonts.dart';
import '../../support/settings_fakes.dart';
import '../../support/sync_app_localizations.dart';

/// The board's own canvas — the fold assertion is only meaningful on it.
const Size _kCanvas = Size(440, 956);

const Key _kOffersRow = Key('settings-row-notifications-offers');
const Key _kStatusRow = Key('settings-row-notifications-status');

Widget _harness(SharedPreferences prefs, SettingsCubit cubit) {
  return BlocProvider(
    create: (_) => LocaleCubit(
      prefs: prefs,
      deviceLocaleProvider: () => const Locale('en'),
    ),
    child: MaterialApp(
      // Real faces: the default test font is monospaced squares, which inflates
      // every text run and makes the fold measurement meaningless.
      theme: withCaptureTestFonts(AppTheme.midnight()),
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object?>>[
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: SettingsScreen(cubit: cubit, appVersion: '1.2.3'),
    ),
  );
}

/// The toggle track: the only rounded-rectangle `DecoratedBox` in a switch row
/// (the knob is a circle), so this cannot silently match the wrong box.
BoxDecoration _track(WidgetTester tester, Key rowKey) {
  final Finder finder = find.descendant(
    of: find.byKey(rowKey),
    matching: find.byWidgetPredicate((Widget w) {
      if (w is! DecoratedBox) return false;
      final Decoration d = w.decoration;
      return d is BoxDecoration && d.borderRadius == OmdsBorderRadius.pill;
    }),
  );
  expect(finder, findsOneWidget);
  return tester.widget<DecoratedBox>(finder).decoration as BoxDecoration;
}

void main() {
  setUpAll(loadCatalogCaptureFonts);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<SettingsCubit> loadedCubit() async {
    final SettingsCubit cubit = SettingsCubit(
      profileRepository: InMemoryProfileRepository(),
      accountService: const FakeAccountService(),
      fallbackPhoneE164: '+96170100200',
    );
    await cubit.load();
    return cubit;
  }

  Future<BuildContext> pumpScreen(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(_kCanvas);
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final SettingsCubit cubit = await loadedCubit();
    addTearDown(cubit.close);
    await tester.pumpWidget(_harness(prefs, cubit));
    // No timeout override: R22 is a board-still tile, so if anything on this
    // screen loops forever this call is what fails.
    await tester.pumpAndSettle();
    return tester.element(find.byKey(const Key('settings-screen-list')));
  }

  testWidgets('field is the content variant, orange glow top-end, no wash',
      (WidgetTester tester) async {
    await pumpScreen(tester);

    final JeebMidnightField field =
        tester.widget<JeebMidnightField>(find.byType(JeebMidnightField));
    expect(field.variant, JeebFieldVariant.content);
    // `radial-gradient(480px 380px at 88% -6%)` — the tile's only radial.
    expect(field.glowPlacement, JeebFieldGlowPlacement.topEnd);
    // R22 declares zero periwinkle: a wash here would paint a layer the tile
    // does not draw.
    expect(field.washPlacement, isNull);
  });

  testWidgets('identity card is emphasis glass with no lift',
      (WidgetTester tester) async {
    final BuildContext context = await pumpScreen(tester);

    final JeebNavySurfaceCard card = tester.widget<JeebNavySurfaceCard>(
      find.byKey(const Key('settings-row-profile')),
    );
    // The legacy navy-tinted `ctaNavy` shadow is retired (sheet §7); the board
    // draws no box-shadow on this card at all.
    expect(card.shadow, isEmpty);

    final Icon chevron = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('settings-row-profile')),
        matching: find.byType(Icon),
      ),
    );
    expect(
      chevron.color,
      Theme.of(context).extension<JeebSemanticColors>()!.mutedText,
      reason: 'board tpl 1360 fills the chevron #8A93D8, not white@.7',
    );
  });

  testWidgets('Become-a-Jeeber is the one lit frame: accent-tinted fill',
      (WidgetTester tester) async {
    await pumpScreen(tester);

    final JeebAccentFrameCard frame = tester.widget<JeebAccentFrameCard>(
      find.byKey(const Key('settings-row-become-jeeber')),
    );
    // `background: rgba(215,59,0,.1)` (tpl 1362) — glass would be white 7%.
    expect(frame.fill, JeebAccentFrameFill.accentTint);
  });

  testWidgets('an ON toggle is orange and glows; OFF is glass',
      (WidgetTester tester) async {
    final BuildContext context = await pumpScreen(tester);
    final JeebRoles roles = context.jeebRoles;
    final JeebSemanticColors semantics =
        Theme.of(context).extension<JeebSemanticColors>()!;

    final BoxDecoration on = _track(tester, _kOffersRow);
    expect(on.color, roles.accent);
    expect(on.boxShadow, hasLength(1));
    // `0 0 12px rgba(215,59,0,.5)` (tpl 1382).
    expect(on.boxShadow!.single.blurRadius, 12);
    expect(on.boxShadow!.single.color, roles.accent.withValues(alpha: 0.5));

    // Every category ships ON, so the OFF track has to be produced.
    await tester.tap(find.byKey(_kStatusRow));
    await tester.pumpAndSettle();
    final BoxDecoration off = _track(tester, _kStatusRow);
    expect(off.color, semantics.glassFillPressed);
    expect(off.boxShadow, isEmpty);

    // 46×26 — Material's Switch draws 52×32 and cannot reach either value.
    expect(
      tester.getSize(
        find.descendant(
          of: find.byKey(_kOffersRow),
          matching: find.byWidgetPredicate(
            (Widget w) =>
                w is DecoratedBox &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).borderRadius ==
                    OmdsBorderRadius.pill,
          ),
        ),
      ),
      const Size(46, 26),
    );
  });

  testWidgets('destructive stays dim red — danger-soft, not full error',
      (WidgetTester tester) async {
    final BuildContext context = await pumpScreen(tester);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final TextButton button = tester.widget<TextButton>(
      find.byKey(const Key('settings-row-delete-account')),
    );
    final Color? ink =
        button.style!.foregroundColor!.resolve(<WidgetState>{});
    // `#FF7B7B` (tpl 1407), the board's danger-SOFT.
    expect(ink, scheme.onErrorContainer);
    expect(ink, isNot(scheme.error));
  });

  testWidgets('doc-13 P1: the MORE band no longer eats the empty band',
      (WidgetTester tester) async {
    // The shipped shape. `Diag.enabled` is `kDebugMode`, so a debug build adds
    // a fourth dev-only row no release user ever sees (22dp of scroll).
    Diag.enabledOverride = false;
    addTearDown(() => Diag.enabledOverride = null);
    await pumpScreen(tester);

    final ScrollableState scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const Key('settings-screen-list')),
        matching: find.byType(Scrollable),
      ),
    );
    // F11 added the device-only note + the manage row, so the band no longer
    // measures exactly zero — but it must stay a band, not a scrolled page:
    // less than one row's worth of overflow.
    expect(scrollable.position.maxScrollExtent, lessThan(120));
  });
}
