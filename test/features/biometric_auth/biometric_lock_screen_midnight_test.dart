// M3-35 · biometric-unlock derived from R7 "OTP verify" — per-element MIDNIGHT
// assertions.
//
// Goldens tolerate 5% pixel diff, so a headline re-inked from `onSurface` to
// `primary` (which IS #D73B00 on Midnight) moves far too few pixels to fail
// one. Everything here reads the colour/variant/geometry off the widget.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_midnight_palette.dart';
import 'package:jeeb_mobile/core/theme/jeeb_radii.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_glass_card.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_info_note.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/biometric_lock_screen_fixtures.dart';
import 'package:jeeb_mobile/features/biometric_auth/application/biometric_lock_cubit.dart';
import 'package:jeeb_mobile/features/biometric_auth/presentation/biometric_lock_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// Carries `/register`, the one named route the password fallback targets.
Widget _harness(
  BiometricLockCubit cubit, {
  Locale? locale,
  double textScale = 1,
}) {
  final GoRouter router = GoRouter(
    initialLocation: '/lock',
    routes: <RouteBase>[
      GoRoute(path: '/lock', builder: (_, _) => const BiometricLockScreen()),
      GoRoute(
        name: 'register',
        path: '/register',
        builder: (_, _) => const Scaffold(body: Text('REGISTER')),
      ),
    ],
  );
  addTearDown(router.dispose);
  return BlocProvider<BiometricLockCubit>.value(
    value: cubit,
    child: MaterialApp.router(
      theme: AppTheme.midnight(),
      routerConfig: router,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object?>>[
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
    ),
  );
}

Future<BiometricLockCubit> _pump(
  WidgetTester tester,
  BiometricLockCubit Function() create,
) async {
  final BiometricLockCubit cubit = create();
  addTearDown(cubit.close);
  await tester.pumpWidget(_harness(cubit));
  await tester.pump();
  return cubit;
}

void main() {
  final JeebSemanticColors midnight = JeebSemanticColors.midnight();

  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final view = binding.platformDispatcher.views.first;
    // The board canvas, so a capture and a design frame line up unrescaled.
    view.physicalSize = const Size(440, 956);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });

  ColorScheme schemeOf(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(JeebMidnightField))).colorScheme;

  AppLocalizations l10nOf(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(JeebMidnightField)));

  group('M3-35 field — R7s measured anchor', () {
    testWidgets(
        'mounts one still CONTENT field with the PERIWINKLE wash top-start and '
        'no orange glow at all', (tester) async {
      await _pump(tester, biometricLockScreenLockedCubit);

      final Finder finder = find.byType(JeebMidnightField);
      expect(finder, findsOneWidget, reason: 'one field, not one per band');
      final JeebMidnightField field = tester.widget<JeebMidnightField>(finder);

      expect(field.variant, JeebFieldVariant.content);
      expect(field.washPlacement, JeebFieldWashPlacement.topStart);
      // Wave-D: a least-squares fit finds NO orange radial in R7's field.
      expect(field.glowColor, Colors.transparent);
      // M3 standing ruling: no motion beyond what kit widgets animate.
      expect(field.animateDecor, isFalse);
    });

    testWidgets('the Scaffold is transparent so the field is what paints',
        (tester) async {
      await _pump(tester, biometricLockScreenLockedCubit);

      final Scaffold scaffold =
          tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, Colors.transparent);
      expect(scaffold.appBar, isNull, reason: 'a gate offers no BACK');
    });
  });

  // M6 L14: the screen used to set a raw `SystemUiOverlayStyle.light` with a
  // transparent nav bar; raw `.light` carries a BLACK one.
  group('M6 L14 system bands', () {
    testWidgets('takes the ratified overlay style, not raw .light',
        (tester) async {
      final BiometricLockCubit cubit = biometricLockScreenLockedCubit();
      addTearDown(cubit.close);
      await tester.pumpWidget(_harness(cubit));
      await tester.pump();

      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.ancestor(
          of: find.byType(JeebMidnightField),
          matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
        ),
      );
      expect(region.value, AppTheme.systemOverlayStyle);
      expect(region.value.systemNavigationBarColor, JeebMidnight.page);
      expect(
        region.value.systemNavigationBarColor,
        isNot(SystemUiOverlayStyle.light.systemNavigationBarColor),
      );
      expect(region.value.statusBarIconBrightness, Brightness.light);
    });
  });

  group('M3-35 the hero mark', () {
    testWidgets(
        'is the §4 HERO glass recipe on a 118 disc — the pass-1 hand-rolled '
        '.10/.18 alphas snapped to their ladder rungs', (tester) async {
      await _pump(tester, biometricLockScreenLockedCubit);

      final Finder finder = find.byType(JeebGlassCapsule);
      expect(finder, findsOneWidget, reason: '§4 budget: hero surfaces only');
      final JeebGlassCapsule capsule = tester.widget<JeebGlassCapsule>(finder);
      expect(capsule.radius, JeebRadii.pill, reason: 'a disc, not a card');
      expect(capsule.blurSigma, JeebGlassCapsule.standardBlur);

      final SizedBox box = tester.widget<SizedBox>(
        find.ancestor(of: finder, matching: find.byType(SizedBox)).first,
      );
      expect(box.width, 118);
      expect(box.height, 118);

      final DecoratedBox surface = tester.widget<DecoratedBox>(
        find
            .descendant(of: finder, matching: find.byType(DecoratedBox))
            .last,
      );
      final BoxDecoration decoration = surface.decoration as BoxDecoration;
      expect(decoration.color, midnight.glassFillEmphasis);
      expect(decoration.border!.top.color, midnight.glassBorderStrong);
      expect(decoration.color, isNot(midnight.glassFill));
    });

    testWidgets('the fingerprint glyph reads onSurface, never onPrimary',
        (tester) async {
      await _pump(tester, biometricLockScreenLockedCubit);
      final ColorScheme scheme = schemeOf(tester);

      final Icon mark = tester.widget<Icon>(find.byIcon(Icons.fingerprint));
      expect(mark.color, scheme.onSurface);
      // Wave-B: `onSurface` #EDEFFC is the ink app-wide; #FFFFFF is orange-fill
      // ink and does not get re-homed onto glass.
      expect(mark.color, isNot(scheme.onPrimary));
    });
  });

  group('M3-35 orange budget', () {
    testWidgets(
        'GUARD: not one Text is inked colorScheme.primary — which IS #D73B00 '
        'under Midnight (pass-1 inked the headline with it)', (tester) async {
      await _pump(tester, biometricLockScreenFailedCubit);
      final ColorScheme scheme = schemeOf(tester);

      for (final Text text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.style?.color, isNot(scheme.primary));
      }
    });

    testWidgets(
        'GUARD: the screen paints no orange décor of its own — the two '
        'hand-painted accent rings are gone', (tester) async {
      await _pump(tester, biometricLockScreenLockedCubit);
      final ColorScheme scheme = schemeOf(tester);

      for (final Icon icon in tester.widgetList<Icon>(find.byType(Icon))) {
        expect(icon.color, isNot(scheme.primary));
      }
      for (final CustomPaint paint
          in tester.widgetList<CustomPaint>(find.byType(CustomPaint))) {
        expect(
          paint.painter.runtimeType.toString(),
          isNot(contains('AccentRings')),
        );
      }
    });
  });

  group('M3-35 the copy block', () {
    testWidgets('headline reads onSurface at the h1 rung', (tester) async {
      await _pump(tester, biometricLockScreenLockedCubit);
      final ColorScheme scheme = schemeOf(tester);
      final AppLocalizations l10n = l10nOf(tester);

      final Text headline =
          tester.widget<Text>(find.text(l10n.biometricUnlockTitle));
      expect(headline.style!.color, scheme.onSurface);
      expect(headline.style!.color, isNot(scheme.primary));
      // §6: h1 is 26/w700/−0.6 and ships the tracking itself.
      expect(headline.style!.fontSize, 26);
      expect(headline.style!.letterSpacing, -0.6);
      expect(headline.textAlign, TextAlign.center);
    });

    testWidgets('body reads the muted rung #8A93D8', (tester) async {
      await _pump(tester, biometricLockScreenLockedCubit);
      final AppLocalizations l10n = l10nOf(tester);

      final Text body = tester.widget<Text>(find.text(l10n.biometricLockBody));
      expect(body.style!.color, midnight.mutedText);
      expect(body.style!.fontSize, 14.5);
    });
  });

  group('M3-35 the three cubit states', () {
    testWidgets('LOCKED — the default: no in-flight line, no failure note',
        (tester) async {
      await _pump(tester, biometricLockScreenLockedCubit);
      final AppLocalizations l10n = l10nOf(tester);

      expect(find.byKey(const Key('biometricLock.promptingLine')), findsNothing);
      expect(find.byType(JeebInfoNote), findsNothing);

      final JeebCtaButton cta = tester.widget<JeebCtaButton>(
        find.descendant(
          of: find.bySemanticsIdentifier('biometric_unlock_authenticate_cta'),
          matching: find.byType(JeebCtaButton),
        ),
      );
      expect(cta.label, l10n.biometricUnlockAuthenticateCta);
      expect(cta.isEnabled, isTrue);
    });

    testWidgets(
        'PROMPTING — the loading form: R7 speaks the in-flight round trip as a '
        'bodySmall line, not a spinner, and the CTA goes dead', (tester) async {
      await _pump(tester, biometricLockScreenPromptingCubit);
      final AppLocalizations l10n = l10nOf(tester);

      final Finder line = find.byKey(const Key('biometricLock.promptingLine'));
      expect(line, findsOneWidget);
      final Text prompting = tester.widget<Text>(line);
      expect(prompting.data, l10n.biometricLockPrompting);
      expect(prompting.style!.color, midnight.mutedText);
      expect(prompting.style!.fontSize, 12.5, reason: '§6 bodySmall');

      final JeebCtaButton cta = tester.widget<JeebCtaButton>(
        find.descendant(
          of: find.bySemanticsIdentifier('biometric_unlock_authenticate_cta'),
          matching: find.byType(JeebCtaButton),
        ),
      );
      expect(cta.isEnabled, isFalse);
      expect(find.byType(JeebInfoNote), findsNothing);
    });

    testWidgets(
        'FAILED — the error form: the kit error note plus the retry label',
        (tester) async {
      await _pump(tester, biometricLockScreenFailedCubit);
      final ColorScheme scheme = schemeOf(tester);
      final AppLocalizations l10n = l10nOf(tester);

      final JeebInfoNote note =
          tester.widget<JeebInfoNote>(find.byType(JeebInfoNote));
      expect(note.tone, JeebInfoNoteTone.error);
      expect(note.text, l10n.biometricLockFailure);

      final Text failure =
          tester.widget<Text>(find.text(l10n.biometricLockFailure));
      // R22: negative COPY is danger-SOFT #FF7B7B, not the #FF5252 solid.
      expect(failure.style!.color, scheme.onErrorContainer);
      expect(failure.style!.color, isNot(scheme.error));

      final JeebCtaButton cta = tester.widget<JeebCtaButton>(
        find.descendant(
          of: find.bySemanticsIdentifier('biometric_unlock_authenticate_cta'),
          matching: find.byType(JeebCtaButton),
        ),
      );
      expect(cta.label, l10n.biometricLockRetry);
      expect(cta.isEnabled, isTrue, reason: 'a failure must be retryable');
      expect(find.byKey(const Key('biometricLock.promptingLine')), findsNothing);
    });
  });

  group('M3-35 the two affordances', () {
    testWidgets(
        'the unlock pill is PERIWINKLE and the fallback is the bare text rung',
        (tester) async {
      await _pump(tester, biometricLockScreenLockedCubit);

      final JeebCtaButton unlock = tester.widget<JeebCtaButton>(
        find.descendant(
          of: find.bySemanticsIdentifier('biometric_unlock_authenticate_cta'),
          matching: find.byType(JeebCtaButton),
        ),
      );
      expect(unlock.variant, JeebCtaVariant.primary);
      expect(unlock.variant, isNot(JeebCtaVariant.accent));

      final JeebCtaButton fallback = tester.widget<JeebCtaButton>(
        find.descendant(
          of: find.bySemanticsIdentifier('biometric_unlock_use_password_link'),
          matching: find.byType(JeebCtaButton),
        ),
      );
      expect(fallback.variant, JeebCtaVariant.text);
    });

    testWidgets('the three frozen identifiers survive in every state',
        (tester) async {
      for (final BiometricLockCubit Function() create
          in <BiometricLockCubit Function()>[
        biometricLockScreenLockedCubit,
        biometricLockScreenPromptingCubit,
        biometricLockScreenFailedCubit,
      ]) {
        await _pump(tester, create);
        expect(
          find.bySemanticsIdentifier('biometric_unlock_prompt'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('biometric_unlock_authenticate_cta'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('biometric_unlock_use_password_link'),
          findsOneWidget,
        );
      }
    });

    testWidgets('AC3 still releases the gate and lands on /register',
        (tester) async {
      final BiometricLockCubit cubit =
          await _pump(tester, biometricLockScreenLockedCubit);

      await tester.tap(
        find.bySemanticsIdentifier('biometric_unlock_use_password_link'),
      );
      await tester.pumpAndSettle();

      expect(cubit.state.isUnlocked, isTrue);
      expect(find.text('REGISTER'), findsOneWidget);
    });
  });

  group('M3-35 layout', () {
    testWidgets('runs the token sheets 24px gutter, directionally',
        (tester) async {
      await _pump(tester, biometricLockScreenLockedCubit);

      final Iterable<Padding> gutters = tester
          .widgetList<Padding>(
            find.ancestor(
              of: find.text(l10nOf(tester).biometricUnlockTitle),
              matching: find.byType(Padding),
            ),
          )
          .where((Padding p) => p.padding is EdgeInsetsDirectional);
      expect(gutters, isNotEmpty, reason: 'never a bare EdgeInsets: RTL');
      final EdgeInsetsDirectional pad =
          gutters.first.padding as EdgeInsetsDirectional;
      expect(pad.start, 24);
      expect(pad.end, 24);
    });

    testWidgets('lays out under Arabic at 200% on the smallest canvas',
        (tester) async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      final view = binding.platformDispatcher.views.first;
      view.physicalSize = const Size(320, 480);
      view.devicePixelRatio = 1.0;

      final BiometricLockCubit cubit = biometricLockScreenFailedCubit();
      addTearDown(cubit.close);
      await tester.pumpWidget(
        _harness(cubit, locale: const Locale('ar'), textScale: 2),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        Directionality.of(tester.element(find.byType(JeebMidnightField))),
        TextDirection.rtl,
      );
    });
  });
}
