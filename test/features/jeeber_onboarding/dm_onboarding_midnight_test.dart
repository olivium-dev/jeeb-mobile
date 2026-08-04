// M3-17 delivery-man onboarding wizard — per-element MIDNIGHT assertions.
//
// The screen has no tile of its own; R23 "Become a Jeeber" is the nearest one
// (the step this wizard chains INTO, same funnel, same shape) and R5/R6 supply
// the welcome/intro run. Every expectation below is that carry-over read off
// the widget, because the golden gate tolerates 5% pixel diff and none of these
// elements is 5% of the frame.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/theme/jeeb_radii.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/theme/jeeb_text_styles.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_meter.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_outlined_card.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_section_label.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/dm_onboarding_screen_fixtures.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/application/dm_onboarding_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/application/dm_onboarding_state.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/domain/dm_onboarding_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/presentation/dm_onboarding_screen.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/presentation/widgets/dm_onboarding_photo_upload_card.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/presentation/widgets/dm_onboarding_progress_header.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/presentation/widgets/dm_onboarding_step_header.dart';
import 'package:jeeb_mobile/features/kyc/presentation/widgets/kyc_capture_tile.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';
import 'package:jeeb_mobile/features/photo_attachment/domain/photo_attachment.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// Parks the wizard on a fixed state without driving a picker or a gateway.
class _SeededCubit extends DmOnboardingCubit {
  _SeededCubit(DmOnboardingState seed)
      : super(
          pickerService: StubPhotoPickerService(),
          gateway: FakeDmOnboardingGateway(),
          initialStep: seed.step,
        ) {
    emit(seed);
  }
}

PhotoAttachment _photo() => PhotoAttachment(
      id: 'm3-17-photo',
      bytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
      originalSizeBytes: 4,
      source: PhotoSource.camera,
    );

void main() {
  final JeebSemanticColors midnight = JeebSemanticColors.midnight();
  final JeebColorRoles roles = JeebColorRoles.midnight();

  /// Builds the cubit INSIDE the widget builder, exactly as the Dev Tool
  /// catalog does: a fixture that fires a probe at construction emits its
  /// one-shot error before a listener exists if it is built any earlier.
  Future<void> pumpLazy(
    WidgetTester tester,
    DmOnboardingCubit Function() build,
  ) async {
    DmOnboardingCubit? made;
    addTearDown(() => made?.close());
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
            child: DmOnboardingScreen(cubit: made ??= build()),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> pumpCubit(WidgetTester tester, DmOnboardingCubit cubit) async {
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
            child: DmOnboardingScreen(cubit: cubit),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> pump(
    WidgetTester tester, {
    DmOnboardingStep step = DmOnboardingStep.photo,
    PhotoAttachment? photo,
    DmOnboardingHomeBase? homeBase,
  }) =>
      pumpCubit(
        tester,
        _SeededCubit(
          DmOnboardingState(step: step, photo: photo, homeBase: homeBase),
        ),
      );

  ColorScheme schemeOf(WidgetTester tester) =>
      Theme.of(tester.element(find.byKey(DmOnboardingScreen.rootKey)))
          .colorScheme;

  group('M3-17 field', () {
    testWidgets(
        'mounts one still content field with the top-end ORANGE glow and '
        'declares no periwinkle wash', (tester) async {
      await pump(tester);

      final Finder finder = find.byType(JeebMidnightField);
      expect(finder, findsOneWidget, reason: 'one field hosts every step');
      final JeebMidnightField field = tester.widget<JeebMidnightField>(finder);

      expect(field.variant, JeebFieldVariant.content);
      // R23 and the whole top-end class (wave-C ruling); the glow is ORANGE and
      // the wash is PERIWINKLE — a wash here would paint a layer R23 has none of.
      expect(field.glowPlacement, JeebFieldGlowPlacement.topEnd);
      expect(field.washPlacement, isNull);
      expect(field.animateDecor, isFalse);
    });

    testWidgets('the scaffold is transparent so the field is the background',
        (tester) async {
      await pump(tester);
      final Scaffold scaffold = tester.widget<Scaffold>(
        find.byKey(DmOnboardingScreen.rootKey),
      );
      expect(scaffold.backgroundColor, Colors.transparent);
      expect(scaffold.backgroundColor, isNot(schemeOf(tester).surface));
    });
  });

  group('M3-17 progress band', () {
    testWidgets('draws the step caption in onSurface, never the accent',
        (tester) async {
      await pump(tester);
      final ColorScheme scheme = schemeOf(tester);

      final Text caption = tester.widget<Text>(
        find
            .descendant(
              of: find.byKey(DmOnboardingProgressHeader.rootKey),
              matching: find.byType(Text),
            )
            .first,
      );
      expect(caption.style!.color, scheme.onSurface);
      // Under Midnight `primary` IS #D73B00: this caption used to spend the
      // orange budget on a read-only line.
      expect(caption.style!.color, isNot(scheme.primary));
      expect(caption.style!.color, isNot(roles.accent));
    });

    testWidgets(
        'runs the empty segment on white 14%, not the opaque navy the kit '
        'tone defaults to', (tester) async {
      await pump(tester);
      final JeebMeter meter = tester.widget<JeebMeter>(find.byType(JeebMeter));

      expect(meter.trackColor, midnight.glassFillPressed);
      expect(meter.trackColor, isNot(schemeOf(tester).surfaceContainerHighest));
    });

    testWidgets('fills segment N while the user is ON step N (R23 rule)',
        (tester) async {
      for (final DmOnboardingStep step in DmOnboardingStep.values) {
        await pump(tester, step: step);
        final JeebMeter meter =
            tester.widget<JeebMeter>(find.byType(JeebMeter));
        expect(meter.filled, step.index + 1,
            reason: 'a "Step 3 of 3" caption over a 2/3 bar is the off-by-one '
                'R23 already closed');
        expect(meter.steps, DmOnboardingState.totalSteps);
      }
    });
  });

  group('M3-17 intro run (R5/R6 shape)', () {
    testWidgets('headline is the white h1 over a periwinkle body line',
        (tester) async {
      await pump(tester);
      final ColorScheme scheme = schemeOf(tester);
      final JeebTextStyles text = JeebTextStyles.midnight();

      final Iterable<Text> lines = tester.widgetList<Text>(
        find.descendant(
          of: find.byType(DmOnboardingStepHeader),
          matching: find.byType(Text),
        ),
      );
      expect(lines.length, 2);
      final Text title = lines.first;
      final Text subtitle = lines.last;

      expect(title.style!.color, scheme.onSurface);
      expect(title.style!.color, isNot(scheme.primary));
      expect(title.style!.fontSize, text.h1.fontSize);
      // R5/R6 draw the supporting line at body scale, not the caption ramp.
      expect(subtitle.style!.color, scheme.onSurfaceVariant);
      expect(subtitle.style!.fontSize, text.body.fontSize);
    });
  });

  group('M3-17 photo drop zone', () {
    testWidgets(
        'is R23\'s dashed zone on glassBorderVivid with NO fill — the solid '
        'accent slab is gone', (tester) async {
      await pump(tester);

      final Finder painted = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is KycDashedBorderPainter,
      );
      expect(painted, findsOneWidget);
      final KycDashedBorderPainter painter =
          tester.widget<CustomPaint>(painted).painter!
              as KycDashedBorderPainter;
      expect(painter.color, midnight.glassBorderVivid);
      expect(painter.strokeWidth, 1.5);
    });

    testWidgets('§2.2 budget: nothing inside the drop card is filled accent',
        (tester) async {
      await pump(tester);
      final ColorScheme scheme = schemeOf(tester);

      final Iterable<DecoratedBox> boxes = tester.widgetList<DecoratedBox>(
        find.descendant(
          of: find.byKey(DmOnboardingPhotoUploadCard.rootKey),
          matching: find.byType(DecoratedBox),
        ),
      );
      for (final DecoratedBox box in boxes) {
        final Color? fill = (box.decoration as BoxDecoration).color;
        expect(fill, isNot(scheme.primary));
        expect(fill, isNot(roles.accent));
      }
    });

    testWidgets('the card sits on the lg rung', (tester) async {
      await pump(tester);
      final JeebOutlinedCard card = tester.widget<JeebOutlinedCard>(
        find
            .descendant(
              of: find.byKey(DmOnboardingPhotoUploadCard.rootKey),
              matching: find.byType(JeebOutlinedCard),
            )
            .first,
      );
      expect(card.radius, JeebRadii.lg);
    });

    testWidgets(
        'a non-decodable payload falls back to the drop mark instead of '
        'throwing the card away', (tester) async {
      await pump(tester, photo: _photo());
      await tester.pump();

      expect(find.byKey(DmOnboardingPhotoUploadCard.rootKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('M3-17 address step', () {
    testWidgets('labels are the kit section label, not a primary-inked Text',
        (tester) async {
      await pump(tester, step: DmOnboardingStep.address);
      final ColorScheme scheme = schemeOf(tester);

      expect(find.byType(JeebSectionLabel), findsNWidgets(4));
      for (final Text line in tester.widgetList<Text>(find.byType(Text))) {
        expect(line.style?.color, isNot(scheme.primary));
      }
    });

    testWidgets(
        'the inputs are R23\'s OmdsTextField on the md rung, not the '
        'headlineLarge-over-navy validated variant', (tester) async {
      await pump(tester, step: DmOnboardingStep.address);

      expect(find.byType(OmdsValidatedTextField), findsNothing);
      final Iterable<OmdsTextField> fields =
          tester.widgetList<OmdsTextField>(find.byType(OmdsTextField));
      expect(fields.length, 4);
      for (final OmdsTextField field in fields) {
        expect(field.borderRadius, JeebRadii.md);
      }
      // The frozen `find.byType(TextField)` contract survives the swap.
      expect(find.byType(TextField), findsNWidgets(4));
    });
  });

  group('M3-17 service area', () {
    testWidgets('the map preview is rest glass, not an opaque navy slab',
        (tester) async {
      await pump(tester, step: DmOnboardingStep.serviceArea);
      final ColorScheme scheme = schemeOf(tester);

      final Finder panel = find.descendant(
        of: find.bySemanticsIdentifier('service_area_map_pin'),
        matching: find.byType(JeebOutlinedCard),
      );
      expect(panel, findsOneWidget);
      expect(tester.widget<JeebOutlinedCard>(panel).radius, JeebRadii.lg);
      for (final Container box in tester.widgetList<Container>(
        find.descendant(
          of: find.bySemanticsIdentifier('service_area_map_pin'),
          matching: find.byType(Container),
        ),
      )) {
        expect(box.color, isNot(scheme.surfaceContainerHighest));
      }
    });

    testWidgets(
        '§2.2 budget: the glyph goes accent only once a real pin exists',
        (tester) async {
      await pump(tester, step: DmOnboardingStep.serviceArea);
      Icon glyph = tester.widget<Icon>(find.byIcon(Icons.map_outlined));
      expect(glyph.color, midnight.mutedText);
      expect(glyph.color, isNot(roles.accent));

      await pump(
        tester,
        step: DmOnboardingStep.serviceArea,
        homeBase: const DmOnboardingHomeBase(
          lat: 33.88,
          lng: 35.51,
          label: 'Sassine Square',
        ),
      );
      glyph = tester.widget<Icon>(find.byIcon(Icons.location_on).first);
      expect(glyph.color, roles.accent);
    });

    testWidgets('the unset location value reads mutedText, not the 14% stroke',
        (tester) async {
      await pump(tester, step: DmOnboardingStep.serviceArea);
      final ColorScheme scheme = schemeOf(tester);

      final Text value = tester.widget<Text>(
        find.descendant(
          of: find.bySemanticsIdentifier('dm_onboarding_location_value'),
          matching: find.byType(Text),
        ),
      );
      expect(value.style!.color, midnight.mutedText);
      // `outline` is a stroke token; as ink on navy it measures ~1.2:1.
      expect(value.style!.color, isNot(scheme.outline));
    });
  });

  group('M3-17 CTA', () {
    testWidgets('the docked Continue is the ACCENT pill (R23 + R5 both orange)',
        (tester) async {
      await pump(tester);
      final JeebCtaButton cta =
          tester.widget<JeebCtaButton>(find.byType(JeebCtaButton));

      expect(cta.variant, JeebCtaVariant.accent);
      expect(cta.variant, isNot(JeebCtaVariant.primary));
    });

    testWidgets('loading: the in-flight coverage probe spins the same pill',
        (tester) async {
      await pumpLazy(
        tester,
        DmOnboardingScreenPreviewFixtures.checkingCoverage,
      );
      await tester.pump();

      final JeebCtaButton cta =
          tester.widget<JeebCtaButton>(find.byType(JeebCtaButton));
      expect(cta.isLoading, isTrue);
      expect(cta.variant, JeebCtaVariant.accent);
      expect(find.byType(JeebMidnightField), findsOneWidget);
    });

    testWidgets('error: a failed probe keeps the field and the retry pill up',
        (tester) async {
      await pumpLazy(
        tester,
        DmOnboardingScreenPreviewFixtures.coverageFailed,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byType(JeebMidnightField), findsOneWidget);
      final JeebCtaButton cta =
          tester.widget<JeebCtaButton>(find.byType(JeebCtaButton));
      expect(cta.isLoading, isFalse);
    });
  });
}
