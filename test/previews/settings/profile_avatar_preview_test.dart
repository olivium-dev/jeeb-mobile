// Render tests for the ProfileAvatar previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/settings/presentation/widgets/profile_avatar.dart';

import '../preview_test_harness.dart';

/// `Sizes.tenXLarge`, the diameter every shipping call site takes.
const Size _kCircle = Size(96, 96);

/// The initial bubble's own [Container] — the one carrying the fill. It is the
/// innermost ancestor of the glyph, so `.first` is the right one.
BoxDecoration _bubble(WidgetTester tester, String glyph) {
  final Container box = tester.widget<Container>(
    find.ancestor(of: find.text(glyph), matching: find.byType(Container)).first,
  );
  return box.decoration! as BoxDecoration;
}

/// WCAG contrast between the initial's ink and the circle it sits on, read off
/// the live render tree rather than off the palette constants — the point is
double _initialContrast(WidgetTester tester, String glyph) {
  final double ink = tester
      .widget<Text>(find.text(glyph))
      .style!
      .color!
      .computeLuminance();
  final double fill = _bubble(tester, glyph).color!.computeLuminance();
  final double lighter = ink > fill ? ink : fill;
  final double darker = ink > fill ? fill : ink;
  return (lighter + 0.05) / (darker + 0.05);
}

/// Pumps [preview] and then lets REAL asynchronous work run until the widget
/// settles on something textual.
Future<void> _pumpUntilIoSettles(
  WidgetTester tester,
  Widget Function() preview,
) async {
  // The preceding test pumped the same `FileImage` and left a PENDING entry in
  imageCache.clear();
  imageCache.clearLiveImages();
  await tester.pumpWidget(previewCanvas(preview, const Locale('en')));
  for (int turn = 0; turn < 20; turn++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    if (find.byType(Text).evaluate().isNotEmpty) return;
  }
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'ProfileAvatar',
    const <String, Widget Function()>{
      'Named, no photo': profileAvatarNamed,
      'No name yet': profileAvatarNoName,
      'Arabic name': profileAvatarArabicName,
      'Phone-only synthetic handle': profileAvatarSyntheticHandle,
      'Empty photo URL': profileAvatarEmptyPhotoUrl,
      'Stale local photo path': profileAvatarStaleLocalPath,
    },
    expectedText: const <String, String>{
      'Named, no photo': 'S',
      'No name yet': '?',
      // Lam — the first letter of 'ليلى حداد' as authored, uppercased to itself.
      'Arabic name': 'ل',
      'Phone-only synthetic handle': 'J',
      'Empty photo URL': 'Z',
      // 'Stale local photo path' renders no text; see the header note and the
    },
  );

  group('ProfileAvatar preview specifics', () {
    testWidgets('shows the uppercased initial and nothing else of the name', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, profileAvatarNamed);

      expect(find.text('S'), findsOneWidget);
      expect(find.textContaining('ami'), findsNothing);
    });

    testWidgets('an Arabic initial arrives as one whole grapheme', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, profileAvatarArabicName);

      // `_initial` takes `trimmed.characters.first` — a grapheme cluster — and
      expect(tester.widget<Text>(find.text('ل')).data, 'ل');
      expect(find.textContaining('حداد'), findsNothing);
    });

    testWidgets('a whitespace-only name falls back exactly like a null one', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, profileAvatarNoName);

      // `_initial` trims BEFORE testing for empty, so '   ' and null share this
      expect(find.text('?'), findsOneWidget);
    });

    // TRIPWIRE, not an endorsement. Jeeb mints `jeeb-<hash>` display names for
    testWidgets('a synthetic handle is rendered as a name, not suppressed', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, profileAvatarSyntheticHandle);

      expect(find.text('J'), findsOneWidget);
      expect(find.text('?'), findsNothing);
    });

    testWidgets('an empty photoUrl takes the initial path, not an image path', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, profileAvatarEmptyPhotoUrl);

      // `build` short-circuits on `photoUrl!.isEmpty`. If that check is ever
      expect(find.text('Z'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });
  });

  group('ProfileAvatar local-file branch (JEBV4-13)', () {
    testWidgets('is the only state that mounts an Image, and it is textless', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, profileAvatarStaleLocalPath);

      // The negative pin that stands in for `expectedText` here: no other
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(Text), findsNothing);
      expect(tester.getSize(find.byType(ProfileAvatar)), _kCircle);

      // Textless is also the honest reading of what a user sees mid-read, and
    });

    testWidgets('degrades to the initial bubble once the read fails', (
      WidgetTester tester,
    ) async {
      await _pumpUntilIoSettles(tester, profileAvatarStaleLocalPath);

      // An avatar whose stored path no longer resolves — the iOS app-container
      expect(find.text('K'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('ProfileAvatar geometry and contrast', () {
    testWidgets('the initial scales with text size; the circle does not', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, profileAvatarNamed);

      expect(tester.getSize(find.byType(ProfileAvatar)), _kCircle);
      expect(tester.widget<Text>(find.text('S')).style!.fontSize, 36.0);
      expect(tester.getSize(find.text('S')), const Size(36, 44));

      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpPreview(tester, profileAvatarNamed);

      // `displaySmall` has no `TextScaler` clamp and `diameter` has no scaler at
      expect(tester.getSize(find.byType(ProfileAvatar)), _kCircle);
      expect(tester.getSize(find.text('S')), const Size(72, 88));
    });

    // The same 36 dp glyph is what makes the public `diameter` parameter a trap:
    testWidgets('the glyph does not shrink with the diameter knob', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, profileAvatarNamed);

      expect(
        tester.widget<ProfileAvatar>(find.byType(ProfileAvatar)).diameter,
        96.0,
      );
      // 44 dp of glyph at 1x, whatever the circle is told to be. Any caller
      expect(tester.getSize(find.text('S')).height, 44.0);
    });

    // A positive pin, and the reason this widget is worth reading next to its
    testWidgets('paints a real tone pair: 13.28:1 light, 7.23:1 dark', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, profileAvatarNamed);
      expect(_initialContrast(tester, 'S'), closeTo(13.28, 0.01));
      expect(_bubble(tester, 'S').shape, BoxShape.circle);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await pumpPreview(tester, profileAvatarNamed);

      expect(_initialContrast(tester, 'S'), closeTo(7.23, 0.01));
    });
  });
}
