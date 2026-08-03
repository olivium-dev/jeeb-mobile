// Render tests for the NotificationPreferencesScreen previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/devtool/catalog/fixtures/notification_preferences_screen_fixtures.dart';
import 'package:jeeb_mobile/features/notification_prefs/domain/notification_prefs_repository.dart';
import 'package:jeeb_mobile/features/settings/presentation/screens/notification_preferences_screen.dart';

import '../preview_test_harness.dart';

/// Mirror the frames the fixture declares, so a preview quietly rewired to a
/// different window fails here instead of looking plausible in the canvas.
const Size _phoneFrame = Size(390, 844);
const Size _compactFrame = Size(320, 568);

/// The debounce the cubit is built with (`NotificationPrefsCubit` default) plus
/// slack — the previews cannot shorten it, because `NotificationPreferencesScreen`
const Duration _pastDebounce = Duration(milliseconds: 600);

void main() {
  setUpAll(loadPreviewArbs);

  // Every preview whose surface settles. `Loading` is excluded and gets its own
  testPreviewsRender(
    'NotificationPreferencesScreen',
    const <String, Widget Function()>{
      'Loaded · defaults': notificationPreferencesScreenLoaded,
      'Loaded · everything off': notificationPreferencesScreenAllOff,
      'Error · fetch failed': notificationPreferencesScreenError,
      'Loaded · the save will fail': notificationPreferencesScreenSaveFails,
      'Loaded · transactional unlocked':
          notificationPreferencesScreenTransactionalUnlocked,
      'Loaded · compact · 200% text':
          notificationPreferencesScreenCompactLargeText,
    },
    // Each state names its own fixture. The screen shows the same rows, the
    expectedText: const <String, String>{
      'Loaded · defaults': 'Loaded · defaults · phone 390 × 844',
      'Loaded · everything off': 'Loaded · everything off · phone 390 × 844',
      'Error · fetch failed': 'Error · fetch failed · phone 390 × 844',
      'Loaded · the save will fail':
          'Loaded · the save will fail · phone 390 × 844',
      'Loaded · transactional unlocked':
          'Loaded · transactional unlocked · phone 390 × 844',
      'Loaded · compact · 200% text':
          'Loaded · defaults · compact 320 × 568 · 200% text',
    },
  );

  group('NotificationPreferencesScreen previews · Loading', () {
    // A `CircularProgressIndicator` animates forever, so this state gets the
    Future<void> pumpSpinning(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(
        previewCanvas(notificationPreferencesScreenLoading, locale),
      );
      await tester.pump(); // resolve localizations + the nested Router
      await tester.pump(); // let the cubit's first emit land
      await tester.pump(const Duration(milliseconds: 16)); // one spinner frame
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Loading · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpSpinning(tester, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Loading renders its own state', (WidgetTester tester) async {
      await pumpSpinning(tester);

      expect(find.text('Loading · phone 390 × 844'), findsOneWidget);
      // The centered spinner is up...
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // ...and neither settled surface is. That combination is true of no
      expect(find.byType(OmdsSettingsSwitchRow), findsNothing);
      expect(find.text('Retry'), findsNothing);
    });
  });

  group('NotificationPreferencesScreen preview specifics', () {
    /// The switch values, top to bottom: offers, order status, wallet,
    /// marketing, and the locked transactional row.
    List<bool> switchValues(WidgetTester tester) => tester
        .widgetList<OmdsSettingsSwitchRow>(find.byType(OmdsSettingsSwitchRow))
        .map((OmdsSettingsSwitchRow r) => r.value)
        .toList();

    /// Pumps [preview] onto an EMPTY tree.
    /// Calling `pumpPreview` twice in one test reconciles the second preview
    Future<void> pumpFresh(
      WidgetTester tester,
      Widget Function() preview,
    ) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpPreview(tester, preview);
    }

    testWidgets('the loaded fixtures really do differ in their switches', (
      WidgetTester tester,
    ) async {
      // The whole reason the expected strings above are captions: THIS is the
      await pumpFresh(tester, notificationPreferencesScreenLoaded);
      expect(
        switchValues(tester),
        // Operational categories on, marketing off (the consent-friendly
        <bool>[true, true, true, false, true],
      );

      await pumpFresh(tester, notificationPreferencesScreenAllOff);
      expect(
        switchValues(tester),
        // Everything the user is allowed to turn off, off — and the locked row
        <bool>[false, false, false, false, true],
      );
    });

    testWidgets('the locked transactional row is on AND not toggleable', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, notificationPreferencesScreenAllOff);

      final OmdsSettingsSwitchRow locked = tester
          .widgetList<OmdsSettingsSwitchRow>(
            find.byType(OmdsSettingsSwitchRow),
          )
          .last;
      expect(locked.value, isTrue);
      expect(locked.enabled, isFalse);
      expect(locked.onChanged, isNull);
      expect(
        find.bySemanticsIdentifier('notif_prefs_transactional_lock_icon'),
        findsOneWidget,
      );
    });

    testWidgets(
      'transactionalLocked:false takes the whole Security section away',
      (WidgetTester tester) async {
        // Including `notif_prefs_transactional_lock_icon`, which JM-058 AC2 and
        await pumpPreview(
          tester,
          notificationPreferencesScreenTransactionalUnlocked,
        );

        expect(find.text('Security'), findsNothing);
        expect(find.text('Security codes'), findsNothing);
        expect(
          find.bySemanticsIdentifier('notif_prefs_transactional_lock_icon'),
          findsNothing,
        );
        // The four toggleable categories are untouched.
        expect(switchValues(tester), <bool>[true, true, true, false]);
      },
    );

    testWidgets('a failed fetch loses its own classification', (
      WidgetTester tester,
    ) async {
      // `NotificationPrefsCubit` maps the repository failure onto a
      Future<void> pumpFailure(NotificationPrefsFailure failure) => pumpFresh(
            tester,
            () => NotificationPreferencesScreenPreviewHost(
              caption: 'Error · $failure',
              window: NotificationPreferencesScreenWindows.phone,
              screen: NotificationPreferencesScreen(
                repository: NotificationPreferencesScreenFakeRepository(
                  fetchFailure: failure,
                ),
              ),
            ),
          );

      await pumpFailure(NotificationPrefsFailure.network);
      expect(
        find.text("Couldn't load your notification preferences."),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);

      await pumpFailure(NotificationPrefsFailure.unknown);
      expect(
        find.text("Couldn't load your notification preferences."),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('a failing save flips the row, then flips it back silently', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, notificationPreferencesScreenSaveFails);

      // Marketing defaults OFF.
      expect(switchValues(tester)[3], isFalse);

      await tester.tap(
        find.bySemanticsIdentifier('notif_prefs_marketing_toggle'),
      );
      await tester.pump();

      // Optimistic: it is on immediately, and NOTHING marks the write as
      expect(switchValues(tester)[3], isTrue);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final OmdsSettingsSwitchRow marketing = tester
          .widgetList<OmdsSettingsSwitchRow>(
            find.byType(OmdsSettingsSwitchRow),
          )
          .elementAt(3);
      expect(marketing.enabled, isTrue);

      // 500 ms debounce, then the PATCH throws (D30).
      await tester.pump(_pastDebounce);
      await tester.pump();

      expect(switchValues(tester)[3], isFalse, reason: 'reverted');
      expect(
        find.text("Couldn't save your preference. It has been reverted."),
        findsOneWidget,
      );

      // The snackbar is the ONLY feedback this screen ever gives about a save,
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('back pops to /settings, never to customer-profile', (
      WidgetTester tester,
    ) async {
      // The production stack. `settings-notifications` is declared as a CHILD
      await pumpPreview(tester, notificationPreferencesScreenLoaded);

      await tester.tap(find.bySemanticsIdentifier('notif_prefs_back'));
      await tester.pumpAndSettle();

      expect(
        find.text(notificationPreferencesScreenSettingsStandInLabel),
        findsOneWidget,
      );
      expect(
        find.text(notificationPreferencesScreenProfileStandInLabel),
        findsNothing,
      );
    });

    testWidgets('the goNamed(customer-profile) fallback needs a flat stack', (
      WidgetTester tester,
    ) async {
      // Not a preview: no route into this screen produces a flat stack, so this
      await pumpPreview(
        tester,
        () => const NotificationPreferencesScreenPreviewHost(
          poppable: false,
          caption: 'Loaded · flat stack (no route produces this)',
          window: NotificationPreferencesScreenWindows.phone,
          screen: NotificationPreferencesScreen(
            repository: NotificationPreferencesScreenFakeRepository(
              prefs: notificationPreferencesScreenDefaultPrefs,
            ),
          ),
        ),
      );

      await tester.tap(find.bySemanticsIdentifier('notif_prefs_back'));
      await tester.pumpAndSettle();

      expect(
        find.text(notificationPreferencesScreenProfileStandInLabel),
        findsOneWidget,
      );
    });

    testWidgets(
      'at the ceiling the locked row is below the fold, and not built',
      (WidgetTester tester) async {
        await pumpFresh(tester, notificationPreferencesScreenCompactLargeText);

        // Nothing overflows — `SwitchListTile` wraps its title column inside
        expect(tester.takeException(), isNull);
        final ScrollableState body = tester.state<ScrollableState>(
          find.descendant(
            of: find.byType(NotificationPreferencesScreen),
            matching: find.byType(Scrollable),
          ),
        );
        expect(body.position.maxScrollExtent, greaterThan(0));

        // Four of the five rows are built. The fifth — the locked
        expect(find.byType(OmdsSettingsSwitchRow), findsNWidgets(4));
        expect(find.text('Security codes'), findsNothing);
        expect(
          find.bySemanticsIdentifier('notif_prefs_transactional_lock_icon'),
          findsNothing,
        );

        // ...and it IS there once you scroll to it, which is what makes this a
        await tester.scrollUntilVisible(
          find.text('Security codes'),
          200,
          scrollable: find.descendant(
            of: find.byType(NotificationPreferencesScreen),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.bySemanticsIdentifier('notif_prefs_transactional_lock_icon'),
          findsOneWidget,
        );
      },
    );

    testWidgets('each preview simulates its own window, not the 800 × 600 host',
        (WidgetTester tester) async {
      // If the fixture ever stopped pinning the MediaQuery/SizedBox, both
      Future<Size> frame(Widget Function() preview) async {
        await pumpFresh(tester, preview);
        return tester.getRect(find.byType(NotificationPreferencesScreen)).size;
      }

      expect(await frame(notificationPreferencesScreenLoaded), _phoneFrame);
      expect(
        await frame(notificationPreferencesScreenCompactLargeText),
        _compactFrame,
      );
    });

    testWidgets('only the compact window is text-scaled', (
      WidgetTester tester,
    ) async {
      // `NotificationPreferencesScreenWindow.textScale` is nullable on purpose:
      Future<double> scale(Widget Function() preview) async {
        await pumpFresh(tester, preview);
        return MediaQuery.textScalerOf(
          tester.element(find.byType(NotificationPreferencesScreen)),
        ).scale(10);
      }

      expect(await scale(notificationPreferencesScreenLoaded), 10);
      expect(await scale(notificationPreferencesScreenCompactLargeText), 20);
    });
  });
}
