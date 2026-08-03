// Render tests for the KycCaptureTile previews.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/kyc/presentation/widgets/kyc_capture_tile.dart';
import 'package:jeeb_mobile/features/photo_attachment/domain/photo_attachment.dart';

import '../preview_test_harness.dart';

/// Exact ARB copy (`kycIdFrontLabel`, `kycIdBackLabel`, `kycSelfieStepTitle`),
/// so a reworded string breaks the test instead of silently unpinning a preview.
const String _frontLabel = 'Front side';
const String _backLabel = 'Back side';
const String _selfieLabel = 'Take a selfie';
const String _selfieLabelArabic = 'التقط صورة شخصية';

/// Every label the previews use, so the two text-free states can be asserted
/// negatively against all of them.
const List<String> _allLabels = <String>[
  _frontLabel,
  _backLabel,
  _selfieLabel,
  _selfieLabelArabic,
];

/// The width `KycIdentityStep` gives the tile on a 390 dp phone: the step's
/// `EdgeInsets.all(Spacing.large)` off either side.
const double _tileWidth = 390 - 2 * Spacing.large;

/// Pumps a preview into the real 390 dp-wide canvas box at [textScale] instead
/// of the 800x600 default test surface. The width is the whole point — at 800 dp
Future<void> _pumpInPreviewBox(
  WidgetTester tester,
  Widget Function() preview, {
  required double textScale,
  Size box = const Size(390, 180),
  Locale locale = const Locale('en'),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = box;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: previewCanvas(preview, locale),
    ),
  );
  await tester.pumpAndSettle();
}

/// The tile's own outermost [Container] — the one carrying the fill and the
/// border. The captured body nests two more (the label pill, and the decode
BoxDecoration _tileDecoration(WidgetTester tester) {
  final Container box = tester.widget<Container>(
    find
        .descendant(
          of: find.byType(KycCaptureTile),
          matching: find.byType(Container),
        )
        .first,
  );
  return box.decoration! as BoxDecoration;
}

Semantics _tileSemantics(WidgetTester tester) {
  return tester.widget<Semantics>(
    find
        .descendant(
          of: find.byType(KycCaptureTile),
          matching: find.byType(Semantics),
        )
        .first,
  );
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'KycCaptureTile',
    const <String, Widget Function()>{
      'Empty · ID front': kycCaptureTileEmpty,
      'Captured · ID back': kycCaptureTileCaptured,
      'Captured · undecodable bytes': kycCaptureTileUndecodableBytes,
      'Capturing · first capture': kycCaptureTileCapturing,
      'Retake in flight · photo hidden': kycCaptureTileRetakeInFlight,
      'Captured · Arabic label': kycCaptureTileArabicLabel,
    },
    expectedText: const <String, String>{
      // One distinct slot label per state that renders text. The two
      'Empty · ID front': _frontLabel,
      'Captured · ID back': _backLabel,
      'Captured · undecodable bytes': _selfieLabel,
      'Captured · Arabic label': _selfieLabelArabic,
    },
  );

  group('KycCaptureTile preview specifics', () {
    testWidgets('the empty tile is a camera glyph over its slot label', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycCaptureTileEmpty);

      expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
      expect(find.text(_frontLabel), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(find.byType(OmdsLoadingState), findsNothing);
      // The "empty" affordance is the heavier 1.5 dp border; a captured tile
      expect((_tileDecoration(tester).border! as Border).top.width, 1.5);
    });

    testWidgets('a captured tile shows the thumbnail plus the label pill', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycCaptureTileCaptured);

      expect(find.byType(Image), findsOneWidget);
      expect(find.text(_backLabel), findsOneWidget);
      expect(find.byIcon(Icons.photo_camera_outlined), findsNothing);
      expect((_tileDecoration(tester).border! as Border).top.width, 1.0);
    });

    testWidgets('undecodable stub bytes fall back instead of throwing', (
      WidgetTester tester,
    ) async {
      // StubPhotoPickerService — the default picker in the MVP build, in widget
      await pumpPreview(tester, kycCaptureTileUndecodableBytes);

      expect(tester.takeException(), isNull);
      expect(find.byType(Image), findsOneWidget);
      // The label survives the fallback, so the slot is still identifiable.
      expect(find.text(_selfieLabel), findsOneWidget);
    });

    // The two `isProcessing` states are the ones `expectedText` cannot pin.
    for (final MapEntry<String, Widget Function()> state
        in <String, Widget Function()>{
      'Capturing · first capture': kycCaptureTileCapturing,
      'Retake in flight · photo hidden': kycCaptureTileRetakeInFlight,
    }.entries) {
      testWidgets('${state.key}: a spinner and NO text at all', (
        WidgetTester tester,
      ) async {
        await pumpPreview(tester, state.value);

        expect(find.byType(OmdsLoadingState), findsOneWidget);
        expect(find.byType(Text), findsNothing);
        for (final String label in _allLabels) {
          expect(find.text(label), findsNothing, reason: label);
        }
        // Tap is disabled while a pick is in flight, and the Semantics node
        expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);
        expect(_tileSemantics(tester).properties.enabled, isFalse);
      });
    }

    testWidgets('a retake in flight HIDES the photo already on file', (
      WidgetTester tester,
    ) async {
      // build() tests isProcessing before hasPhoto, so `photo != null` is
      await pumpPreview(tester, kycCaptureTileRetakeInFlight);

      expect(find.byType(Image), findsNothing);
      // …and the tile still claims the captured styling, which is the ONLY
      expect((_tileDecoration(tester).border! as Border).top.width, 1.0);
    });

    testWidgets('a first capture in flight keeps the empty border weight', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycCaptureTileCapturing);

      expect((_tileDecoration(tester).border! as Border).top.width, 1.5);
    });

    testWidgets('the accessible name is the CTA, not the slot label', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycCaptureTileEmpty);

      final props = _tileSemantics(tester).properties;
      expect(props.button, isTrue);
      expect(props.enabled, isTrue);
      // `captureCtaSemantic ?? label` — the step passes kycIdCaptureCta here,
      expect(props.label, 'Take photo');
    });

    testWidgets('the label pill mirrors to the trailing edge in Arabic', (
      WidgetTester tester,
    ) async {
      await _pumpInPreviewBox(
        tester,
        kycCaptureTileCaptured,
        textScale: 1.0,
        locale: const Locale('ar'),
      );

      final Rect tile = tester.getRect(find.byType(KycCaptureTile));
      final Rect pill = tester.getRect(find.text(_backLabel));
      expect(Directionality.of(tester.element(find.byType(KycCaptureTile))),
          TextDirection.rtl);
      expect(
        pill.center.dx,
        greaterThan(tile.center.dx),
        reason: 'PositionedDirectional(start:) must put the pill on the right '
            'in RTL, not stay pinned bottom-left',
      );
    });
  });

  // Defects the previews exposed, held as assertions so they cannot regress
  group('KycCaptureTile layout ceiling (350 dp tile on a 390 dp phone)', () {
    testWidgets('the two bodies disagree about a LOOSE width constraint', (
      WidgetTester tester,
    ) async {
      // KycCaptureTile pins its height and nothing else. Given width loosely —
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 180);
      addTearDown(tester.view.reset);

      Future<double> widthUnderLooseConstraints(PhotoAttachment? photo) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: KycCaptureTile(
                  label: _frontLabel,
                  photo: photo,
                  isProcessing: false,
                  onTap: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return tester.getSize(find.byType(KycCaptureTile)).width;
      }

      final double empty = await widthUnderLooseConstraints(null);
      final double captured = await widthUnderLooseConstraints(
        PhotoAttachment(
          id: 'kyc-id-front',
          bytes: Uint8List(16),
          originalSizeBytes: 16,
          source: PhotoSource.camera,
        ),
      );

      expect(captured, 390, reason: 'the captured Stack takes the maximum');
      expect(
        empty,
        lessThan(captured - 100),
        reason: 'the placeholder Column shrink-wraps to icon + label, so the '
            'same slot is >100 dp narrower before a photo is taken',
      );
    });

    testWidgets('the previews themselves render at the wizard width', (
      WidgetTester tester,
    ) async {
      // Guards the fixture, not the widget: if the harness ever loses the
      for (final Widget Function() preview in <Widget Function()>[
        kycCaptureTileEmpty,
        kycCaptureTileCaptured,
        kycCaptureTileCapturing,
      ]) {
        await _pumpInPreviewBox(tester, preview, textScale: 1.0);
        expect(tester.getSize(find.byType(KycCaptureTile)).width, _tileWidth);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('the label pill cannot wrap: Arabic is chopped at 200% text', (
      WidgetTester tester,
    ) async {
      // PositionedDirectional sets `start` and no `end`, so RenderStack lays
      await _pumpInPreviewBox(
        tester,
        kycCaptureTileArabicLabel,
        textScale: 2.0,
      );

      final Rect tile = tester.getRect(find.byType(KycCaptureTile));
      final Rect label = tester.getRect(find.text(_selfieLabelArabic));

      expect(
        label.width,
        greaterThan(tile.width),
        reason: 'a single line WIDER than the tile it sits in — proof it was '
            'measured against unbounded width and never wrapped',
      );
      expect(
        label.right,
        greaterThan(tile.right),
        reason: 'laid out past the trailing edge, so the tail is clipped away',
      );
      // And nothing complains: Stack clips silently, so there is no overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('the widest ENGLISH label clears the same edge by a sliver', (
      WidgetTester tester,
    ) async {
      // Why the defect above only shows up in Arabic: the widest English label
      await _pumpInPreviewBox(
        tester,
        kycCaptureTileUndecodableBytes,
        textScale: 2.0,
      );

      final Rect tile = tester.getRect(find.byType(KycCaptureTile));
      final Rect label = tester.getRect(find.text(_selfieLabel));

      expect(label.right, lessThan(tile.right));
      expect(
        tile.right - label.right,
        lessThan(40),
        reason: 'under 40 dp of text slack — and the pill spends 12 of it on '
            'its own trailing padding, so ~20 dp is the whole margin',
      );
    });
  });
}
