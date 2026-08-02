// Render tests for the ObsOverlayPanelHeader previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// One deviation from that template, on purpose — the same one
// `delivery_confirm_illustration_preview_test.dart` makes. The widget under
// review renders ONE constant string ("Session Trace") in every state, so the
// `expectedText` map below binds to each preview's caption, which is preview
// scaffolding rather than widget output. On its own that would be exactly the
// weak assertion the harness warns about: it would pass even if all five
// previews drew the same row. The real per-state contract is asserted
// underneath, by MEASURING the header for every state. This widget's only
// inputs are its constraints, its `Directionality` and the text scaler, so its
// geometry *is* its state.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/observability/session_trace/presentation/widgets/obs_overlay_panel_header.dart';
import 'package:jeeb_mobile/previews/core/obs_overlay_panel_header_preview.dart';

import '../preview_test_harness.dart';

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Panel (production, 390pt)': obsOverlayPanelHeaderInPanel,
  'Compact device (320pt)': obsOverlayPanelHeaderCompactDevice,
  'Wrapping title (160pt)': obsOverlayPanelHeaderWrappingTitle,
  'Bare full-width host': obsOverlayPanelHeaderFullWidthHost,
  'Fixed 40pt slot (tap target shrinks)': obsOverlayPanelHeaderFixedHeightSlot,
};

/// The content width each host hands the header. Not copied from a run —
/// this is the arithmetic the hosts promise: the panel caps at 340 and pads
/// 16 a side (`340 − 32 = 308`), the compact phone gets `320 − 24 = 296` of
/// card (`296 − 32 = 264`), and the bare host gets the whole 390.
const Map<String, double> _expectedWidths = <String, double>{
  'Panel (production, 390pt)': 308,
  'Compact device (320pt)': 264,
  'Wrapping title (160pt)': 128,
  'Bare full-width host': 390,
  'Fixed 40pt slot (tap target shrinks)': 308,
};

/// The 48pt Material minimum touch target, which is also the height a
/// single-line header inherits from its `IconButton`.
const double _kMinTapTarget = kMinInteractiveDimension;

final Finder _closeButton = find.byKey(const Key('obs-overlay-close'));
final Finder _title = find.text('Session Trace');

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'ObsOverlayPanelHeader',
    _previews,
    expectedText: const <String, String>{
      'Panel (production, 390pt)': 'Panel host: 340pt card on a 390pt phone',
      'Compact device (320pt)': 'Compact host: 296pt card on a 320pt phone',
      'Wrapping title (160pt)': 'Wrap threshold: 160pt host',
      'Bare full-width host': 'Bare host: full 390pt width, no padding',
      'Fixed 40pt slot (tap target shrinks)':
          'Fixed slot: 40pt tall, tap target clipped',
    },
  );

  group('ObsOverlayPanelHeader preview specifics', () {
    // Every preview shares one inert controller (see the preview library doc),
    // so a test that taps the close button would otherwise leak `expanded`
    // into the next test.
    setUp(() {
      if (obsOverlayPanelHeaderPreviewController.expanded) {
        obsOverlayPanelHeaderPreviewController.toggleExpanded();
      }
    });

    // The assertion the caption-based `expectedText` above cannot make: five
    // previews of a widget with no content state are only five states if the
    // rows they lay out are distinct.
    _expectedWidths.forEach((String state, double width) {
      testWidgets('$state lays out ${width}pt wide', (
        WidgetTester tester,
      ) async {
        await pumpPreview(tester, _previews[state]!);

        expect(
          tester.getSize(find.byType(ObsOverlayPanelHeader)).width,
          closeTo(width, 0.05),
        );
      });
    });

    testWidgets('no two previews render the same box', (
      WidgetTester tester,
    ) async {
      final List<Size> sizes = <Size>[];
      for (final Widget Function() preview in _previews.values) {
        await pumpPreview(tester, preview);
        sizes.add(tester.getSize(find.byType(ObsOverlayPanelHeader)));
      }

      expect(
        sizes.toSet().length,
        sizes.length,
        reason: 'a preview set whose states all lay out the same row is a set '
            'of one state with five names',
      );
    });

    testWidgets('an unbounded-height host gives the row the 48pt button height',
        (WidgetTester tester) async {
      for (final String state in const <String>[
        'Panel (production, 390pt)',
        'Compact device (320pt)',
        'Bare full-width host',
      ]) {
        await pumpPreview(tester, _previews[state]!);

        expect(
          tester.getSize(find.byType(ObsOverlayPanelHeader)).height,
          _kMinTapTarget,
          reason: '$state: one line of title is shorter than the close '
              'button, so the button sets the row height',
        );
        expect(tester.getSize(_closeButton), const Size(48, 48));
      }
    });

    testWidgets('a narrow host wraps the title instead of clipping it', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, obsOverlayPanelHeaderWrappingTitle);

      // The title `Text` sets no `maxLines` and no `overflow`, so it must
      // degrade by growing rather than by an ellipsis or an overflow stripe.
      // (How MANY lines depends on the font — the test font is monospaced and
      // wider than the shipped one — so this asserts the behaviour, not a
      // line count.)
      final double titleHeight = tester.getSize(_title).height;
      final double rowHeight =
          tester.getSize(find.byType(ObsOverlayPanelHeader)).height;
      expect(titleHeight, greaterThan(_kMinTapTarget));
      expect(rowHeight, titleHeight,
          reason: 'once wrapped, the title is what sets the row height');
      expect(tester.takeException(), isNull);
    });

    testWidgets('the close button never leaves the row, LTR or RTL', (
      WidgetTester tester,
    ) async {
      for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
        for (final MapEntry<String, Widget Function()> entry
            in _previews.entries) {
          await pumpPreview(tester, entry.value, locale: locale);

          final Rect row = tester.getRect(find.byType(ObsOverlayPanelHeader));
          final Rect button = tester.getRect(_closeButton);
          expect(
            button.left >= row.left - 0.05 && button.right <= row.right + 0.05,
            isTrue,
            reason: '${entry.key} · ${locale.languageCode}: the close button '
                'is the only way back to the collapsed bubble — it must never '
                'be pushed outside the row',
          );
        }
      }
    });

    testWidgets('the row mirrors in RTL', (WidgetTester tester) async {
      await pumpPreview(tester, obsOverlayPanelHeaderInPanel);
      Rect row = tester.getRect(find.byType(ObsOverlayPanelHeader));
      expect(tester.getRect(_closeButton).right, closeTo(row.right, 0.05));
      expect(tester.getRect(_title).left, closeTo(row.left, 0.05));

      await pumpPreview(
        tester,
        obsOverlayPanelHeaderInPanel,
        locale: const Locale('ar'),
      );
      row = tester.getRect(find.byType(ObsOverlayPanelHeader));
      expect(
        tester.getRect(_closeButton).left,
        closeTo(row.left, 0.05),
        reason: 'the close button must move to the leading edge in Arabic',
      );
      expect(tester.getRect(_title).right, closeTo(row.right, 0.05));
    });

    testWidgets('the close button is really wired to toggleExpanded', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, obsOverlayPanelHeaderInPanel);
      final bool before = obsOverlayPanelHeaderPreviewController.expanded;

      await tester.tap(_closeButton);
      await tester.pumpAndSettle();

      expect(
        obsOverlayPanelHeaderPreviewController.expanded,
        !before,
        reason: 'a preview whose only control is inert reviews nothing',
      );
    });

    testWidgets('the tooltip resolves an Overlay (panel-crash regression)', (
      WidgetTester tester,
    ) async {
      // `Tooltip` resolves an `Overlay` as part of building. When the overlay
      // layer was a plain `Stack` sibling of the routed child, this close
      // button threw "No Overlay widget found" the instant the panel expanded,
      // and the substituted `ErrorWidget` reported "BOTTOM OVERFLOWED BY 99778
      // PIXELS" — see the `_ObsOverlayLayer` doc in `obs_overlay.dart`. This
      // preview mounts the header under its own private `Overlay`, the way the
      // fix does.
      await pumpPreview(tester, obsOverlayPanelHeaderInPanel);
      expect(tester.takeException(), isNull);

      await tester.longPress(_closeButton);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Close'), findsOneWidget);

      await tester.pumpAndSettle();
    });

    testWidgets('a fixed-height slot shrinks the exit below 48pt', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, obsOverlayPanelHeaderFixedHeightSlot);

      // No assertion fires, no overflow stripe is painted and nothing throws —
      // the tap target simply drops under the Material minimum, silently.
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(_closeButton).height,
        lessThan(_kMinTapTarget),
        reason: 'the header defends neither its own height nor its button’s, '
            'so a fixed-height host takes the only exit under 48pt',
      );
    });

    testWidgets('the close icon does not grow with the text scaler', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: previewCanvas(
            obsOverlayPanelHeaderCompactDevice,
            const Locale('en'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The title is a `Text` and doubles; the close button is an `Icon`, whose
      // 24pt size ignores the scaler entirely. At the accessibility ceiling the
      // header therefore grows past the button that anchors it, and the tap
      // target stays exactly where it was.
      expect(
        tester.getSize(find.byType(ObsOverlayPanelHeader)).height,
        greaterThan(_kMinTapTarget),
      );
      expect(tester.getSize(_closeButton), const Size(48, 48));
      expect(tester.takeException(), isNull);
    });

    testWidgets('both strings are English literals in Arabic too', (
      WidgetTester tester,
    ) async {
      // Recorded, not endorsed. `ObsOverlayPanelHeader` hardcodes its title and
      // its `tooltip: 'Close'` (the close button's only screen-reader label)
      // rather than reading `AppLocalizations`, so the `AR RTL dark` rendering
      // of every preview here shows English. Defensible for a tool that only
      // exists in a `--dart-define JEEB_OBS_OVERLAY=true` build; if this test
      // ever fails because those strings were localized, delete it.
      await pumpPreview(
        tester,
        obsOverlayPanelHeaderInPanel,
        locale: const Locale('ar'),
      );

      expect(find.text('Session Trace'), findsOneWidget);
      expect(
        find.byTooltip('Close'),
        findsOneWidget,
        reason: 'the tooltip doubles as the semantics label for the only '
            'control in the row',
      );
    });
  });
}
