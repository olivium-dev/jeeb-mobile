// Render tests for the SavedAddressesScreen previews.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/devtool/catalog/fixtures/saved_addresses_screen_fixtures.dart';
import 'package:jeeb_mobile/features/settings/presentation/screens/saved_addresses_screen.dart';

import '../preview_test_harness.dart';

/// Points the test surface at [box] at 1:1 density, undone after the test.
void _useBox(WidgetTester tester, Size box) {
  tester.view.physicalSize = box;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Applies the app's 200% accessibility ceiling — the third card of a
/// `matrix: true` preview — for the duration of the test.
void _useLargeText(WidgetTester tester) {
  tester.platformDispatcher.textScaleFactorTestValue = 2.0;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void main() {
  setUpAll(loadPreviewArbs);

  setUp(() {
    final TestWidgetsFlutterBinding binding =
        TestWidgetsFlutterBinding.ensureInitialized();
    final view = binding.platformDispatcher.views.first;
    view.physicalSize = SavedAddressesScreenFixtures.phoneBox;
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });

  testPreviewsRender(
    'SavedAddressesScreen',
    const <String, Widget Function()>{
      'Placeholder · phone': savedAddressesScreenPlaceholder,
      'Compact device': savedAddressesScreenCompact,
      'Landscape · short viewport': savedAddressesScreenLandscape,
    },
    expectedText: const <String, String>{
      'Placeholder · phone': SavedAddressesScreenFixtures.title,
      'Compact device': SavedAddressesScreenFixtures.subtitle,
      // 'Landscape · short viewport' deliberately absent — see the header.
    },
  );

  group('SavedAddressesScreen preview specifics', () {
    // What the single state actually is, pinned so "the previews render" can
    testWidgets('the one state is a bare placeholder with no affordances', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, savedAddressesScreenPlaceholder);

      expect(find.text(SavedAddressesScreenFixtures.title), findsOneWidget);
      expect(find.text(SavedAddressesScreenFixtures.subtitle), findsOneWidget);
      expect(find.byIcon(Icons.construction_outlined), findsOneWidget);
      // No app bar, so no back affordance of any kind.
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(BackButton), findsNothing);
      // No action out of the dead end either.
      expect(find.byType(ButtonStyleButton), findsNothing);
    });

    // The copy is three string literals (`title`, `subtitle`, and the
    testWidgets('an Arabic build still renders the English copy', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        savedAddressesScreenPlaceholder,
        locale: const Locale('ar'),
      );

      expect(
        Directionality.of(tester.element(find.byType(SavedAddressesScreen))),
        TextDirection.rtl,
        reason: 'the frame mirrors…',
      );
      expect(
        find.text(SavedAddressesScreenFixtures.title),
        findsOneWidget,
        reason: '…but the words do not: the screen ships string literals',
      );

      // And the Arabic the screen is ignoring is right there in the ARB.
      final String arb = File('lib/l10n/app_ar.arb').readAsStringSync();
      expect(
        arb.contains('"savedAddressesTitle"'),
        isTrue,
        reason: 'a localized title already exists for this feature',
      );
    });

    // 272pt of usable width after `EdgeInsets.all(24)`. `OmdsEmptyState` passes
    testWidgets('the compact device wraps the headline instead of truncating', (
      WidgetTester tester,
    ) async {
      _useBox(tester, SavedAddressesScreenFixtures.compactBox);
      await pumpPreview(tester, savedAddressesScreenCompact);

      final Text title =
          tester.widget<Text>(find.text(SavedAddressesScreenFixtures.title));
      expect(title.maxLines, isNull);
      expect(title.overflow, isNull);

      final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
        find.text(SavedAddressesScreenFixtures.title),
      );
      expect(
        paragraph.getMaxIntrinsicWidth(double.infinity),
        greaterThan(paragraph.size.width),
        reason: 'the headline wants more width than a 320pt phone gives it',
      );
      expect(
        paragraph.size.height,
        greaterThan(paragraph.getMinIntrinsicHeight(double.infinity)),
        reason: 'so it occupies more than one line',
      );
      expect(tester.takeException(), isNull);
    });

    // The control for the finding below: at the shipped text size the same
    testWidgets('the short viewport is fine at the default text size', (
      WidgetTester tester,
    ) async {
      _useBox(tester, SavedAddressesScreenFixtures.landscapeBox);
      await pumpPreview(tester, savedAddressesScreenLandscape);

      expect(tester.takeException(), isNull);
      expect(find.text(SavedAddressesScreenFixtures.title), findsOneWidget);
    });

    // The height ceiling, and the reason the landscape card carries a matrix.
    testWidgets('the short viewport clips its content at 200% text', (
      WidgetTester tester,
    ) async {
      _useBox(tester, SavedAddressesScreenFixtures.landscapeBox);
      _useLargeText(tester);
      await tester.pumpWidget(
        previewCanvas(savedAddressesScreenLandscape, const Locale('en')),
      );
      // Two frames: `Scaffold` measures its body through `_BodyBuilder`, so the
      await tester.pump();

      final Object? overflow = tester.takeException();
      expect(
        overflow,
        isA<FlutterError>().having(
          (FlutterError e) => e.toString(),
          'message',
          contains('overflowed by'),
        ),
        reason: 'the empty-state Column has no room on a 390pt-tall viewport '
            'once the text is doubled',
      );
      expect(
        find.byType(Scrollable),
        findsNothing,
        reason: 'and nothing in this screen scrolls, so the clipped content is '
            'unreachable rather than merely below the fold',
      );
    });

    // The same content at the same 200%, in the reference phone box — so the
    testWidgets('the phone box has room for the same content at 200% text', (
      WidgetTester tester,
    ) async {
      _useLargeText(tester);
      await pumpPreview(tester, savedAddressesScreenPlaceholder);

      expect(tester.takeException(), isNull);
      expect(find.text(SavedAddressesScreenFixtures.title), findsOneWidget);
      expect(find.text(SavedAddressesScreenFixtures.subtitle), findsOneWidget);
    });

    // The catalog and the canvas must be showing the same state. If someone
    testWidgets('the previews and the catalog share one fixture', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, savedAddressesScreenPlaceholder);

      expect(find.byType(SavedAddressesScreen), findsOneWidget);
      expect(
        SavedAddressesScreenFixtures.placeholder(),
        isA<SavedAddressesScreen>(),
      );
      expect(
        SavedAddressesScreenFixtures.semanticsLabel,
        '${SavedAddressesScreenFixtures.title}. '
            '${SavedAddressesScreenFixtures.subtitle}',
      );
    });
  });
}
