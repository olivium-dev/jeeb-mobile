// Render tests for the DmOnboardingPhotoStep previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// One deviation from that template, on purpose — the same one
// `delivery_confirm_illustration_preview_test.dart` makes. Every state of this
// step renders the SAME copy (one title, one subtitle, one "Continue"), so the
// `expectedText` map below binds to each preview's caption, which is preview
// scaffolding rather than widget output. On its own that would be exactly the
// weak assertion the harness warns about: six previews of one state with six
// labels would pass. The per-state contract is asserted underneath, against the
// three things this step actually varies — whether the CTA is enabled, what the
// drop-area contains, and the box that drop-area lays out in.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/presentation/widgets/dm_onboarding_photo_step.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/presentation/widgets/dm_onboarding_photo_upload_card.dart';

import '../preview_test_harness.dart';

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Empty (no photo)': dmOnboardingPhotoStepEmpty,
  'Photo chosen': dmOnboardingPhotoStepWithPhoto,
  'Wide photo (cropped)': dmOnboardingPhotoStepWidePhoto,
  'Compact 320': dmOnboardingPhotoStepCompact,
  'Short viewport (scrolls)': dmOnboardingPhotoStepShortViewport,
  'Photo pick failed': dmOnboardingPhotoStepPickFailed,
};

/// The step's single bottom-pinned CTA.
OmdsLoadingButton _cta(WidgetTester tester) =>
    tester.widget<OmdsLoadingButton>(find.byType(OmdsLoadingButton));

/// The 4:5 drop-area, as a box.
Size _cardBox(WidgetTester tester) =>
    tester.getSize(find.byKey(DmOnboardingPhotoUploadCard.rootKey));

/// How far the step's content can be scrolled — 0 when everything fits.
double _scrollExtent(WidgetTester tester) => tester
    .state<ScrollableState>(find.byType(Scrollable))
    .position
    .maxScrollExtent;

/// The laid-out line boxes of the step's wrapped title, top to bottom.
///
/// Line boxes rather than the widget rect: the title wraps to the full content
/// width in both locales, so the rect is identical either way and only the
/// glyph runs inside it can show whether the header mirrored.
List<TextBox> _titleLines(WidgetTester tester, String title) {
  final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
    find.text(title),
  );
  final Map<int, List<TextBox>> byLine = <int, List<TextBox>>{};
  for (final TextBox box in paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: title.length),
  )) {
    byLine.putIfAbsent(box.top.round(), () => <TextBox>[]).add(box);
  }
  final List<int> tops = byLine.keys.toList()..sort();
  return <TextBox>[
    for (final int top in tops)
      TextBox.fromLTRBD(
        byLine[top]!.map((TextBox b) => b.left).reduce(math.min),
        top.toDouble(),
        byLine[top]!.map((TextBox b) => b.right).reduce(math.max),
        byLine[top]!.first.bottom,
        byLine[top]!.first.direction,
      ),
  ];
}

/// WCAG relative-contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final double hi = math.max(a.computeLuminance(), b.computeLuminance());
  final double lo = math.min(a.computeLuminance(), b.computeLuminance());
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'DmOnboardingPhotoStep',
    _previews,
    expectedText: const <String, String>{
      'Empty (no photo)': 'Empty: no photo yet — Continue inert',
      'Photo chosen': 'Photo chosen: Continue enabled',
      'Wide photo (cropped)': 'Wide photo: 3:1 cropped to 4:5',
      'Compact 320': 'Compact 320pt device',
      'Short viewport (scrolls)': 'Short viewport: content scrolls, CTA pinned',
      'Photo pick failed': 'Pick failed: step shows nothing',
    },
  );

  group('DmOnboardingPhotoStep preview specifics', () {
    // One pump per test, deliberately: two of these trees differ only in the
    // cubit's seed, so pumping them into the same tester relies on the
    // `ValueKey` in `_hosted` to force `BlocProvider.create` to re-run. Tests
    // that do pump twice below are the ones comparing states on purpose.
    testWidgets('the empty step offers the "+" drop-area and an inert CTA', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, dmOnboardingPhotoStepEmpty);

      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(
        _cta(tester).isEnabled,
        isFalse,
        reason:
            'Continue is gated on hasPhoto — the heading says the photo is '
            'required, so the first step must stay blocked',
      );
      expect(_cta(tester).isLoading, isFalse);
    });

    testWidgets('a chosen photo replaces the "+" and unblocks Continue', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, dmOnboardingPhotoStepWithPhoto);

      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(Icons.add), findsNothing);
      expect(_cta(tester).isEnabled, isTrue);
    });

    testWidgets('the two photo states differ from empty by content, not box', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, dmOnboardingPhotoStepEmpty);
      final Size emptyBox = _cardBox(tester);

      await pumpPreview(tester, dmOnboardingPhotoStepWithPhoto);
      expect(_cardBox(tester), emptyBox);
      final Image portrait = tester.widget<Image>(find.byType(Image));

      await pumpPreview(tester, dmOnboardingPhotoStepWidePhoto);
      expect(_cardBox(tester), emptyBox);
      final Image wide = tester.widget<Image>(find.byType(Image));

      // Same card, same fit, different payload: the 3:1 fixture is cropped to
      // 4:5 with no reframe control anywhere in the step.
      expect(portrait.fit, BoxFit.cover);
      expect(wide.fit, BoxFit.cover);
      expect(
        wide.image,
        isNot(portrait.image),
        reason:
            'the wide-photo preview must carry its own payload, or it is '
            'the photo-chosen state with a different caption',
      );
      expect(
        emptyBox.width / emptyBox.height,
        closeTo(4 / 5, 0.001),
        reason:
            'the drop-area is the Figma 392x507 portrait hole; a landscape '
            'photo has to lose its edges to fit it',
      );
    });

    testWidgets('a failed pick leaves the step indistinguishable from empty', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, dmOnboardingPhotoStepEmpty);
      final Size emptyBox = _cardBox(tester);

      await pumpPreview(tester, dmOnboardingPhotoStepPickFailed);

      // Pinning the gap, not endorsing it: DmOnboardingError.photoPickFailed is
      // surfaced only by the host screen's one-shot SnackBar (JEBV4-13 P1-5),
      // which is acknowledged immediately. The drop-area keeps no trace of the
      // failure and offers no retry affordance of its own.
      expect(_cardBox(tester), emptyBox);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(_cta(tester).isEnabled, isFalse);
      expect(find.textContaining('again'), findsNothing);
    });

    testWidgets('the compact device shrinks the card, not the CTA', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, dmOnboardingPhotoStepEmpty);
      final Size phoneCard = _cardBox(tester);
      final double phoneCtaHeight = tester
          .getSize(find.byType(OmdsLoadingButton))
          .height;

      await pumpPreview(tester, dmOnboardingPhotoStepCompact);
      final Size compactCard = _cardBox(tester);

      // 390 and 320 minus the 24pt gutters, at 4:5.
      expect(phoneCard.width, closeTo(342, 0.01));
      expect(compactCard.width, closeTo(272, 0.01));
      expect(
        compactCard.width,
        lessThan(phoneCard.width),
        reason:
            'a 320pt state that renders at 390pt under test is the same '
            'state as the phone one',
      );
      expect(compactCard.width / compactCard.height, closeTo(4 / 5, 0.001));
      expect(
        tester.getSize(find.byType(OmdsLoadingButton)).height,
        phoneCtaHeight,
        reason: 'OmdsLoadingButton is a fixed 48pt box on every device',
      );
    });

    testWidgets('the short viewport scrolls further and keeps the CTA pinned', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, dmOnboardingPhotoStepEmpty);
      final double phoneExtent = _scrollExtent(tester);

      await pumpPreview(tester, dmOnboardingPhotoStepShortViewport);
      final double shortExtent = _scrollExtent(tester);

      expect(
        shortExtent,
        greaterThan(phoneExtent),
        reason:
            'a short viewport that scrolls no further than a tall one was '
            'never actually short',
      );

      // The overflow becomes scroll, not a RenderFlex stripe, and Continue
      // stays inside the step's own box instead of being pushed off it.
      final Rect step = tester.getRect(
        find.byKey(DmOnboardingPhotoStep.rootKey),
      );
      final Rect cta = tester.getRect(find.byType(OmdsLoadingButton));
      expect(cta.bottom, lessThanOrEqualTo(step.bottom + 0.01));
      expect(cta.top, greaterThanOrEqualTo(step.top));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the drop-area still says "Tap to add a photo" once filled', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpPreview(tester, dmOnboardingPhotoStepEmpty);
      expect(find.bySemanticsLabel('Tap to add a photo'), findsOneWidget);

      await pumpPreview(tester, dmOnboardingPhotoStepWithPhoto);
      // DmOnboardingPhotoUploadCard builds its Semantics label OUTSIDE the
      // BlocBuilder that swaps "+" for the image, so the announcement never
      // changes: a screen-reader user is told to add a photo they have already
      // added, and is never told the required step is satisfied.
      expect(
        find.bySemanticsLabel('Tap to add a photo'),
        findsOneWidget,
        reason:
            'if this ever fails the label became state-aware — delete this '
            'expectation and the note in the preview library doc',
      );

      handle.dispose();
    });

    testWidgets('the blocked CTA is dimmed but not announced as disabled', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpPreview(tester, dmOnboardingPhotoStepEmpty);

      final SemanticsNode node = tester.getSemantics(
        find.bySemanticsIdentifier('dm_onboarding_continue'),
      );
      // Pinning the gap: OmdsLoadingButton drops its GestureDetector callback
      // and fades the fill to 60% alpha, but the wrapping Semantics never sets
      // `enabled: false`, so assistive tech announces a plain button and the
      // user is left tapping a control that cannot respond.
      expect(node.flagsCollection.isButton, isTrue);
      expect(
        node.flagsCollection.isEnabled,
        ui.Tristate.none,
        reason:
            'Tristate.none means the node declares no enabled state at all '
            '— if this ever fails the disabled state became announceable, so '
            'delete this expectation and the note in the preview library doc',
      );

      handle.dispose();
    });

    testWidgets('the step is localized, not hardcoded English', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, dmOnboardingPhotoStepEmpty);
      expect(find.text('Upload a clear photo for you'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);

      await pumpPreview(
        tester,
        dmOnboardingPhotoStepEmpty,
        locale: const Locale('ar'),
      );
      expect(find.text('Upload a clear photo for you'), findsNothing);
      expect(find.text('ارفع صورة واضحة لك'), findsOneWidget);
      expect(find.text('متابعة'), findsOneWidget);
      expect(
        Directionality.of(
          tester.element(find.byKey(DmOnboardingPhotoStep.rootKey)),
        ),
        TextDirection.rtl,
      );
    });

    testWidgets('the AR rendering really mirrors, it is not just translated', (
      WidgetTester tester,
    ) async {
      // The step has no icons or rows to mirror — its only directional surface
      // is the header block, which relies on `CrossAxisAlignment.start`
      // resolving against `Directionality`. Both title lines wrap to the full
      // content width, so a rect comparison cannot see the difference; the
      // laid-out line boxes can.
      await pumpPreview(tester, dmOnboardingPhotoStepEmpty);
      final List<TextBox> en = _titleLines(
        tester,
        'Upload a clear photo for you',
      );
      expect(en.first.left, closeTo(0, 0.5));

      await pumpPreview(
        tester,
        dmOnboardingPhotoStepEmpty,
        locale: const Locale('ar'),
      );
      const String arTitle = 'ارفع صورة واضحة لك';
      final double width = tester
          .renderObject<RenderParagraph>(find.text(arTitle))
          .size
          .width;
      final List<TextBox> ar = _titleLines(tester, arTitle);
      expect(ar.length, greaterThan(1));
      for (final TextBox line in ar) {
        expect(
          line.right,
          closeTo(width, 0.5),
          reason:
              'every Arabic line must end at the trailing (right) edge — a '
              'left-aligned line here means the header stopped mirroring',
        );
      }
      expect(ar.last.left, greaterThan(0));
    });

    testWidgets('at 200% text the content scrolls instead of overflowing', (
      WidgetTester tester,
    ) async {
      final Map<String, double> extentsAt100 = <String, double>{};
      for (final MapEntry<String, Widget Function()> entry
          in _previews.entries) {
        await pumpPreview(tester, entry.value);
        extentsAt100[entry.key] = _scrollExtent(tester);
      }

      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
        for (final MapEntry<String, Widget Function()> entry
            in _previews.entries) {
          await pumpPreview(tester, entry.value, locale: locale);

          expect(
            tester.takeException(),
            isNull,
            reason:
                '${entry.key} (${locale.languageCode}) overflowed at the '
                '200% accessibility ceiling',
          );
          expect(
            _scrollExtent(tester),
            greaterThan(extentsAt100[entry.key]!),
            reason:
                'the doubled header has to lengthen the scroll, not be '
                'clipped',
          );
          // The CTA is the one part of the step that does NOT grow: an
          // `OmdsLoadingButton` is a fixed 48pt box whatever the text scale.
          // At 200% the label is 40pt of those 48, so the shipping copy still
          // clears the box — with 8pt to spare in EN and no room for a longer
          // localized label or a taller scale.
          expect(tester.getSize(find.byType(OmdsLoadingButton)).height, 48.0);
          expect(
            tester
                .getSize(
                  find.text(
                    locale.languageCode == 'ar' ? 'متابعة' : 'Continue',
                  ),
                )
                .height,
            lessThanOrEqualTo(48.0),
          );
        }
      }
    });

    test('the drop-area boundary and the subtitle miss their contrast floors', () {
      // Measured through the previews, asserted here on the palette itself so
      // the numbers cannot drift silently.
      for (final ThemeData theme in <ThemeData>[
        AppTheme.light(),
        AppTheme.dark(),
      ]) {
        final ColorScheme cs = theme.colorScheme;

        // `DmOnboardingPhotoUploadCard` paints `surfaceContainerLow` inside a
        // `outlineVariant` hairline, on the page's `surface`. Both readings are
        // far under the 3:1 WCAG 1.4.11 asks of the boundary that identifies a
        // control — and this control IS the step: a 342x427 tap target whose
        // only visible edge is that hairline. What actually marks it is the
        // "+" glyph (8.9:1 light / 10.1:1 dark).
        expect(
          _contrast(cs.outlineVariant, cs.surface),
          lessThan(3.0),
          reason:
              'if this ever passes 3:1 the palette was fixed — delete this '
              'expectation and the note in the preview library doc',
        );
        expect(_contrast(cs.surfaceContainerLow, cs.surface), lessThan(1.2));
      }

      // `DmOnboardingStepHeader` inks the subtitle with `onSecondaryContainer`
      // — the light-indigo emphasis tint — over the white scaffold. At 3.76:1
      // it misses WCAG AA's 4.5:1 for normal-size text (`titleSmall` is 14pt
      // Inter, well under the 18.66pt large-text exemption). The dark scheme is
      // fine at 14.29:1, so this is a light-mode-only defect and the EN light
      // rendering of every preview above is where it shows.
      final ColorScheme light = AppTheme.light().colorScheme;
      expect(
        _contrast(light.onSecondaryContainer, light.surface),
        lessThan(4.5),
        reason:
            'if this ever passes 4.5:1 the tint was fixed — delete this '
            'expectation and the note in the preview library doc',
      );
      expect(
        _contrast(
          AppTheme.dark().colorScheme.onSecondaryContainer,
          AppTheme.dark().colorScheme.surface,
        ),
        greaterThan(4.5),
      );
    });
  });
}
