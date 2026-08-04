// MIDNIGHT M3-19/20 — neither the offer-KYC gate nor its register prompt has a
// tile. Every assertion below traces to R23 (become-a-jeeber: the funnel chrome
// both screens wear, and the screen `gate_start_kyc_cta` lands on) or to a
// ratified token-sheet value, never to taste.
//
// Read per element, not off a golden: the golden comparator tolerates 5%, which
// is more than either screen's whole orange budget.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_shadows.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_info_note.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/offer_kyc_gate_screen_fixtures.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_submission.dart';
import 'package:jeeb_mobile/features/offer_kyc_gate/presentation/delivery_register_prompt_screen.dart';
import 'package:jeeb_mobile/features/offer_kyc_gate/presentation/offer_kyc_gate_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// Token sheet §1/§3, spelled out rather than read back off the theme.
const Color _orange = Color(0xFFD73B00);
const Color _periwinkle = Color(0xFF8A93D8);
const Color _ink = Color(0xFFEDEFFC);

void main() {
  Widget host(Widget screen, {Locale locale = const Locale('en')}) =>
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
        home: screen,
      );

  Widget gate({
    KycStatus status = KycStatus.notSubmitted,
    Locale locale = const Locale('en'),
  }) => host(
    OfferKycGateScreen(gateway: OfferKycGateScreenFakeGateway(status: status)),
    locale: locale,
  );

  Widget loadingGate() => host(
    const OfferKycGateScreen(gateway: OfferKycGateScreenPendingGateway()),
  );

  Widget failedGate() => host(
    const OfferKycGateScreen(gateway: OfferKycGateScreenFailingGateway()),
  );

  Widget prompt({Locale locale = const Locale('en')}) =>
      host(const DeliveryRegisterPromptScreen(), locale: locale);

  BoxDecoration decorationOf(WidgetTester tester, Finder button) =>
      tester
              .widget<DecoratedBox>(
                find.descendant(of: button, matching: find.byType(DecoratedBox)).first,
              )
              .decoration
          as BoxDecoration;

  Finder ctaFor(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(JeebCtaButton));

  JeebMidnightField fieldOf(WidgetTester tester) =>
      tester.widget<JeebMidnightField>(find.byType(JeebMidnightField));

  group('field — R23, carried identically by both screens', () {
    for (final (String name, Widget Function() build) in <(
      String,
      Widget Function(),
    )>[('gate', gate), ('register prompt', prompt)]) {
      testWidgets('$name: content variant, ONE orange glow at the top end',
          (tester) async {
        await tester.pumpWidget(build());
        await tester.pumpAndSettle();

        final field = fieldOf(tester);
        expect(field.variant, JeebFieldVariant.content);
        expect(
          field.glowPlacement,
          JeebFieldGlowPlacement.topEnd,
          reason: 'wave-C lists R23 in the top-END class; topStart is the '
              'R4/R9/R17 anchor and would mirror the bloom',
        );
      });

      testWidgets('$name: NO periwinkle wash — R23 declares none',
          (tester) async {
        await tester.pumpWidget(build());
        await tester.pumpAndSettle();

        expect(
          fieldOf(tester).washPlacement,
          isNull,
          reason: 'washPlacement paints periwinkle unconditionally; a glow and '
              'a wash are different layers (wave-C error #3)',
        );
        expect(fieldOf(tester).glowColor, isNull);
      });

      testWidgets('$name: rest frame — an M3 row earns no motion',
          (tester) async {
        await tester.pumpWidget(build());
        await tester.pumpAndSettle();

        expect(fieldOf(tester).animateDecor, isFalse);
      });

      testWidgets('$name: the field paints the page, not the Scaffold',
          (tester) async {
        await tester.pumpWidget(build());
        await tester.pumpAndSettle();

        expect(
          tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
          Colors.transparent,
        );
        expect(
          find.ancestor(
            of: find.byType(Scaffold),
            matching: find.byType(JeebMidnightField),
          ),
          findsNothing,
          reason: 'the field is INSIDE the Scaffold body, so SafeArea and the '
              'docked footer sit over the glow, not beside it',
        );
      });
    }
  });

  group('docked act — the ORANGE rung R23 draws for `Submit for review`', () {
    testWidgets('gate_start_kyc_cta is the accent pill with the ctaOrange lift',
        (tester) async {
      await tester.pumpWidget(gate());
      await tester.pumpAndSettle();

      final cta = ctaFor('Start verification');
      expect(cta, findsOneWidget);
      final decoration = decorationOf(tester, cta);

      expect(
        decoration.color,
        _orange,
        reason: 'the periwinkle `primary` default would paint $_periwinkle; '
            'both neighbours (R23, R17) dock THIS act orange',
      );
      expect(decoration.boxShadow, JeebShadows.ctaOrange);
      expect(find.bySemanticsIdentifier('gate_start_kyc_cta'), findsOneWidget);
    });

    testWidgets('delivery_register_prompt_cta shares that rung exactly',
        (tester) async {
      await tester.pumpWidget(prompt());
      await tester.pumpAndSettle();

      final decoration = decorationOf(tester, ctaFor('Start verification'));
      expect(decoration.color, _orange);
      expect(decoration.boxShadow, JeebShadows.ctaOrange);
      expect(
        find.bySemanticsIdentifier('delivery_register_prompt_cta'),
        findsOneWidget,
      );
    });

    testWidgets('the gate spends its orange ONCE — both exits stay words',
        (tester) async {
      await tester.pumpWidget(gate());
      await tester.pumpAndSettle();

      for (final label in const [
        "I haven't registered as a Jeeber yet",
        'Back to requests',
      ]) {
        final decoration = decorationOf(tester, ctaFor(label));
        expect(decoration.color, isNull, reason: '$label must draw no pill');
        expect(decoration.border, isNull);
        final ink = tester.widget<Text>(find.text(label)).style!.color;
        expect(ink, _periwinkle);
        expect(ink, isNot(_orange));
      }
    });
  });

  group('ink ranking — token sheet §6', () {
    testWidgets('headline rides h1 26/w700 on onSurface', (tester) async {
      await tester.pumpWidget(gate());
      await tester.pumpAndSettle();

      final headline = tester
          .widget<Text>(find.text('Get approved to start sending offers'));
      expect(headline.style!.fontSize, 26);
      expect(headline.style!.fontWeight, FontWeight.w700);
      expect(headline.style!.color, _ink);
    });

    testWidgets('body rides body 14.5 on the muted ink role', (tester) async {
      await tester.pumpWidget(gate());
      await tester.pumpAndSettle();

      final body = tester.widget<Text>(
        find.text(
          'Finish your identity verification to unlock offering. It only '
          'takes a few minutes.',
        ),
      );
      expect(body.style!.fontSize, 14.5);
      expect(
        body.style!.color,
        _periwinkle,
        reason: 'onSurfaceVariant IS periwinkle under Midnight — the pass-1 '
            'comment claiming otherwise described a white page',
      );
    });
  });

  group('status slot — all four phases draw something honest', () {
    testWidgets('loading occupies the slot instead of popping in later',
        (tester) async {
      await tester.pumpWidget(loadingGate());
      await tester.pump();

      expect(find.byKey(const Key('gate-status-loading')), findsOneWidget);
      final note = tester.widget<JeebInfoNote>(find.byType(JeebInfoNote).first);
      expect(
        note.tone,
        JeebInfoNoteTone.muted,
        reason: 'a read in flight is not a decision, so it is calm glass',
      );
    });

    testWidgets('a failed read draws a muted strip, never the error tone',
        (tester) async {
      await tester.pumpWidget(failedGate());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('gate-status-unavailable')), findsOneWidget);
      final note = tester.widget<JeebInfoNote>(find.byType(JeebInfoNote).first);
      expect(note.tone, JeebInfoNoteTone.muted);
      expect(
        note.tone,
        isNot(JeebInfoNoteTone.error),
        reason: 'the error tone is reserved for a real KYC decision — a failed '
            'status READ must not read as a rejection',
      );
    });

    testWidgets('not-submitted draws no strip at all — the headline says it',
        (tester) async {
      await tester.pumpWidget(gate());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('gate-status-loading')), findsNothing);
      expect(find.byKey(const Key('gate-status-unavailable')), findsNothing);
      expect(
        find.byType(JeebInfoNote),
        findsOneWidget,
        reason: 'only gate_topup_note remains',
      );
    });

    testWidgets('pending keeps the warning tone', (tester) async {
      await tester.pumpWidget(gate(status: KycStatus.pending));
      await tester.pumpAndSettle();

      expect(
        tester.widget<JeebInfoNote>(find.byType(JeebInfoNote).first).tone,
        JeebInfoNoteTone.warning,
      );
    });

    testWidgets('rejected keeps the error tone — that one IS a decision',
        (tester) async {
      await tester.pumpWidget(gate(status: KycStatus.rejected));
      await tester.pumpAndSettle();

      expect(
        tester.widget<JeebInfoNote>(find.byType(JeebInfoNote).first).tone,
        JeebInfoNoteTone.error,
      );
    });

    testWidgets('R-F holds: the three exits render in EVERY phase',
        (tester) async {
      for (final build in <Widget Function()>[
        loadingGate,
        failedGate,
        gate,
        () => gate(status: KycStatus.pending),
      ]) {
        // Unmount between phases: the screen self-provides its cubit, so
        // reusing the element would keep the previous phase alive.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(build());
        await tester.pump();

        expect(find.bySemanticsIdentifier('gate_start_kyc_cta'), findsOneWidget);
        expect(find.bySemanticsIdentifier('gate_register_link'), findsOneWidget);
        expect(find.bySemanticsIdentifier('gate_back_cta'), findsOneWidget);
        expect(find.bySemanticsIdentifier('gate_topup_note'), findsOneWidget);
      }
    });
  });

  group('the top-up note stays calm glass (R23 info panel)', () {
    testWidgets('muted tone, not accent — the gate offers no top-up link',
        (tester) async {
      await tester.pumpWidget(gate());
      await tester.pumpAndSettle();

      final note = tester.widget<JeebInfoNote>(find.byType(JeebInfoNote));
      expect(note.tone, JeebInfoNoteTone.muted);
      expect(note.linkLabel, isNull);
    });
  });

  testWidgets('both screens mirror under RTL without overflow', (tester) async {
    await tester.pumpWidget(gate(locale: const Locale('ar')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(prompt(locale: const Locale('ar')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
