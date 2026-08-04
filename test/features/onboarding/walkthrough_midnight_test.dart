import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/motion/jeeb_motion.dart';
import 'package:jeeb_mobile/core/onboarding/onboarding_cubit.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_radii.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/features/onboarding/presentation/onboarding_screen.dart';

import '../../support/sync_app_localizations.dart';

/// MIDNIGHT paint evidence for M2-21: every assertion reads the actual colour,
/// geometry or variant off the widget, because the golden comparator tolerates
/// 5% pixel diff and a token re-point on a small element is invisible to it.
void main() {
  late SharedPreferences prefs;
  late OnboardingCubit cubit;
  late LocaleCubit localeCubit;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    cubit = OnboardingCubit(prefs: prefs);
    localeCubit = LocaleCubit(
      prefs: prefs,
      deviceLocaleProvider: () => const Locale('en'),
    );
  });

  tearDown(() async {
    await cubit.close();
    await localeCubit.close();
  });

  Widget harness({Locale locale = const Locale('en')}) => wrapForTest(
    Builder(
      builder: (context) => MediaQuery(
        // 19 animated elements loop ∞ by design; reduce motion is the only way
        // a harness on this screen can settle.
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: Theme(
          data: AppTheme.midnight(),
          child: MultiBlocProvider(
            providers: [
              BlocProvider<OnboardingCubit>.value(value: cubit),
              BlocProvider<LocaleCubit>.value(value: localeCubit),
            ],
            child: OnboardingScreen(onComplete: () {}),
          ),
        ),
      ),
    ),
    locale: locale,
  );

  JeebMidnightField field(WidgetTester tester) =>
      tester.widget<JeebMidnightField>(find.byType(JeebMidnightField));

  Future<void> advance(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('onboarding.next')));
    await tester.pumpAndSettle();
  }

  group('field — the radial is per tile, and a wash is not a glow', () {
    testWidgets('W1 draws an ORANGE glow at centre-upper', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pump();

      final f = field(tester);
      expect(f.glowPlacement, JeebFieldGlowPlacement.centerUpper);
      expect(f.variant, JeebFieldVariant.content);
      final scheme = AppTheme.midnight().colorScheme;
      expect(f.glowColor, scheme.primary.withValues(alpha: 0.28));
      // The tiles draw their own rings inside the art.
      expect(f.showRings, isFalse);
      expect(f.showTwinkles, isFalse);
    });

    testWidgets('W2 draws a PERIWINKLE wash and declares zero orange', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      await tester.pump();
      await advance(tester);

      final scheme = AppTheme.midnight().colorScheme;
      final glow = field(tester).glowColor!;
      expect(
        glow,
        scheme.secondary.withValues(alpha: 0.22),
        reason: 'W2 declares rgba(119,127,192,.28) and no orange radial at all',
      );
      expect(
        glow.r,
        lessThan(glow.b),
        reason: 'a wash is blue-dominant; an orange glow is red-dominant',
      );
    });

    testWidgets('W3 draws no radial at all under its night map', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      await tester.pump();
      await advance(tester);
      await advance(tester);

      expect(field(tester).glowColor!.a, 0);
    });
  });

  group('sheet — a frosted navy panel, not a flat white one', () {
    testWidgets('fills surface at 70% behind an outline hairline', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      await tester.pump();

      final scheme = AppTheme.midnight().colorScheme;
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(BackdropFilter),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, scheme.surface.withValues(alpha: 0.7));
      expect((decoration.border! as BorderDirectional).top.color,
          scheme.outline);
      expect(
        decoration.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(JeebRadii.hero)),
      );
    });

    testWidgets('spends exactly ONE real BackdropFilter (§4 budget ≤2)', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      await tester.pump();

      expect(find.byType(BackdropFilter), findsOneWidget);
      final blur = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
      expect(blur.filter, isA<ui.ImageFilter>());
    });

    testWidgets('nothing in the sheet moves', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pump();

      final sheet = find.byType(BackdropFilter);
      for (final matcher in <Finder>[
        find.byType(JFloat),
        find.byType(JBreathe),
        find.byType(JTwinkle),
        find.byType(JArcPulse),
        find.byType(JHalo),
        find.byType(JWaveBar),
        find.byType(JBlink),
      ]) {
        expect(
          find.descendant(of: sheet, matching: matcher),
          findsNothing,
          reason: 'the eyebrow, headline, dots and CTAs are all still',
        );
      }
    });
  });

  group('CTA + toggle', () {
    testWidgets('Next is the ORANGE accent pill with a mirroring arrow', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      await tester.pump();

      final cta = tester.widget<JeebCtaButton>(
        find.byKey(const Key('onboarding.next')),
      );
      expect(cta.variant, JeebCtaVariant.accent);
      expect(cta.trailingIcon, Icons.arrow_forward);
      expect(cta.mirrorIcons, isTrue);
    });

    testWidgets('Get Started drops the arrow on the last slide', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      await tester.pump();
      await advance(tester);
      await advance(tester);

      final cta = tester.widget<JeebCtaButton>(
        find.byKey(const Key('onboarding.getStarted')),
      );
      expect(cta.variant, JeebCtaVariant.accent);
      expect(cta.trailingIcon, isNull);
    });

    testWidgets('the selected language pill is a NAVY knockout on white', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      await tester.pump();

      final scheme = AppTheme.midnight().colorScheme;
      final pill = tester.widget<AnimatedContainer>(
        find
            .ancestor(
              of: find.text('EN'),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      expect((pill.decoration! as BoxDecoration).color, scheme.onSurface);
      final label = tester.widget<Text>(find.text('EN'));
      expect(
        label.style!.color,
        scheme.surface,
        reason: 'the pre-Midnight ink resolved to ORANGE once primary flipped',
      );
      // The idle segment stays periwinkle.
      final idle = tester.widget<Text>(find.text('عربي'));
      expect(idle.style!.color, scheme.onSurfaceVariant);
    });
  });
}
