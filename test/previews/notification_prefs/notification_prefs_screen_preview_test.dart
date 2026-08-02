// Render tests for the NotificationPrefsScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand.
//
// This screen makes "did it render" an unusually weak question: every loaded
// state paints the SAME fifteen ARB strings — two section headers, four
// category rows with their subtitles, the push-only note and the locked
// transactional row are all static — and a fixture changes only the value of
// four `Switch`es. A suite that asserted "the app bar rendered" would pass with
// all six previews wired to the same fake. So the expected strings pin WHICH
// fixture each preview is built from (the caption the fixture host paints), and
// the specifics group asserts the things that actually differ: the switch
// values, the presence of the locked Security section, the failure surface, and
// where the back arrow goes.
//
// ## Fonts
//
// `preview_test_harness.dart` deliberately does NOT load the real faces, so
// every glyph is a 1-em square there — Latin measures ~2x and Arabic ~2.4x what
// it does on a device. That is fine for "did this build and show its own
// state", which is all the shared suite claims. It is NOT fine for any claim
// about fitting, so every measurement in this file goes through
// [_notificationPrefsScreenCanvas], the same canvas with `withGoldenTestFonts`
// applied: real Inter for Latin, a deterministic Noto subset for Arabic.

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

/// Mirror the frames the fixture declares, so a preview quietly rewired to a
/// different window fails here instead of looking plausible in the canvas.
const Size _phoneFrame = Size(390, 844);
const Size _compactFrame = Size(320, 568);

/// The debounce the cubit is built with (`NotificationPrefsCubit` default) plus
/// slack. The fixtures keep the production value on purpose — a preview that
/// shortened it would render a round trip nobody can see.
const Duration _pastDebounce = Duration(milliseconds: 600);

/// Exact ARB copy, so a reworded string breaks the test instead of silently
/// unpinning the assertion.
const String _loadError = "Couldn't load your notification preferences.";
const String _saveError = "Couldn't save your preference. It has been reverted.";
const String _retryCta = 'Retry';
const String _securitySection = 'Security';
const String _lockedRowTitle = 'Security codes';

/// The disable-offers confirmation dialog that ships in the ARB (EN + AR, with
/// generated getters) and is rendered by no code anywhere under `lib/`.
const String _disableOffersDialogTitle = 'Stop offer notifications?';

/// The four category subtitles. F9 fixed a defect where the wallet row reused
/// the page-header copy and the rating-reminders row reused the offers copy, so
/// this list existing as four DISTINCT strings is the regression itself.
const List<String> _categorySubtitles = <String>[
  'Discounts and seasonal promotions',
  'Pickup, hand-off, and delivery alerts',
  'Top-ups, refunds, and balance updates',
  'Reminders to rate completed deliveries',
];

/// [previewCanvas] with the real font faces installed on the theme.
///
/// The shared canvas builds `AppTheme.light()` unmodified and the theme carries
/// no `fontFamilyFallback`, so Arabic falls back to the 1-em test face there.
/// `withGoldenTestFonts` is what adds the deterministic Noto family, and only
/// through it is a measurement on this screen worth anything.
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

/// Pumps [preview] onto an EMPTY tree, with the real faces.
///
/// Unmounting first is load-bearing. Pumping a second preview onto the first
/// one's elements reconciles them — same widget types, same positions — and the
/// cubit is built inside `BlocProvider.create`, which runs once per `State`.
/// The second fixture's repository would be dropped on the floor and the first
/// fixture's cubit would keep driving the screen, so a state comparison would
/// compare one state with itself.
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
  // group below: `OmdsLoadingState` is a `CircularProgressIndicator`, whose
  // controller repeats forever, so `pumpAndSettle` — which `pumpPreview` calls
  // — never returns on it.
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
    // same subtitles and the same app bar in all of them, so without this a
    // preview wired to the wrong repository — or six previews accidentally
    // sharing one — would pass unnoticed.
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
    // same three assertions the shared suite makes (builds in EN, builds in AR,
    // renders its OWN state) driven by fixed pumps instead of `pumpAndSettle`.
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
      // preview in this file. Note what is NOT here: no skeleton of the rows
      // about to arrive, and no message — the whole loading state is one
      // spinner on an empty body.
      expect(find.byType(OmdsSettingsSwitchRow), findsNothing);
      expect(find.text(_retryCta), findsNothing);
    });
  });

  group('NotificationPrefsScreen preview specifics', () {
    testWidgets('the loaded fixtures really do differ in their switches', (
      WidgetTester tester,
    ) async {
      // The whole reason the expected strings above are captions: THIS is the
      // only thing that separates the loaded states, and it is invisible to a
      // text finder.
      await _pumpFresh(tester, notificationPrefsScreenLoaded);
      expect(
        _switchValues(tester),
        // The catalog snapshot: offers + order status on, wallet and marketing
        // off, transactional locked on.
        <bool>[true, true, false, false, true],
      );

      await _pumpFresh(tester, notificationPrefsScreenAllOff);
      expect(
        _switchValues(tester),
        // Everything the user is allowed to turn off, off — and the locked row
        // still on, which is the point of the state.
        <bool>[false, false, false, false, true],
      );
    });

    testWidgets('every category row carries its own dedicated subtitle (F9)', (
      WidgetTester tester,
    ) async {
      // The defect F9 fixed was copy REUSE: the wallet row showed the page
      // header's "Manage what you get notified about" and the rating-reminders
      // row showed the offers row's "Discounts and seasonal promotions". Four
      // distinct strings, each exactly once, is the regression guard.
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
        // the on-device jm-058 flow both assert. The screen still "works" in
        // this shape — it is the acceptance test that goes red.
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
      // `…Confirm`, described in the ARB as "the confirmation dialog shown when
      // the user turns the offers toggle off", translated into Arabic and
      // exposed as generated getters. No widget under `lib/` reads any of them.
      // This is the tap that was supposed to be guarded.
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
      // `NotificationPrefsFailureView` and `NotificationPrefsError` carries it
      // — then `_ErrorView` renders one string regardless. These two fixtures
      // fail for different reasons and are byte-identical on screen, so an
      // offline user gets no hint that the problem is their connection.
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
      // view. The loaded body is a `ListView` with `Spacing.medium` on both
      // edges, so the two surfaces of the same screen disagree about both.
      await _pumpFresh(tester, notificationPrefsScreenError);

      expect(
        _bodyScrollable(),
        findsNothing,
        reason: 'the loaded body scrolls; the failure body has no way to',
      );

      // At 100% on a phone the failure line is one 298 pt line inside 390 pt,
      // so the missing padding costs nothing and is invisible in review.
      final Rect phone = tester.getRect(find.byType(NotificationPrefsScreen));
      expect(
        tester.getRect(find.text(_loadError)).width,
        lessThan(phone.width),
      );

      // At the ceiling it is not invisible. Same view, 320 pt wide at 200%:
      // the copy wraps to three lines that start at the left screen border and
      // end at the right one, with no margin at all, while every row on the
      // loaded surface sits in `Spacing.medium`.
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
      // CTA — the only way out of this state — stays on screen.
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
      // pending. `NotificationPrefsLoaded.isSaving` is emitted by the cubit for
      // exactly this window and the screen never reads it — no spinner, no
      // disabled row, no app-bar progress.
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
      // Let it go so the test leaves no pending timer.
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('back pops to /settings, never to customer-profile', (
      WidgetTester tester,
    ) async {
      // The production stack. `settings-notifications` is declared as a CHILD
      // of `/settings` and go_router materializes a page for every matched
      // ancestor with a builder, so `canPop()` is true however the screen was
      // reached and the arrow always pops. `_onBack`'s `goNamed`
      // ('customer-profile') fallback — and the screen's own dartdoc — describe
      // a destination no route into this screen can reach.
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
      // is the only way to see where `_onBack`'s written contract would land.
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
        // anything: under the 1-em test face Latin is roughly twice as wide,
        // and the same layout there reports 1618 pt of scroll against the
        // 814 pt a real Inter rendering produces.
        await _pumpFresh(tester, notificationPrefsScreenCompactLargeText);

        // Nothing overflows — `OmdsSettingsSwitchRow` wraps its title column
        // inside the tile's own constraints instead of pushing the switch off
        // the trailing edge — the composition just becomes a long scroll.
        expect(tester.takeException(), isNull);
        final ScrollableState body =
            tester.state<ScrollableState>(_bodyScrollable());
        expect(
          body.position.maxScrollExtent,
          greaterThan(body.position.viewportDimension),
          reason: 'the body is more than a screenful even at real metrics',
        );

        // Four of the five rows are built. The fifth — the locked transactional
        // row — is past the `ListView`'s viewport plus cache extent, so on
        // arrival `notif_prefs_transactional_lock_icon` is absent from the
        // widget tree AND from the semantics tree. A driver or a screen reader
        // querying the id JM-058 AC2 publishes finds nothing until the user
        // scrolls. Halving the scroll extent with real fonts did not change
        // that: the locked row is LAST, so it is the first thing to fall off.
        expect(find.byType(OmdsSettingsSwitchRow), findsNWidgets(4));
        expect(find.text(_lockedRowTitle), findsNothing);
        expect(
          find.bySemanticsIdentifier('notif_prefs_transactional_lock_icon'),
          findsNothing,
        );

        // ...and it IS there once you scroll to it, which is what makes this a
        // reachability finding rather than a missing row.
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
      // windows would collapse onto the test surface and the compact state
      // would silently become the phone one.
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
      // a window that pinned 1.0 would overwrite the `matrix: true` 200% card
      // and label a 100% rendering "EN 200% text".
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
