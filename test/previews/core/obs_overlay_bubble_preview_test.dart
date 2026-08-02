// Render tests for the ObsOverlayBubble previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// One deviation from that template, on purpose — the same one
// `chat/delivery_confirm_illustration_preview_test.dart` makes. The widget
// under review renders no text at all (an icon in a circle), so the
// `expectedText` map below binds to each preview's caption, which is preview
// scaffolding rather than widget output. On its own that would be exactly the
// weak assertion the harness warns about. The real per-state contract is
// asserted underneath, by MEASURING where the bubble lands and what it covers:
// this widget's state IS its geometry against the content behind it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/observability/session_trace/observability.dart';
import 'package:jeeb_mobile/core/observability/session_trace/observability_config.dart';
import 'package:jeeb_mobile/core/observability/session_trace/presentation/widgets/obs_overlay_bubble.dart';
import 'package:jeeb_mobile/previews/core/obs_overlay_bubble_preview.dart';

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
/// so it is matched by its shape: the only circular [BoxDecoration] anywhere in
/// the bubble's subtree (the bubble itself is a `Material` with a
/// `CircleBorder`, not a decorated container).
Finder _recordingDot() => find.descendant(
      of: find.byType(ObsOverlayBubble),
      matching: find.byWidgetPredicate((Widget widget) {
        if (widget is! Container) return false;
        final Decoration? decoration = widget.decoration;
        return decoration is BoxDecoration &&
            decoration.shape == BoxShape.circle;
      }),
    );

void main() {
  setUpAll(loadPreviewArbs);

  // `obsOverlayBubbleRecordingRequested` writes the global runtime switch (the
  // widget's only seam — see the preview's doc comment), so put it back.
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
        reason: '24pt icon box + 12pt padding each side. Exactly the 48pt '
            'minimum tap target, with no margin above it — and it does NOT '
            'grow with textScaler, so the 200% rendering is this same circle.',
      );
      expect(stage.right - bubble.right, closeTo(obsOverlayBubbleEndInset, 0.01));
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

      // Characterization, not endorsement: `ObsOverlayBubble` uses
      // `Positioned.right`, not `PositionedDirectional.end`, so the bubble
      // stays in the physically-right corner while the app around it flips.
      // If someone switches it to the directional variant this test fails —
      // which is the point: that is a decision worth making deliberately.
      expect(rtl, ltr, reason: 'the bubble is anchored to the physical right');
      expect(
        stage.right - rtl.right,
        closeTo(obsOverlayBubbleEndInset, 0.01),
        reason: 'in Arabic this corner is the LEADING corner in reading order',
      );
    });

    testWidgets('covers a bottom-nav destination — a different one per locale',
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

      // 64pt bar occupies 0-64pt from the bottom; the bubble occupies 24-72pt.
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

      // The bar mirrors and the bubble does not, so it covers the OTHER end of
      // the navigation — a tester who loses "Profile" in English loses "Home"
      // in Arabic instead.
      expect(bubbleAr.overlaps(lastAr), isFalse);
      expect(bubbleAr.overlaps(firstAr), isTrue);
    });

    testWidgets('covers the trailing 48pt of a docked primary action', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, obsOverlayBubbleOverPrimaryCta);

      final Rect bubble = _bubbleRect(tester);
      final Rect cta = tester.getRect(find.byKey(obsOverlayBubblePrimaryCtaKey));
      final Rect covered = bubble.intersect(cta);

      expect(bubble.overlaps(cta), isTrue);
      expect(
        covered.width,
        closeTo(obsOverlayBubbleDiameter, 0.01),
        reason: 'the whole width of the bubble is over the button: the button '
            'runs to a 16pt gutter and so does the bubble',
      );
      expect(covered.height, closeTo(40, 0.01));
      expect(
        find.text('Place order').hitTestable(),
        findsOneWidget,
        reason: 'the label itself is centred and stays reachable — it is the '
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
        reason: 'the 24pt anchor is raw — `ObsOverlayHost` is mounted from '
            '`MaterialApp.builder`, outside any SafeArea, so nothing subtracts '
            'MediaQuery.padding.bottom from it',
      );
      expect(
        bubble.bottom - band.top,
        closeTo(obsOverlayBubbleGestureBandHeight - obsOverlayBubbleBottomInset,
            0.01),
      );
    });

    testWidgets('the recording dot appears iff Observability is recording', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, obsOverlayBubbleDocked);
      expect(ObservabilityConfig.instance.enabled, isFalse);
      expect(_recordingDot(), findsNothing);

      await pumpPreview(tester, obsOverlayBubbleRecordingRequested);

      // The preview really did ask for it...
      expect(ObservabilityConfig.instance.enabled, isTrue);
      // ...but `recording` is `kObsCompiledIn && enabled`, and `kObsCompiledIn`
      // needs BOTH `JEEB_DEVTOOL_ENABLED=true` and `JEEB_OBS_OVERLAY=true` at
      // compile time. A plain `flutter test` (and a plain preview canvas) has
      // neither, so the dot is unreachable there. Asserted as the contract
      // rather than as `findsNothing` so this still passes — and still means
      // something — in a build that does carry the defines.
      expect(
        _recordingDot(),
        Observability.instance.recording ? findsOneWidget : findsNothing,
        reason: 'the badge dot must track Observability.instance.recording',
      );
    });

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
      // Hardcoded, not localized. Defensible for a devtool-only affordance —
      // but it is the one string a screen-reader user gets from this widget,
      // and it is the same string in both locales.
      expect(find.bySemanticsLabel('Session trace overlay'), findsOneWidget);

      handle.dispose();
    });
  });
}
