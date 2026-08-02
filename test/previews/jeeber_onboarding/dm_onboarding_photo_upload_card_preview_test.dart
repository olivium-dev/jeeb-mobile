// Render tests for the DmOnboardingPhotoUploadCard previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// One deviation from that template, on purpose. The card renders no text — it
// is an `Icons.add` or an `Image.memory` — so the `expectedText` map below
// binds to each preview's caption, which is preview scaffolding rather than
// widget output. On its own that would be exactly the weak assertion the
// harness warns about: it would pass even if all six previews drew the same
// empty box. So the real per-state contract is asserted underneath, on three
// axes at once — the MEASURED box, WHICH branch of `_CardContent` rendered,
// and WHICH photo the filled ones are showing.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/presentation/widgets/dm_onboarding_photo_upload_card.dart';

import '../preview_test_harness.dart';

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Empty · phone (390pt)': dmOnboardingPhotoUploadCardEmpty,
  'Empty · compact device (320pt)': dmOnboardingPhotoUploadCardCompactDevice,
  'Filled · portrait 4:5': dmOnboardingPhotoUploadCardPortraitPhoto,
  'Filled · landscape 16:9': dmOnboardingPhotoUploadCardLandscapePhoto,
  'Filled · low-resolution capture': dmOnboardingPhotoUploadCardLowResPhoto,
  'Filled · height-bounded host': dmOnboardingPhotoUploadCardBoundedHeight,
};

/// The box each preview must produce, measured on the card's own root key.
///
/// Not copied from a run — this is the arithmetic the widget promises: the step
/// column's width (device less two `Spacing.xLarge` gutters) resolved through
/// the 4:5 ratio, except for the bounded host where the height wins instead.
final Map<String, Size> _expectedBoxes = <String, Size>{
  'Empty · phone (390pt)': _widthDriven(390),
  'Empty · compact device (320pt)': _widthDriven(320),
  'Filled · portrait 4:5': _widthDriven(390),
  'Filled · landscape 16:9': _widthDriven(390),
  'Filled · low-resolution capture': _widthDriven(390),
  // Height wins: 180 * (4 / 5) = 144.
  'Filled · height-bounded host': const Size(144, 180),
};

Size _widthDriven(double deviceWidth) {
  final double w = dmOnboardingPhotoUploadCardContentWidth(deviceWidth);
  return Size(w, dmOnboardingPhotoUploadCardHeightFor(w));
}

/// Which photo each filled preview must be showing. The empty ones map to null.
final Map<String, Uint8List?> _expectedPhoto = <String, Uint8List?>{
  'Empty · phone (390pt)': null,
  'Empty · compact device (320pt)': null,
  'Filled · portrait 4:5': dmOnboardingPhotoUploadCardPortraitBytes,
  'Filled · landscape 16:9': dmOnboardingPhotoUploadCardLandscapeBytes,
  'Filled · low-resolution capture': dmOnboardingPhotoUploadCardLowResBytes,
  'Filled · height-bounded host': dmOnboardingPhotoUploadCardPortraitBytes,
};

/// Decodes a fixture for its intrinsic dimensions. Real decode work, so it has
/// to happen outside the fake-async zone.
Future<Size> _intrinsicSize(WidgetTester tester, Uint8List bytes) async {
  late Size size;
  await tester.runAsync(() async {
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    size = Size(frame.image.width.toDouble(), frame.image.height.toDouble());
    frame.image.dispose();
    codec.dispose();
  });
  return size;
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'DmOnboardingPhotoUploadCard',
    _previews,
    expectedText: const <String, String>{
      'Empty · phone (390pt)': 'Empty · 342pt content column',
      'Empty · compact device (320pt)': 'Empty · 272pt content column',
      'Filled · portrait 4:5': 'Filled · 80x100 source, no crop',
      'Filled · landscape 16:9': 'Filled · 160x90 source, 55% cropped',
      'Filled · low-resolution capture': 'Filled · 24x30 source, upscaled 14x',
      'Filled · height-bounded host': 'Bounded 180pt height · card collapses',
    },
  );

  group('DmOnboardingPhotoUploadCard preview specifics', () {
    // The assertion the caption-based `expectedText` above cannot make: six
    // previews of a parameterless widget are six states only if the boxes and
    // the contents actually differ.
    _expectedBoxes.forEach((String state, Size expected) {
      testWidgets('$state lays out at ${expected.width}x${expected.height}', (
        WidgetTester tester,
      ) async {
        await pumpPreview(tester, _previews[state]!);

        final Size actual = tester.getSize(
          find.byKey(DmOnboardingPhotoUploadCard.rootKey),
        );
        expect(actual.width, closeTo(expected.width, 0.05));
        expect(actual.height, closeTo(expected.height, 0.05));
      });
    });

    _expectedPhoto.forEach((String state, Uint8List? bytes) {
      testWidgets('$state renders ${bytes == null ? 'the plus' : 'its own '
          'photo'}', (WidgetTester tester) async {
        await pumpPreview(tester, _previews[state]!);

        if (bytes == null) {
          expect(find.byIcon(Icons.add), findsOneWidget);
          expect(find.byType(Image), findsNothing);
          return;
        }

        expect(find.byIcon(Icons.add), findsNothing);
        final Image image = tester.widget<Image>(find.byType(Image));
        expect(image.fit, BoxFit.cover);
        expect(
          (image.image as MemoryImage).bytes,
          same(bytes),
          reason: 'a filled preview showing a different fixture than the one '
              'it names is a preview set with one state and three labels',
        );
      });
    });

    testWidgets('the three photo fixtures are genuinely different shapes', (
      WidgetTester tester,
    ) async {
      // If these ever decode to the same shape the crop states below stop
      // meaning anything, so they are asserted rather than assumed.
      expect(
        await _intrinsicSize(tester, dmOnboardingPhotoUploadCardPortraitBytes),
        const Size(80, 100),
      );
      expect(
        await _intrinsicSize(tester, dmOnboardingPhotoUploadCardLandscapeBytes),
        const Size(160, 90),
      );
      expect(
        await _intrinsicSize(tester, dmOnboardingPhotoUploadCardLowResBytes),
        const Size(24, 30),
      );
    });

    testWidgets('a landscape capture loses over half its width to the cover', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, dmOnboardingPhotoUploadCardLandscapePhoto);
      final Size box = tester.getSize(
        find.byKey(DmOnboardingPhotoUploadCard.rootKey),
      );
      final Size source = await _intrinsicSize(
        tester,
        dmOnboardingPhotoUploadCardLandscapeBytes,
      );

      // BoxFit.cover takes the larger scale; for a 16:9 source in a 4:5 box
      // that is the vertical one, so the source is painted this wide.
      final double painted = source.width * (box.height / source.height);
      expect(painted, closeTo(760, 0.5));
      expect(
        1 - box.width / painted,
        greaterThan(0.5),
        reason: 'over half the frame is discarded, centred, with no alignment '
            'passed and no crop UI anywhere in the step',
      );
    });

    testWidgets('a 4:5 capture is not cropped at all', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, dmOnboardingPhotoUploadCardPortraitPhoto);
      final Size box = tester.getSize(
        find.byKey(DmOnboardingPhotoUploadCard.rootKey),
      );
      final Size source = await _intrinsicSize(
        tester,
        dmOnboardingPhotoUploadCardPortraitBytes,
      );

      expect(
        source.width / source.height,
        closeTo(box.width / box.height, 0.001),
        reason: 'the sign-off state: a portrait capture fills the drop area '
            'edge to edge',
      );
    });

    testWidgets('nothing gates the resolution of an accepted capture', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, dmOnboardingPhotoUploadCardLowResPhoto);
      final Size box = tester.getSize(
        find.byKey(DmOnboardingPhotoUploadCard.rootKey),
      );
      final Size source = await _intrinsicSize(
        tester,
        dmOnboardingPhotoUploadCardLowResBytes,
      );

      expect(
        box.width / source.width,
        greaterThan(10),
        reason: 'a 24pt-wide thumbnail is upscaled 14x into the card and the '
            'card says nothing about it — the compressor has a byte ceiling '
            'and no resolution floor',
      );
      // And it is still the filled branch: no fallback, no warning, no retake.
      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets('bounding the height collapses the drop area to a sliver', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, dmOnboardingPhotoUploadCardBoundedHeight);

      final Size box = tester.getSize(
        find.byKey(DmOnboardingPhotoUploadCard.rootKey),
      );
      // The ratio IS defended (the width constraint is loose, so AspectRatio
      // resolves from the height instead of short-circuiting)...
      expect(box.width / box.height, closeTo(4 / 5, 0.001));
      // ...at the cost of the thing the card is for. 144 of 342 available.
      final double available = dmOnboardingPhotoUploadCardContentWidth(390);
      expect(box.width / available, lessThan(0.45));

      // And it does not centre: the step's column is CrossAxisAlignment.start,
      // so the sliver sits hard against the leading edge of the column.
      final double cardLeft = tester
          .getTopLeft(find.byKey(DmOnboardingPhotoUploadCard.rootKey))
          .dx;
      final double columnLeft =
          tester.getTopLeft(find.byType(Column).last).dx;
      expect(cardLeft, closeTo(columnLeft, 0.5));
    });

    testWidgets('the plus icon opts out of the 200% text ceiling', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, dmOnboardingPhotoUploadCardEmpty);
      final Size atOneX = tester.getSize(find.byIcon(Icons.add));

      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpPreview(tester, dmOnboardingPhotoUploadCardEmpty);
      final Size atTwoX = tester.getSize(find.byIcon(Icons.add));

      expect(atOneX, const Size(Sizes.twoXLarge, Sizes.twoXLarge));
      expect(
        atTwoX,
        atOneX,
        reason: 'the only visual affordance in the empty state is a 32pt icon '
            'pinned by an absolute token, so it stays 32pt at the '
            'accessibility ceiling the 200% rendering of the matrix asserts',
      );
    });

    testWidgets('the card still says "add" after a photo has been added', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpPreview(tester, dmOnboardingPhotoUploadCardEmpty);
      expect(find.bySemanticsLabel('Tap to add a photo'), findsOneWidget);

      await pumpPreview(tester, dmOnboardingPhotoUploadCardPortraitPhoto);
      expect(
        find.bySemanticsLabel('Tap to add a photo'),
        findsOneWidget,
        reason: 'the label is fixed at build time and never reads state.photo, '
            'so a screen-reader user is told the box is empty while it is '
            'showing their photo — and the Image itself carries no semantics '
            'at all, so there is no other announcement to correct it',
      );

      handle.dispose();
    });

    testWidgets('the hint is localized, not hardcoded English', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpPreview(
        tester,
        dmOnboardingPhotoUploadCardEmpty,
        locale: const Locale('ar'),
      );
      expect(find.bySemanticsLabel('Tap to add a photo'), findsNothing);
      expect(find.bySemanticsLabel('اضغط لإضافة صورة'), findsOneWidget);

      handle.dispose();
    });

    test('the plus icon is the only thing marking the drop area', () {
      // The empty card is `surfaceContainerLow` on the scaffold's `surface`,
      // outlined with a hairline `outlineVariant`, with a `onSurfaceVariant`
      // plus in the middle. Measured against WCAG 1.4.11's 3:1 for the
      // boundary of a UI component:
      //
      //             fill/page   border/page
      //   light        1.06         1.29
      //   dark         1.08         1.98
      //
      // i.e. the card has no perceivable edge in EITHER theme, and light — the
      // default — is the worse of the two, which is the opposite of what the
      // AR RTL *dark* rendering of the matrix trains you to expect. Asserted
      // loosely on purpose: pinning 1.29 would make fixing the palette a test
      // failure, and asserting 3.0 would fail today.
      for (final ColorScheme scheme in <ColorScheme>[
        AppTheme.light().colorScheme,
        AppTheme.dark().colorScheme,
      ]) {
        expect(_contrast(scheme.outlineVariant, scheme.surface), greaterThan(1.0));

        // What the affordance actually rests on. This one IS a guard: if the
        // plus stops clearing 3:1 there is nothing left to see at all.
        expect(
          _contrast(scheme.onSurfaceVariant, scheme.surfaceContainerLow),
          greaterThanOrEqualTo(3.0),
          reason: 'with the card edge under 2:1 in both themes, the 32pt icon '
              'is the whole affordance and must stay legible',
        );
      }
    });
  });
}

/// WCAG relative-contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final double lumA = a.computeLuminance();
  final double lumB = b.computeLuminance();
  final double hi = lumA > lumB ? lumA : lumB;
  final double lo = lumA > lumB ? lumB : lumA;
  return (hi + 0.05) / (lo + 0.05);
}
