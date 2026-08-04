// Render tests for the GpsDeniedState previews.

// `Tristate` is a dart:ui type that `package:flutter/semantics.dart` does not
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/location/presentation/widgets/gps_denied_state.dart';

import '../preview_test_harness.dart';

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Full phone slot · CTA wired': gpsDeniedStateWiredCta,
  'Default constructor · CTA dead': gpsDeniedStateNoCallback,
  'Compact 320pt phone': gpsDeniedStateCompactPhone,
  'Short map card (200pt)': gpsDeniedStateShortCard,
  'Landscape phone (740×360)': gpsDeniedStateLandscape,
};

/// The single [Column] inside the widget — its size IS the height the content
/// demands, now measured inside the scroll view rather than against the slot.
final Finder _content = find.descendant(
  of: find.byType(GpsDeniedState),
  matching: find.byType(Column),
);

/// The composed illustration block. `JeebEmptyState` draws it as the block's
/// only [FittedBox], the same anchor the frozen kit suite uses.
final Finder _illustration = find
    .descendant(
      of: find.byType(GpsDeniedState),
      matching: find.byType(FittedBox),
    )
    .first;

/// What the M4 sweep added, and what every geometry claim below rests on.
final Finder _scrollable = find.descendant(
  of: find.byType(GpsDeniedState),
  matching: find.byType(Scrollable),
);

final Finder _cta = find.text('Open Settings');

/// The tappable core `JeebCtaButton` builds for the CTA.
final Finder _ctaGesture = find
    .descendant(
      of: find.byType(GpsDeniedState),
      matching: find.byType(GestureDetector),
    )
    .first;

/// How much taller than its slot the content is. Zero means it fits outright.
double _absorbedByScrolling(WidgetTester tester) =>
    tester.state<ScrollableState>(_scrollable).position.maxScrollExtent;

/// Pumps [preview] into a real device box instead of the 800x600 test surface,
/// optionally at a raised text scale.
Future<void> _pumpAt(
  WidgetTester tester,
  Widget Function() preview, {
  required Size size,
  double textScale = 1.0,
  Locale locale = const Locale('en'),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: previewCanvas(preview, locale),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'GpsDeniedState',
    _previews,
    expectedText: const <String, String>{
      'Full phone slot · CTA wired': 'Full phone slot · CTA wired',
      'Default constructor · CTA dead': 'Default constructor · CTA dead',
      'Compact 320pt phone': 'Compact 320pt phone',
      'Short map card (200pt)': 'Short map card (200pt)',
      'Landscape phone (740×360)': 'Landscape phone (740×360)',
    },
  );

  group('GpsDeniedState preview wiring', () {
    testWidgets('every state renders the shipped ARB copy', (
      WidgetTester tester,
    ) async {
      // The widget takes no copy arguments, so this is what AC4 says today. If
      await pumpPreview(tester, gpsDeniedStateWiredCta);

      expect(find.text('Location access required'), findsOneWidget);
      expect(
        find.text('Grant location permission to pin your drop-off point.'),
        findsOneWidget,
      );
      expect(_cta, findsOneWidget);
    });

    testWidgets('the wired CTA is really live', (WidgetTester tester) async {
      // A preview wired to `() {}` looks identical to one wired to nothing at
      await pumpPreview(tester, gpsDeniedStateWiredCta);
      expect(find.text('settings opened 0'), findsOneWidget);

      await tester.tap(_cta);
      await tester.pumpAndSettle();

      expect(find.text('settings opened 1'), findsOneWidget);
    });

    testWidgets('the default constructor ships a CTA that cannot be tapped', (
      WidgetTester tester,
    ) async {
      // `isEnabled: onOpenSettings != null` — so `const GpsDeniedState()` is a
      await pumpPreview(tester, gpsDeniedStateNoCallback);
      expect(_cta, findsOneWidget);

      await tester.tap(_cta);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('settings opened'), findsNothing);
    });
  });

  group('GpsDeniedState preview a11y', () {
    testWidgets('the CTA carries the button role, not just a tap action', (
      WidgetTester tester,
    ) async {
      // Disposed inline rather than in a tearDown: the end-of-test handle
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpPreview(tester, gpsDeniedStateWiredCta);

      final SemanticsData data =
          tester.getSemantics(_ctaGesture).getSemanticsData();

      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.label, 'Open Settings');

      // The gap the M4 sweep closed: the CTA now sits inside an explicit
      // `Semantics(button: true)`, so it announces as a button, not as text.
      expect(data.flagsCollection.isButton, isTrue);

      handle.dispose();
    });

    testWidgets('the disabled CTA exposes no tap action either', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpPreview(tester, gpsDeniedStateNoCallback);

      final SemanticsData data =
          tester.getSemantics(_ctaGesture).getSemanticsData();

      // Not merely inert to touch: with `onTap` null the node carries no tap
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      expect(data.flagsCollection.isEnabled, Tristate.none);

      handle.dispose();
    });

    testWidgets(
      'the illustration is a fixed 300 pt block that does not follow the text '
      'scaler',
      (WidgetTester tester) async {
        await _pumpAt(
          tester,
          gpsDeniedStateWiredCta,
          size: const Size(390, 1400),
        );
        expect(tester.getSize(_illustration), const Size(300, 300));

        await _pumpAt(
          tester,
          gpsDeniedStateWiredCta,
          size: const Size(390, 1400),
          textScale: 2.0,
        );

        // Kit contract, not an oversight: `illustrationSize` is a raw logical
        // width and the medallions pin `TextScaler.noScaling`.
        expect(tester.getSize(_illustration), const Size(300, 300));
      },
    );
  });

  group('GpsDeniedState preview geometry', () {
    testWidgets('the body scrolls, so a short slot cannot clip it', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, gpsDeniedStateWiredCta);

      // The font-independent root cause of every overflow below, now closed:
      expect(_scrollable, findsOneWidget);
      expect(
        tester.state<ScrollableState>(_scrollable).position.axis,
        Axis.vertical,
      );
    });

    testWidgets(
      'the text half of the content doubles at the 200% ceiling, the '
      'illustration does not',
      (WidgetTester tester) async {
        const Size tall = Size(390, 1400);

        await _pumpAt(tester, gpsDeniedStateWiredCta, size: tall);
        final double artAtDefault = tester.getSize(_illustration).height;
        final double atDefault = tester.getSize(_content).height;

        await _pumpAt(
          tester,
          gpsDeniedStateWiredCta,
          size: tall,
          textScale: 2.0,
        );
        final double artAtCeiling = tester.getSize(_illustration).height;
        final double atCeiling = tester.getSize(_content).height;

        // Measured on a slot tall enough that neither reading scrolls, so the
        // numbers are the content's own demand and not a clamped viewport.
        expect(artAtCeiling, artAtDefault);
        expect(
          atCeiling - artAtCeiling,
          greaterThan(1.9 * (atDefault - artAtDefault)),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('the short map card scrolls instead of overflowing', (
      WidgetTester tester,
    ) async {
      // The box this preview declares to the canvas: 390x200. Roughly 210 pt
      await _pumpAt(tester, gpsDeniedStateShortCard, size: const Size(390, 200));

      expect(tester.takeException(), isNull);
      expect(
        _absorbedByScrolling(tester),
        greaterThan(0),
        reason: 'the content is still taller than a fixed-height map card: '
            'scrolling, not shrinking, is what absorbs it',
      );
    });

    testWidgets('landscape holds at the 200% ceiling by scrolling', (
      WidgetTester tester,
    ) async {
      // Same slot from the accessibility side: at default text this state
      await _pumpAt(tester, gpsDeniedStateLandscape, size: const Size(740, 360));
      expect(tester.takeException(), isNull);

      await _pumpAt(
        tester,
        gpsDeniedStateLandscape,
        size: const Size(740, 360),
        textScale: 2.0,
      );

      expect(tester.takeException(), isNull);
      expect(_absorbedByScrolling(tester), greaterThan(0));
    });

    testWidgets(
      'a compact phone at 200% scrolls its FULL screen body instead of '
      'overflowing',
      (WidgetTester tester) async {
        // The worst of the three, because there is no host to blame: 320x560 is
        await _pumpAt(
          tester,
          gpsDeniedStateCompactPhone,
          size: const Size(320, 560),
          textScale: 2.0,
        );

        expect(tester.takeException(), isNull);
        expect(_absorbedByScrolling(tester), greaterThan(0));
      },
    );
  });

  group('GpsDeniedState preview localization', () {
    testWidgets('the copy localizes and the layout stays centred', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        gpsDeniedStateWiredCta,
        locale: const Locale('ar'),
      );

      expect(find.text('مطلوب إذن الموقع'), findsOneWidget);
      expect(find.text('فتح الإعدادات'), findsOneWidget);
      expect(find.text('Location access required'), findsNothing);

      // The padding is [EdgeInsetsDirectional] and the column is centred, so
      final Rect widgetBox = tester.getRect(find.byType(GpsDeniedState));
      final Rect content = tester.getRect(_content);
      expect(
        content.left - widgetBox.left,
        moreOrLessEquals(widgetBox.right - content.right, epsilon: 0.5),
      );
    });
  });
}
