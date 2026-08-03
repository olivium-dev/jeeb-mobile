import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/previews/jeeb_preview.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/notification_prefs_screen_fixtures.dart';
import 'package:jeeb_mobile/features/notification_prefs/domain/notification_prefs_repository.dart';
import 'package:jeeb_mobile/features/notification_prefs/presentation/notification_prefs_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/load_test_fonts.dart';
import '../../support/sync_app_localizations.dart';
import '../preview_test_harness.dart';

const Size _phoneFrame = Size(390, 844);
const Size _compactFrame = Size(320, 568);

const Duration _pastDebounce = Duration(milliseconds: 600);

const String _loadError = "Couldn't load your notification preferences.";
const String _saveError = "Couldn't save your preference. It has been reverted.";
const String _retryCta = 'Retry';
const String _securitySection = 'Security';
const String _lockedRowTitle = 'Security codes';

const String _disableOffersDialogTitle = 'Stop offer notifications?';

const List<String> _categorySubtitles = <String>[
  'Discounts and seasonal promotions',
  'Pickup, hand-off, and delivery alerts',
  'Top-ups, refunds, and balance updates',
  'Reminders to rate completed deliveries',
];

Widget _notificationPrefsScreenCanvas(
  Widget Function() preview,
  Locale locale,
) {
  return MaterialApp(
    theme: withGoldenTestFonts(AppTheme.light()),
    darkTheme: withGoldenTestFonts(AppTheme.dark()),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<Object?>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: jeebPreviewHost(preview()),
  );
}

Future<void> _pumpFresh(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(_notificationPrefsScreenCanvas(preview, locale));
  await tester.pumpAndSettle();
}

/// The switch values, top to bottom: offers, order status, wallet, marketing,
/// and — when the Security section is rendered — the locked transactional row.
List<bool> _switchValues(WidgetTester tester) => tester
    .widgetList<OmdsSettingsSwitchRow>(find.byType(OmdsSettingsSwitchRow))
    .map((OmdsSettingsSwitchRow r) => r.value)
    .toList();

Finder _bodyScrollable() => find.descendant(
      of: find.byType(NotificationPrefsScreen),
      matching: find.byType(Scrollable),
    );

void main() {
  setUpAll(() async {
    await loadInterTestFont();
    loadPreviewArbs();
  });

  // Every preview whose surface settles. `Loading` is excluded and gets its own
  testPreviewsRender(
    'NotificationPrefsScreen',
    const <String, Widget Function()>{
      'Loaded · catalog defaults': notificationPrefsScreenLoaded,
      'Loaded · everything off': notificationPrefsScreenAllOff,
      'Error · fetch failed': notificationPrefsScreenError,
      'Loaded · the save will fail': notificationPrefsScreenSaveFails,
      'Loaded · transactional unlocked':
          notificationPrefsScreenTransactionalUnlocked,
      'Loaded · compact · 200% text':
          notificationPrefsScreenCompactLargeText,
    },
    // Each state names its own fixture. The screen shows the same rows, the
    expectedText: const <String, String>{
      'Loaded · catalog defaults':
          'NotifPrefs · Loaded · catalog defaults · phone 390 × 844',
      'Loaded · everything off': 'NotifPrefs · Everything off · phone 390 × 844',
      'Error · fetch failed': 'NotifPrefs · Error · fetch failed · phone 390 × 844',
      'Loaded · the save will fail':
          'NotifPrefs · Save will fail · phone 390 × 844',
      'Loaded · transactional unlocked':
          'NotifPrefs · Transactional unlocked · phone 390 × 844',
      'Loaded · compact · 200% text':
          'NotifPrefs · Longest content · compact 320 × 568 · 200% text',
    },
  );

  group('NotificationPrefsScreen previews · Loading', () {
    // A `CircularProgressIndicator` animates forever, so this state gets the
    Future<void> pumpSpinning(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(
        previewCanvas(notificationPrefsScreenLoading, locale),
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

      expect(
        find.text('NotifPrefs · Loading · phone 390 × 844'),
        findsOneWidget,
      );
      // The centered spinner is up...
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // ...and neither settled surface is. That combination is true of no other
      expect(find.byType(OmdsSettingsSwitchRow), findsNothing);
      expect(find.text(_retryCta), findsNothing);
    });
  });

  group('NotificationPrefsScreen preview specifics', () {
    testWidgets('the loaded fixtures really do differ in their switches', (
      WidgetTester tester,
    ) async {
      // The whole reason the expected strings above are captions: THIS is the
      await _pumpFresh(tester, notificationPrefsScreenLoaded);
      expect(
        _switchValues(tester),
        // The catalog snapshot: offers + order status on, wallet and marketing
        <bool>[true, true, false, false, true],
      );

      await _pumpFresh(tester, notificationPrefsScreenAllOff);
      expect(
        _switchValues(tester),
        // Everything the user is allowed to turn off, off — and the locked row
        <bool>[false, false, false, false, true],
      );
    });

    testWidgets('every category row carries its own dedicated subtitle (F9)', (
      WidgetTester tester,
    ) async {
      // The defect F9 fixed was copy REUSE: the wallet row showed the page
      await _pumpFresh(tester, notificationPrefsScreenLoaded);

      for (final String subtitle in _categorySubtitles) {
        expect(find.text(subtitle), findsOneWidget, reason: subtitle);
      }
    });

    testWidgets('the locked transactional row is on AND not toggleable', (
      WidgetTester tester,
    ) async {
      await _pumpFresh(tester, notificationPrefsScreenAllOff);

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
        await _pumpFresh(
          tester,
          notificationPrefsScreenTransactionalUnlocked,
        );

        expect(find.text(_securitySection), findsNothing);
        expect(find.text(_lockedRowTitle), findsNothing);
        expect(
          find.bySemanticsIdentifier('notif_prefs_transactional_lock_icon'),
          findsNothing,
        );
        // The four toggleable categories are untouched.
        expect(_switchValues(tester), <bool>[true, true, true, false]);
      },
    );

    testWidgets('turning offers OFF shows no confirmation, only the flip', (
      WidgetTester tester,
    ) async {
      // The ARB ships `notificationPreferencesDisableOffersTitle` / `…Body` /
      await _pumpFresh(tester, notificationPrefsScreenLoaded);
      expect(_switchValues(tester)[0], isTrue);

      await tester.tap(find.bySemanticsIdentifier('notif_prefs_offers_toggle'));
      await tester.pump();

      expect(_switchValues(tester)[0], isFalse, reason: 'off in one tap');
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(_disableOffersDialogTitle), findsNothing);
      expect(find.text('Turn off'), findsNothing);

      // Let the debounced PATCH fire so no timer outlives the test.
      await tester.pump(_pastDebounce);
      await tester.pump();
    });

    testWidgets('a failed fetch loses its own classification', (
      WidgetTester tester,
    ) async {
      // `NotificationPrefsCubit` maps the repository failure onto a
      Future<void> pumpFailure(NotificationPrefsFailure failure) => _pumpFresh(
            tester,
            () => NotificationPreferencesScreenPreviewHost(
              caption: 'Error · $failure',
              window: NotificationPreferencesScreenWindows.phone,
              screen: notificationPrefsScreenSeeded(
                repository: NotificationPreferencesScreenFakeRepository(
                  fetchFailure: failure,
                ),
                child: const NotificationPrefsScreen(),
              ),
            ),
          );

      await pumpFailure(NotificationPrefsFailure.network);
      expect(find.text(_loadError), findsOneWidget);
      expect(find.text(_retryCta), findsOneWidget);

      await pumpFailure(NotificationPrefsFailure.unknown);
      expect(find.text(_loadError), findsOneWidget);
      expect(find.text(_retryCta), findsOneWidget);
    });

    testWidgets('the error surface cannot scroll and has no side padding', (
      WidgetTester tester,
    ) async {
      // `_ErrorView` is a bare `Center` > `Column`: no `Padding`, no scroll
      await _pumpFresh(tester, notificationPrefsScreenError);

      expect(
        _bodyScrollable(),
        findsNothing,
        reason: 'the loaded body scrolls; the failure body has no way to',
      );

      // At 100% on a phone the failure line is one 298 pt line inside 390 pt,
      final Rect phone = tester.getRect(find.byType(NotificationPrefsScreen));
      expect(
        tester.getRect(find.text(_loadError)).width,
        lessThan(phone.width),
      );

      // At the ceiling it is not invisible. Same view, 320 pt wide at 200%:
      await _pumpFresh(
        tester,
        () => NotificationPreferencesScreenPreviewHost(
          caption: 'Error · compact · 200%',
          window: NotificationPreferencesScreenWindows.compactLargeText,
          screen: notificationPrefsScreenSeeded(
            repository: const NotificationPreferencesScreenFakeRepository(
              fetchFailure: NotificationPrefsFailure.network,
            ),
            child: const NotificationPrefsScreen(),
          ),
        ),
      );

      final Rect compact = tester.getRect(find.byType(NotificationPrefsScreen));
      final Rect message = tester.getRect(find.text(_loadError));
      expect(message.left, closeTo(compact.left, 0.5));
      expect(message.right, closeTo(compact.right, 0.5));

      // What does NOT break: the un-scrollable column still fits, so the Retry
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.text(_retryCta)).bottom,
        lessThan(compact.bottom),
      );
    });

    testWidgets('a failing save flips the row, then flips it back silently', (
      WidgetTester tester,
    ) async {
      await _pumpFresh(tester, notificationPrefsScreenSaveFails);

      // Marketing is off in the catalog snapshot.
      expect(_switchValues(tester)[3], isFalse);

      await tester.tap(
        find.bySemanticsIdentifier('notif_prefs_marketing_toggle'),
      );
      await tester.pump();

      // Optimistic: it is on immediately, and NOTHING marks the write as
      expect(_switchValues(tester)[3], isTrue);
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

      expect(_switchValues(tester)[3], isFalse, reason: 'reverted');
      expect(find.text(_saveError), findsOneWidget);

      // The snackbar is the ONLY feedback this screen ever gives about a save.
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('back pops to /settings, never to customer-profile', (
      WidgetTester tester,
    ) async {
      // The production stack. `settings-notifications` is declared as a CHILD
      await _pumpFresh(tester, notificationPrefsScreenLoaded);

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
      await _pumpFresh(
        tester,
        () => NotificationPreferencesScreenPreviewHost(
          poppable: false,
          caption: 'Loaded · flat stack (no route produces this)',
          window: NotificationPreferencesScreenWindows.phone,
          screen: notificationPrefsScreenSeeded(
            repository: const NotificationPreferencesScreenFakeRepository(
              prefs: notificationPrefsScreenCatalogPrefs,
            ),
            child: const NotificationPrefsScreen(),
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
        // Measured with the REAL faces, which is the only way this claim means
        await _pumpFresh(tester, notificationPrefsScreenCompactLargeText);

        // Nothing overflows — `OmdsSettingsSwitchRow` wraps its title column
        expect(tester.takeException(), isNull);
        final ScrollableState body =
            tester.state<ScrollableState>(_bodyScrollable());
        expect(
          body.position.maxScrollExtent,
          greaterThan(body.position.viewportDimension),
          reason: 'the body is more than a screenful even at real metrics',
        );

        // Four of the five rows are built. The fifth — the locked transactional
        expect(find.byType(OmdsSettingsSwitchRow), findsNWidgets(4));
        expect(find.text(_lockedRowTitle), findsNothing);
        expect(
          find.bySemanticsIdentifier('notif_prefs_transactional_lock_icon'),
          findsNothing,
        );

        // ...and it IS there once you scroll to it, which is what makes this a
        await tester.scrollUntilVisible(
          find.text(_lockedRowTitle),
          200,
          scrollable: _bodyScrollable(),
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
        await _pumpFresh(tester, preview);
        return tester.getRect(find.byType(NotificationPrefsScreen)).size;
      }

      expect(await frame(notificationPrefsScreenLoaded), _phoneFrame);
      expect(
        await frame(notificationPrefsScreenCompactLargeText),
        _compactFrame,
      );
    });

    testWidgets('only the compact window is text-scaled', (
      WidgetTester tester,
    ) async {
      // `NotificationPreferencesScreenWindow.textScale` is nullable on purpose:
      Future<double> scale(Widget Function() preview) async {
        await _pumpFresh(tester, preview);
        return MediaQuery.textScalerOf(
          tester.element(find.byType(NotificationPrefsScreen)),
        ).scale(10);
      }

      expect(await scale(notificationPrefsScreenLoaded), 10);
      expect(await scale(notificationPrefsScreenCompactLargeText), 20);
    });
  });
}
