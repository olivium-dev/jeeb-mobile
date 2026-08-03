// Render tests for the KycIdAlignmentGuide previews.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/kyc/presentation/widgets/kyc_id_alignment_guide.dart';

import '../preview_test_harness.dart';

/// Exact ARB copy, so a reworded string breaks the test instead of silently
/// unpinning the preview.
const String _title = 'Align your ID inside the frame';
const String _caption = 'Place the card flat, fill the frame, and avoid glare.';
const String _longCaption =
    'We need a clear photo of both sides. Make sure the text is legible and '
    'the corners are visible.';
const String _rejectionCaption =
    "We couldn't read the ID photos. Make sure both sides are sharp and "
    'well-lit.';
const String _captionAr = 'ضع البطاقة مسطحة، واملأ الإطار، وتجنّب الانعكاسات.';

/// The four `_CornerTick`s, in tree order (`_Corner.values`: topStart, topEnd,
/// bottomStart, bottomEnd). They are the only [CustomPaint]s inside the frame.
Finder _cornerTicks() => find.descendant(
      of: find.byKey(KycIdAlignmentGuide.frameKey),
      matching: find.byType(CustomPaint),
    );

/// Pumps a preview at a forced text scale, the way the canvas's
/// `EN 200% text` rendering does.
Future<void> _pumpAtTextScale(
  WidgetTester tester,
  Widget Function() preview,
  double scale,
) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: previewCanvas(preview, const Locale('en')),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'KycIdAlignmentGuide',
    const <String, Widget Function()>{
      'National ID · production copy': kycIdAlignmentGuideProduction,
      'Longest caption · 320 pt phone':
          kycIdAlignmentGuideLongestCaptionCompact,
      'Resubmit · rejection reason': kycIdAlignmentGuideRejectionReason,
      'Empty caption': kycIdAlignmentGuideEmptyCaption,
      'Tablet · full-width step body': kycIdAlignmentGuideTabletWidth,
    },
    expectedText: const <String, String>{
      'National ID · production copy': _caption,
      'Longest caption · 320 pt phone': _longCaption,
      'Resubmit · rejection reason': _rejectionCaption,
      'Tablet · full-width step body': _caption,
    },
  );

  group('KycIdAlignmentGuide preview specifics', () {
    testWidgets('the caption is the ONLY text: the title is never painted', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycIdAlignmentGuideProduction);

      expect(find.text(_caption), findsOneWidget);
      // `title` reaches Semantics and nothing else, so the visible guide has
      expect(find.text(_title), findsNothing);
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('the accessibility node announces the caption TWICE', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, kycIdAlignmentGuideProduction);

      final SemanticsNode node = tester.getSemantics(
        find.byKey(KycIdAlignmentGuide.rootKey),
      );
      // `container: true` without `explicitChildNodes`, so the caption Text is
      expect(node.label, '$_title\n$_caption');
      expect(node.hint, _caption);
      expect(node.childrenCount, 0);

      handle.dispose();
    });

    testWidgets('an empty caption paints nothing but still takes its band', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycIdAlignmentGuideEmptyCaption);

      // Its own state, and not one of the other four.
      expect(find.text(''), findsOneWidget);
      expect(find.text(_caption), findsNothing);
      expect(find.text(_longCaption), findsNothing);
      expect(find.text(_rejectionCaption), findsNothing);

      final Rect frame = tester.getRect(
        find.byKey(KycIdAlignmentGuide.frameKey),
      );
      final Rect caption = tester.getRect(find.byType(Text));
      expect(caption.width, 0, reason: 'nothing is painted');
      expect(
        caption.height,
        greaterThan(0),
        reason: 'an empty line band is still laid out under the frame',
      );
      expect(
        caption.top - frame.bottom,
        closeTo(Spacing.small, 0.01),
        reason: 'the 12 pt gap is unconditional, so the dead space is '
            'Spacing.small + a blank line',
      );
    });

    testWidgets('the ID-1 frame is capped at 240 pt even on a tablet body', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycIdAlignmentGuideTabletWidth);

      final Rect frame = tester.getRect(
        find.byKey(KycIdAlignmentGuide.frameKey),
      );
      expect(frame.width, closeTo(KycIdAlignmentGuide.maxFrameWidth, 0.01));
      expect(
        frame.width / frame.height,
        closeTo(KycIdAlignmentGuide.idCardAspectRatio, 1e-6),
      );
      // Nothing clamps the step to a readable column (no `ResponsiveBody`), so
      expect(
        tester.getRect(find.text(_caption)).width,
        greaterThan(frame.width * 2),
      );
    });

    testWidgets('the frame does not scale with the user text size', (
      WidgetTester tester,
    ) async {
      await _pumpAtTextScale(
        tester,
        kycIdAlignmentGuideLongestCaptionCompact,
        1.0,
      );
      final Size frameAt100 = tester.getSize(
        find.byKey(KycIdAlignmentGuide.frameKey),
      );
      final double captionAt100 = tester.getRect(find.text(_longCaption)).height;

      await _pumpAtTextScale(
        tester,
        kycIdAlignmentGuideLongestCaptionCompact,
        2.0,
      );
      final Size frameAt200 = tester.getSize(
        find.byKey(KycIdAlignmentGuide.frameKey),
      );
      final double captionAt200 = tester.getRect(find.text(_longCaption)).height;

      expect(frameAt200, frameAt100, reason: 'a fixed maxFrameWidth + ratio');
      expect(
        captionAt200,
        greaterThan(captionAt100),
        reason: 'the caption grows under an unchanged rectangle',
      );
    });

    testWidgets('every state localizes: the AR reading is Arabic', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        kycIdAlignmentGuideProduction,
        locale: const Locale('ar'),
      );

      expect(find.text(_captionAr), findsOneWidget);
      expect(find.text(_caption), findsNothing);
      expect(
        Directionality.of(
          tester.element(find.byKey(KycIdAlignmentGuide.rootKey)),
        ),
        TextDirection.rtl,
      );
    });
  });

  // The RTL defect these previews exposed, held as assertions so it cannot
  group('KycIdAlignmentGuide corner brackets', () {
    testWidgets('LTR: the start tick hugs the frame corner (correct)', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycIdAlignmentGuideProduction);

      final Rect frame = tester.getRect(
        find.byKey(KycIdAlignmentGuide.frameKey),
      );
      expect(_cornerTicks(), findsNWidgets(4));

      final Finder startTick = _cornerTicks().first;
      final Rect tick = tester.getRect(startTick);
      expect(
        tick.left,
        lessThan(frame.center.dx),
        reason: 'the start tick sits on the LEFT in English',
      );
      // Elbow anchored at the tick's own top-left — the side facing the
      expect(
        startTick,
        paints
          ..line(p1: Offset.zero, p2: Offset(tick.width, 0))
          ..line(p1: Offset.zero, p2: Offset(0, tick.height)),
      );
    });

    testWidgets('RTL: the tick box mirrors but the elbow it paints does NOT', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        kycIdAlignmentGuideProduction,
        locale: const Locale('ar'),
      );

      final Rect frame = tester.getRect(
        find.byKey(KycIdAlignmentGuide.frameKey),
      );
      final Finder startTick = _cornerTicks().first;
      final Rect tick = tester.getRect(startTick);

      // PositionedDirectional did its job: the start tick moved to the
      expect(
        tick.left,
        greaterThan(frame.center.dx),
        reason: 'the start tick sits on the RIGHT in Arabic',
      );
      expect(
        frame.right - tick.right,
        // Spacing.small inset, plus the 1 pt border the frame's Container
        closeTo(Spacing.small + 1, 0.01),
        reason: 'inset from the trailing edge, mirrored correctly',
      );

      // The painter did not: identical local coordinates to the LTR case, so
      expect(
        startTick,
        paints
          ..line(p1: Offset.zero, p2: Offset(tick.width, 0))
          ..line(p1: Offset.zero, p2: Offset(0, tick.height)),
        reason: 'a mirrored bracket would anchor at Offset(width, 0)',
      );
    });
  });
}
