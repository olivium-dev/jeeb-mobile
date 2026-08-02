// Render tests for the SettingsScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// Two things shape this file.
//
// **What `expectedText` can and cannot prove HERE.** Two of the six states
// differ from the reference only in the Account section — a latched row, two
// greyed rows — which sits at the BOTTOM of a six-section [ListView]. The
// shared suite pumps onto the tester's default 800x600 surface, where that
// section is never built, so it cannot see any of it. Each fixture therefore
// carries its own account holder in the FIRST row (see
// `settings_screen_fixtures.dart`), which is what the shared suite pins: proof
// that each preview renders its own fixture. Proof that each renders its own
// STATE lives in the `preview specifics` group, which sets a surface tall
// enough to build the whole list — the same thing `test/settings_screen_test.dart`
// does, for the same reason.
//
// **Disablement, not copy, is what separates these states.** A latched or
// in-flight row carries the same strings as a live one and differs by
// `onTap == null` and 38% opacity, so every assertion below reads the
// [ListTile] the row actually built rather than the flag handed to it.

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
      // registration phone is the only thing that identifies this state.
      'Empty · phone only, no name':
          SettingsScreenPreviewFixtures.phoneOnlyPhone,
      // Nothing is hydrated yet, so there is no phone for the subtitle — the
      // generic profile-edit copy is the tell, and no other state shows it.
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
    ///
    /// The `size:` on `@JeebPreview` is honoured by the preview canvas only;
    /// calling the function alone gets the tester's 800x600 desktop surface,
    /// which builds the top three sections of this list and nothing else.
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
      // shimmer, no disabled row.
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
      // whose read is still in flight from a user who never set a name.
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
      // reachable — a latched row that disabled both would strand the user.
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
      // AR card of a matrix checks العربية instead of showing an Arabic list
      // with the English row ticked.
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
      // the name wraps instead of ellipsizing: the laid-out paragraph is
      // taller than a single-line row title.
      final RenderParagraph longest = tester.renderObject<RenderParagraph>(
        find.text(SettingsScreenPreviewFixtures.longestName),
      );
      // "App version" is the shortest row title on the screen and cannot wrap
      // at 320 pt, so it is the single-line reference.
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
