// Render tests for the SettingsScreen previews.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/devtool/catalog/fixtures/settings_screen_fixtures.dart';
import 'package:jeeb_mobile/features/settings/presentation/screens/settings_screen.dart';

import '../preview_test_harness.dart';

/// Phone width, and tall enough that the whole list is built in one pass.
const Size _kTallListSurface = Size(390, 2600);

/// Same height, wide enough not to squeeze the compact previews further than
/// the 320 pt they pin in the tree.
const Size _kTallCompactSurface = Size(360, 2600);

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'SettingsScreen',
    const <String, Widget Function()>{
      'Loaded · name + phone': settingsScreenLoaded,
      'Empty · phone only, no name': settingsScreenPhoneOnly,
      'Loading · cold read in flight': settingsScreenColdLoad,
      'Deletion pending · row latched': settingsScreenDeletionPending,
      'Destructive actions in flight': settingsScreenDestructiveInFlight,
      'Longest content · compact 320': settingsScreenLongestContentCompact,
    },
    expectedText: const <String, String>{
      // The reference customer, as the profile row's TITLE.
      'Loaded · name + phone': SettingsScreenPreviewFixtures.sampleName,
      // No name yet, so the row falls back to the placeholder title and the
      'Empty · phone only, no name':
          SettingsScreenPreviewFixtures.phoneOnlyPhone,
      // Nothing is hydrated yet, so there is no phone for the subtitle — the
      'Loading · cold read in flight': 'Update your name and avatar',
      'Deletion pending · row latched':
          SettingsScreenPreviewFixtures.pendingName,
      'Destructive actions in flight':
          SettingsScreenPreviewFixtures.inFlightName,
      'Longest content · compact 320':
          SettingsScreenPreviewFixtures.longestName,
    },
  );

  group('SettingsScreen preview specifics', () {
    /// Pumps [preview] with the surface tall enough to build every section.
    /// The `size:` on `@JeebPreview` is honoured by the preview canvas only;
    Future<void> pumpWholeList(
      WidgetTester tester,
      Widget Function() preview, {
      Size surface = _kTallListSurface,
      Locale locale = const Locale('en'),
    }) async {
      await tester.binding.setSurfaceSize(surface);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpPreview(tester, preview, locale: locale);
    }

    /// The [ListTile] the row with [key] rendered, so assertions read the
    /// RESULT of `enabled:` rather than the argument passed to it.
    ListTile tileOf(WidgetTester tester, Key key) => tester.widget<ListTile>(
          find.descendant(of: find.byKey(key), matching: find.byType(ListTile)),
        );

    // ── The cold read ─────────────────────────────────────────────────────

    testWidgets('cold read · no affordance, and the row is still tappable', (
      WidgetTester tester,
    ) async {
      await pumpWholeList(tester, settingsScreenColdLoad);

      // `isLoading` is true and nothing on screen says so: no spinner, no
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Add your name'), findsOneWidget);
      // And the Profile row still pushes `settings-profile` mid-read.
      expect(tileOf(tester, const Key('settings-row-profile')).onTap, isNotNull);
    });

    testWidgets('cold read differs from "no name saved" by ONE subtitle', (
      WidgetTester tester,
    ) async {
      await pumpWholeList(tester, settingsScreenColdLoad);
      expect(find.text('Add your name'), findsOneWidget);
      expect(find.text('Update your name and avatar'), findsOneWidget);

      await pumpWholeList(tester, settingsScreenPhoneOnly);
      // Same title, same everything else — only the subtitle tells a user
      expect(find.text('Add your name'), findsOneWidget);
      expect(find.text('Update your name and avatar'), findsNothing);
      expect(
        find.text(SettingsScreenPreviewFixtures.phoneOnlyPhone),
        findsOneWidget,
      );
    });

    // ── The Account section ───────────────────────────────────────────────

    testWidgets('deletion pending · delete is dead, sign-out is not', (
      WidgetTester tester,
    ) async {
      await pumpWholeList(tester, settingsScreenDeletionPending);

      // E20 (JEBV4-215): the latched copy REPLACES the destructive subtitle.
      expect(
        find.text('Scheduled for deletion. Sign in again to cancel.'),
        findsOneWidget,
      );
      expect(find.text('Permanently remove your Jeeb account'), findsNothing);

      final ListTile delete =
          tileOf(tester, const Key('settings-row-delete-account'));
      final ListTile signOut =
          tileOf(tester, const Key('settings-row-sign-out'));
      expect(delete.enabled, isFalse);
      expect(delete.onTap, isNull);
      // Signing in again is how the purge is cancelled, so sign-out must stay
      expect(signOut.enabled, isTrue);
      expect(signOut.onTap, isNotNull);
    });

    testWidgets('in flight · both rows dead, and nothing says why', (
      WidgetTester tester,
    ) async {
      await pumpWholeList(tester, settingsScreenDestructiveInFlight);

      expect(
        tileOf(tester, const Key('settings-row-delete-account')).onTap,
        isNull,
      );
      expect(tileOf(tester, const Key('settings-row-sign-out')).onTap, isNull);
      // No spinner, no banner: the only feedback is two rows at 38% opacity.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      // Not latched — the delete row still carries its destructive copy.
      expect(find.text('Permanently remove your Jeeb account'), findsOneWidget);
    });

    testWidgets('loaded · both Account rows are live', (
      WidgetTester tester,
    ) async {
      await pumpWholeList(tester, settingsScreenLoaded);

      expect(
        tileOf(tester, const Key('settings-row-delete-account')).onTap,
        isNotNull,
      );
      expect(tileOf(tester, const Key('settings-row-sign-out')).onTap, isNotNull);
      expect(find.byType(SnackBar), findsNothing);
    });

    // ── The seating the host supplies ─────────────────────────────────────

    testWidgets('the language check follows the AMBIENT locale', (
      WidgetTester tester,
    ) async {
      // The host seeds its LocaleCubit from `Localizations.localeOf`, so the
      Widget? checkOf(WidgetTester tester, String key) => tester
          .widget<OmdsSettingsRow>(find.byKey(Key(key)))
          .trailing;

      await pumpWholeList(tester, settingsScreenLoaded);
      expect(checkOf(tester, 'settings-row-language-en'), isNotNull);
      expect(checkOf(tester, 'settings-row-language-ar'), isNull);

      await pumpWholeList(
        tester,
        settingsScreenLoaded,
        locale: const Locale('ar'),
      );
      expect(checkOf(tester, 'settings-row-language-en'), isNull);
      expect(checkOf(tester, 'settings-row-language-ar'), isNotNull);
    });

    // ── The layout ceiling ────────────────────────────────────────────────

    testWidgets('compact 320 · the longest name wraps, and the row grows', (
      WidgetTester tester,
    ) async {
      await pumpWholeList(
        tester,
        settingsScreenLongestContentCompact,
        surface: _kTallCompactSurface,
      );

      // `OmdsSettingsRow` gives its title Text no maxLines and no overflow, so
      final RenderParagraph longest = tester.renderObject<RenderParagraph>(
        find.text(SettingsScreenPreviewFixtures.longestName),
      );
      // "App version" is the shortest row title on the screen and cannot wrap
      final RenderParagraph oneLine =
          tester.renderObject<RenderParagraph>(find.text('App version'));
      expect(longest.textSize.height, greaterThan(oneLine.textSize.height));
      // Wrapped, not clipped: every laid-out line is inside the paragraph box.
      expect(longest.textSize.height, lessThanOrEqualTo(longest.size.height));

      // Opted out of everything: the four switch rows render OFF.
      final Iterable<Switch> switches =
          tester.widgetList<Switch>(find.byType(Switch));
      expect(switches, hasLength(4));
      expect(switches.every((Switch s) => s.value == false), isTrue);
    });
  });
}
