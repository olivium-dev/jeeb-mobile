// R23 "Become a Jeeber" — per-element MIDNIGHT assertions.
//
// Goldens tolerate 5% pixel diff, so a token re-point on a stepper bar, a
// sub-line or a 22px checkbox is invisible to them. Everything here reads the
// colour/geometry off the widget instead.
//
// Board reference (`23-r23-become-a-jeeber.png`, 484px export = 1.1× the
// 440×956 canvas): field bloom is ORANGE top-end (least-squares un-composite
// rms 3.42 vs periwinkle 5.53 vs no-glow 5.63; fx 0.840, A 0.238); step label
// #FFFFFF; empty stepper track white 14.4%; captured sub-line #7BD9A4; active
// row = 2px accent frame over orange 10.0% fill; locked row .55 with a
// periwinkle padlock; submit pill orange at 45%.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/theme/jeeb_shadows.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_accent_frame_card.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_meter.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_outlined_card.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_select_chip.dart';
import 'package:jeeb_mobile/features/kyc/application/kyc_wizard_cubit.dart';
import 'package:jeeb_mobile/features/kyc/application/kyc_wizard_state.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_gateway.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_submission.dart';
import 'package:jeeb_mobile/features/kyc/presentation/kyc_wizard_screen.dart';
import 'package:jeeb_mobile/features/kyc/presentation/widgets/kyc_capture_tile.dart';
import 'package:jeeb_mobile/features/kyc/presentation/widgets/kyc_identity_step.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';
import 'package:jeeb_mobile/features/photo_attachment/domain/photo_attachment.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// Seeds the wizard on a chosen identity state without driving a gateway.
class _SeededCubit extends KycWizardCubit {
  _SeededCubit(KycWizardState seed)
      : super(pickerService: StubPhotoPickerService(), gateway: FakeKycGateway()) {
    emit(seed);
  }
}

PhotoAttachment _photo(String slot) => PhotoAttachment(
      id: 'r23-$slot',
      bytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
      originalSizeBytes: 4,
      source: PhotoSource.camera,
    );

KycWizardState _identity({
  bool front = false,
  bool back = false,
  bool selfie = false,
}) =>
    KycWizardState(
      step: KycWizardStep.identity,
      submission: KycSubmission(
        status: KycStatus.notSubmitted,
        idFront: front ? _photo('front') : null,
        idBack: back ? _photo('back') : null,
        selfie: selfie ? _photo('selfie') : null,
      ),
    );

void main() {
  final JeebSemanticColors midnight = JeebSemanticColors.midnight();
  final JeebColorRoles roles = JeebColorRoles.midnight();

  Future<void> pump(WidgetTester tester, KycWizardState seed) async {
    final cubit = _SeededCubit(seed);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.midnight(),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          SyncAppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: KycWizardScreen(cubit: cubit),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('R23 field', () {
    testWidgets(
        'mounts one still content field with the top-end ORANGE glow and '
        'declares no periwinkle wash', (tester) async {
      await pump(tester, _identity());

      final Finder finder = find.byType(JeebMidnightField);
      expect(finder, findsOneWidget, reason: 'R23 draws exactly one field');
      final JeebMidnightField field = tester.widget<JeebMidnightField>(finder);

      expect(field.variant, JeebFieldVariant.content);
      expect(field.glowPlacement, JeebFieldGlowPlacement.topEnd);
      // The fit says orange over periwinkle: a wash here would paint a bloom
      // the tile does not draw.
      expect(field.washPlacement, isNull);
      // 03-MOTION-NOTES R23: animated elements = 0.
      expect(field.animateDecor, isFalse);
    });
  });

  group('R23 stepper', () {
    testWidgets('draws the step label in onSurface, never the accent',
        (tester) async {
      await pump(tester, _identity());
      final ColorScheme scheme =
          Theme.of(tester.element(find.byType(JeebMeter))).colorScheme;

      final Text label =
          tester.widget<Text>(find.textContaining('Step 1 of 2'));
      expect(label.style!.color, scheme.onSurface);
      expect(label.style!.color, isNot(scheme.primary));
    });

    testWidgets(
        'runs the empty segment on white 14%, not the opaque navy the kit '
        'tone defaults to', (tester) async {
      await pump(tester, _identity());
      final ColorScheme scheme =
          Theme.of(tester.element(find.byType(JeebMeter))).colorScheme;

      final JeebMeter meter = tester.widget<JeebMeter>(find.byType(JeebMeter));
      expect(meter.trackColor, midnight.glassFillPressed);
      expect(meter.trackColor, isNot(scheme.surfaceContainerHighest));
    });
  });

  group('R23 capture rows', () {
    testWidgets(
        'the live row is an accent frame over the accentTint rung, carrying '
        'the rest glow', (tester) async {
      await pump(tester, _identity(front: true));

      final Finder frame = find.byType(JeebAccentFrameCard);
      expect(frame, findsOneWidget, reason: 'exactly one row is live');
      final JeebAccentFrameCard card =
          tester.widget<JeebAccentFrameCard>(frame);
      expect(card.fill, JeebAccentFrameFill.accentTint);
      expect(card.fill, isNot(JeebAccentFrameFill.glass));
      expect(card.borderWidth, KycCaptureTile.activeBorderWidth);

      // The halo is a painted SIBLING, not a parent decoration: Flutter paints
      // a boxShadow under the widget too, which double-tints a translucent
      // card (measured orange 27.7% vs the board's 10.0%).
      final Finder ring = find.byType(KycActiveGlowRing);
      expect(ring, findsOneWidget);
      expect(
        tester.widget<KycActiveGlowRing>(ring).shadows,
        JeebShadows.glowRest,
      );
      expect(tester.widget<KycActiveGlowRing>(ring).radius,
          KycCaptureTile.cardRadius);
      for (final DecoratedBox box in tester.widgetList<DecoratedBox>(
        find.ancestor(of: frame, matching: find.byType(DecoratedBox)),
      )) {
        expect(
          (box.decoration as BoxDecoration).boxShadow ?? const <BoxShadow>[],
          isEmpty,
          reason: 'a shadow above the card paints through its 12% fill',
        );
      }
    });

    testWidgets('a rest row carries no halo', (tester) async {
      await pump(tester, _identity(front: true, back: true, selfie: true));
      expect(find.byType(KycActiveGlowRing), findsNothing);
    });

    testWidgets('§2.2 budget: the SOLID accent capture pill appears once — a '
        'merely-pending row keeps the glass chip', (tester) async {
      // Cold entry: BOTH gov-ID rows are un-captured, only the front is live.
      await pump(tester, _identity());

      final Iterable<Widget> pills = tester.widgetList(
        find.byWidgetPredicate((w) {
          if (w is! DecoratedBox) return false;
          final BoxDecoration d = w.decoration as BoxDecoration;
          return d.color == roles.accent &&
              d.boxShadow == JeebShadows.ctaOrangeSmall;
        }),
      );
      expect(pills.length, 1, reason: 'one live step, one orange pill');

      final Iterable<JeebSelectChip> chips =
          tester.widgetList<JeebSelectChip>(find.byType(JeebSelectChip));
      expect(chips.length, 1, reason: 'the ID-back row is pending, not live');
      expect(chips.single.selected, isFalse);
    });

    testWidgets('the live fill stays on the accentTint rung — the halo does '
        'not paint under it', (tester) async {
      await pump(tester, _identity(front: true));

      // The kit tints via a scoped Theme swap on glassFill.
      final BuildContext inner =
          tester.element(find.byType(JeebAccentFrameCard));
      expect(
        Theme.of(inner).extension<JeebSemanticColors>()!.glassFill,
        isNot(midnight.accentTint),
        reason: 'content reads true glass back',
      );
      final Finder painted = find
          .descendant(
            of: find.byType(JeebAccentFrameCard),
            matching: find.byType(DecoratedBox),
          )
          .first;
      expect(
        (tester.widget<DecoratedBox>(painted).decoration as BoxDecoration)
            .color,
        midnight.accentTint,
      );
    });

    testWidgets(
        'the live row is the FIRST empty slot — front when nothing is '
        'captured, back once the front is done', (tester) async {
      // The tile key rides on the widget's own Semantics node, so the
      // KycCaptureTile is its ancestor.
      KycCaptureTile tile(Key key) => tester.widget<KycCaptureTile>(
            find.ancestor(
              of: find.byKey(key),
              matching: find.byType(KycCaptureTile),
            ),
          );

      await pump(tester, _identity());
      expect(tile(KycIdentityStep.frontTileKey).isActive, isTrue);
      expect(tile(KycIdentityStep.backTileKey).isActive, isFalse);

      await pump(tester, _identity(front: true));
      expect(tile(KycIdentityStep.backTileKey).isActive, isTrue);
      expect(tile(KycIdentityStep.frontTileKey).isActive, isFalse);
    });

    testWidgets('every row is rest glass once all three are captured',
        (tester) async {
      await pump(tester, _identity(front: true, back: true, selfie: true));

      expect(find.byType(JeebAccentFrameCard), findsNothing);
      expect(find.byType(JeebOutlinedCard), findsWidgets);
    });

    testWidgets(
        'the captured sub-line uses the SOFT success rung (#7BD9A4), not the '
        '#3BB273 solid', (tester) async {
      await pump(tester, _identity(front: true));

      final Text captured = tester.widget<Text>(find.text('Captured'));
      expect(captured.style!.color, roles.onSuccessContainer);
      expect(captured.style!.color, isNot(roles.success));
    });

    testWidgets('the pending hint is inkSoft; only the locked row drops to '
        'mutedText', (tester) async {
      await pump(tester, _identity());

      final Text pending = tester.widget<Text>(
        find.text('Lay it flat, avoid glare').first,
      );
      expect(pending.style!.color, midnight.inkSoft);
      expect(pending.style!.color, isNot(midnight.mutedText));

      final Text locked =
          tester.widget<Text>(find.text('Step 2 — unlocks after your ID'));
      expect(locked.style!.color, midnight.mutedText);
    });

    testWidgets('the locked selfie row dims to .55 and shows a padlock',
        (tester) async {
      await pump(tester, _identity());

      final Opacity dim = tester.widget<Opacity>(
        find
            .descendant(
              of: find.byKey(KycIdentityStep.selfieTileKey),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(dim.opacity, KycCaptureTile.lockedOpacity);
      expect(
        find.descendant(
          of: find.byKey(KycIdentityStep.selfieTileKey),
          matching: find.byIcon(Icons.lock_rounded),
        ),
        findsOneWidget,
      );
    });
  });

  group('R23 submit', () {
    testWidgets('is the ACCENT pill, not the periwinkle primary',
        (tester) async {
      await pump(tester, _identity());

      final JeebCtaButton cta = tester.widget<JeebCtaButton>(
        find.byKey(KycIdentityStep.submitButtonKey),
      );
      expect(cta.variant, JeebCtaVariant.accent);
      expect(cta.variant, isNot(JeebCtaVariant.primary));
      expect(cta.isEnabled, isFalse, reason: 'unlit until the steps complete');
    });
  });

  group('R23 layout — doc-13 P1', () {
    testWidgets(
        'the ID band follows the three capture rows, so front · back · selfie '
        'read as one checklist', (tester) async {
      await pump(tester, _identity());

      final double selfieY =
          tester.getTopLeft(find.byKey(KycIdentityStep.selfieTileKey)).dy;
      final double bandY = tester
          .getTopLeft(find.byKey(KycIdentityStep.idTypeNationalIdKey))
          .dy;
      expect(
        bandY,
        greaterThan(selfieY),
        reason: 'the contract band used to split the checklist',
      );
    });
  });
}
