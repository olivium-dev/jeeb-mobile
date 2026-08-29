import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/observability/session_trace/observability_config.dart';
import 'package:jeeb_mobile/core/observability/session_trace/presentation/widgets/obs_overlay_bubble.dart';

import '../preview_test_harness.dart';

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Docked (production geometry)': obsOverlayBubbleDocked,
  'Over the bottom nav bar': obsOverlayBubbleOverBottomNav,
  'Over a docked primary CTA': obsOverlayBubbleOverPrimaryCta,
  'Recording requested (dot is gated)': obsOverlayBubbleRecordingRequested,
  'Over the home indicator': obsOverlayBubbleOverGestureInset,
};

Rect _bubbleRect(WidgetTester tester) =>
    tester.getRect(find.byType(ObsOverlayBubble));

Rect _stageRect(WidgetTester tester) =>
    tester.getRect(find.byKey(obsOverlayBubbleStageKey));

/// The red badge dot `_BubbleIcon` adds while recording. It is a private class,
Finder _recordingDot() => find.descendant(
  of: find.byType(ObsOverlayBubble),
  matching: find.byWidgetPredicate((Widget widget) {
    if (widget is! Container) return false;
    final Decoration? decoration = widget.decoration;
    return decoration is BoxDecoration && decoration.shape == BoxShape.circle;
  }),
);

void main() {
  setUpAll(loadPreviewArbs);

  tearDown(ObservabilityConfig.instance.reset);

  testPreviewsRender(
    'ObsOverlayBubble',
    _previews,
    expectedText: const <String, String>{
      'Docked (production geometry)': 'Docked · 16/24pt bottom-right',
      'Over the bottom nav bar': 'Bottom nav · covers a tab',
      'Over a docked primary CTA': 'Primary CTA · covers 48pt',
      'Recording requested (dot is gated)': 'Recording on · dot is gated',
      'Over the home indicator': 'Home indicator · 24pt vs 34pt',
    },
  );

  group('ObsOverlayBubble preview specifics', () {
    testWidgets('docks 48x48 at 16pt/24pt from the bottom-right', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, obsOverlayBubbleDocked);

      final Rect stage = _stageRect(tester);
      final Rect bubble = _bubbleRect(tester);

      expect(
        bubble.size,
        const Size(obsOverlayBubbleDiameter, obsOverlayBubbleDiameter),
        reason:
            '24pt icon box + 12pt padding each side. Exactly the 48pt '
            'minimum tap target, with no margin above it — and it does NOT '
            'grow with textScaler, so the 200% rendering is this same circle.',
      );
      expect(
        stage.right - bubble.right,
        closeTo(obsOverlayBubbleEndInset, 0.01),
      );
      expect(
        stage.bottom - bubble.bottom,
        closeTo(obsOverlayBubbleBottomInset, 0.01),
      );
    });

    testWidgets('does not mirror in Arabic — it anchors to a physical edge', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, obsOverlayBubbleDocked);
      final Rect stage = _stageRect(tester);
      final Rect ltr = _bubbleRect(tester);

      await pumpPreview(
        tester,
        obsOverlayBubbleDocked,
        locale: const Locale('ar'),
      );
      final Rect rtl = _bubbleRect(tester);

      expect(rtl, ltr, reason: 'the bubble is anchored to the physical right');
      expect(
        stage.right - rtl.right,
        closeTo(obsOverlayBubbleEndInset, 0.01),
        reason: 'in Arabic this corner is the LEADING corner in reading order',
      );
    });

    testWidgets(
      'covers a bottom-nav destination — a different one per locale',
      (WidgetTester tester) async {
        await pumpPreview(tester, obsOverlayBubbleOverBottomNav);
        final Rect bubbleEn = _bubbleRect(tester);
        final Rect lastEn = tester.getRect(
          find.byKey(obsOverlayBubbleLastDestinationKey),
        );
        final Rect firstEn = tester.getRect(
          find.byKey(obsOverlayBubbleFirstDestinationKey),
        );

        expect(
          bubbleEn.overlaps(lastEn),
          isTrue,
          reason: 'in English the bubble sits on top of the trailing tab',
        );
        expect(bubbleEn.overlaps(firstEn), isFalse);

        expect(bubbleEn.bottom - lastEn.top, closeTo(40, 0.01));

        await pumpPreview(
          tester,
          obsOverlayBubbleOverBottomNav,
          locale: const Locale('ar'),
        );
        final Rect bubbleAr = _bubbleRect(tester);
        final Rect lastAr = tester.getRect(
          find.byKey(obsOverlayBubbleLastDestinationKey),
        );
        final Rect firstAr = tester.getRect(
          find.byKey(obsOverlayBubbleFirstDestinationKey),
        );

        expect(bubbleAr.overlaps(lastAr), isFalse);
        expect(bubbleAr.overlaps(firstAr), isTrue);
      },
    );

    testWidgets('covers the trailing 48pt of a docked primary action', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, obsOverlayBubbleOverPrimaryCta);

      final Rect bubble = _bubbleRect(tester);
      final Rect cta = tester.getRect(
        find.byKey(obsOverlayBubblePrimaryCtaKey),
      );
      final Rect covered = bubble.intersect(cta);

      expect(bubble.overlaps(cta), isTrue);
      expect(
        covered.width,
        closeTo(obsOverlayBubbleDiameter, 0.01),
        reason:
            'the whole width of the bubble is over the button: the button '
            'runs to a 16pt gutter and so does the bubble',
      );
      expect(covered.height, closeTo(40, 0.01));
      expect(
        find.text('Place order').hitTestable(),
        findsOneWidget,
        reason:
            'the label itself is centred and stays reachable — it is the '
            'trailing end of the tap area that is lost',
      );
    });

    testWidgets('reaches 10pt into a 34pt home-indicator band', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, obsOverlayBubbleOverGestureInset);

      final Rect bubble = _bubbleRect(tester);
      final Rect band = tester.getRect(
        find.byKey(obsOverlayBubbleGestureBandKey),
      );

      expect(
        bubble.overlaps(band),
        isTrue,
        reason:
            'the 24pt anchor is raw — `ObsOverlayHost` is mounted from '
            '`MaterialApp.builder`, outside any SafeArea, so nothing subtracts '
            'MediaQuery.padding.bottom from it',
      );
      expect(
        bubble.bottom - band.top,
        closeTo(
          obsOverlayBubbleGestureBandHeight - obsOverlayBubbleBottomInset,
          0.01,
        ),
      );
    });

    testWidgets(
      'the recording preview shows a dot without mutating recording',
      (WidgetTester tester) async {
        await pumpPreview(tester, obsOverlayBubbleDocked);
        expect(ObservabilityConfig.instance.enabled, isFalse);
        expect(_recordingDot(), findsNothing);

        await pumpPreview(tester, obsOverlayBubbleRecordingRequested);

        expect(ObservabilityConfig.instance.enabled, isFalse);
        expect(_recordingDot(), findsOneWidget);
      },
    );

    testWidgets('each preview stages something different under the bubble', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, obsOverlayBubbleDocked);
      expect(find.byKey(obsOverlayBubbleLastDestinationKey), findsNothing);
      expect(find.byKey(obsOverlayBubblePrimaryCtaKey), findsNothing);
      expect(find.byKey(obsOverlayBubbleGestureBandKey), findsNothing);

      await pumpPreview(tester, obsOverlayBubbleOverBottomNav);
      expect(find.byKey(obsOverlayBubbleLastDestinationKey), findsOneWidget);
      expect(find.byKey(obsOverlayBubblePrimaryCtaKey), findsNothing);

      await pumpPreview(tester, obsOverlayBubbleOverPrimaryCta);
      expect(find.byKey(obsOverlayBubblePrimaryCtaKey), findsOneWidget);
      expect(find.byKey(obsOverlayBubbleLastDestinationKey), findsNothing);

      await pumpPreview(tester, obsOverlayBubbleOverGestureInset);
      expect(find.byKey(obsOverlayBubbleGestureBandKey), findsOneWidget);
      expect(find.byKey(obsOverlayBubblePrimaryCtaKey), findsNothing);
    });

    testWidgets('announces itself with the same English label in Arabic', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpPreview(tester, obsOverlayBubbleDocked);
      expect(find.bySemanticsLabel('Session trace overlay'), findsOneWidget);

      await pumpPreview(
        tester,
        obsOverlayBubbleDocked,
        locale: const Locale('ar'),
      );
      expect(find.bySemanticsLabel('Session trace overlay'), findsOneWidget);

      handle.dispose();
    });
  });
}
