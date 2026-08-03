// Render tests for the DiagnosticsScreen previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/diagnostics/diag.dart';
import 'package:jeeb_mobile/core/diagnostics/diagnostics_screen.dart';

import '../preview_test_harness.dart';

/// The longest-content preview's session name. Spelled out here rather than
/// imported from the fixtures so a preview quietly rewired to a short listing
const String _kLongestSessionName =
    '2026-07-31T23-59-59-999Z-jeeber-regression-run-full-journey.jsonl';

/// The simulator container that state lists from — the "On-device folder"
/// subtitle, and the one string on the surface no other state can produce.
const String _kSimulatorDiagDir =
    '/Users/qa/Library/Developer/CoreSimulator/Devices/'
    '8C3F1A6D-2B44-4E19-9F0C-77A1D5E3B240/data/Containers/Data/Application/'
    '2A1B9C77-5D3E-4F62-8A10-6E4B0C9D1F58/Library/Application Support/diag';

/// Every non-empty string currently painted, as a set — the cheapest honest
/// answer to "do these two states look the same?".
Set<String> _visibleText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((Text text) => text.data ?? '')
    .where((String data) => data.isNotEmpty)
    .toSet();

void main() {
  setUpAll(loadPreviewArbs);

  // The previews drive `Diag.enabledOverride` (the screen's build gate is a
  tearDown(Diag.resetForTest);

  // Every preview except `Loading · listing files`, whose spinner cannot settle
  testPreviewsRender(
    'DiagnosticsScreen',
    const <String, Widget Function()>{
      'Sessions · newest first': diagnosticsScreenSessions,
      'Empty · no session files': diagnosticsScreenEmpty,
      'Loader failed · degrades to empty': diagnosticsScreenLoadFailed,
      'Longest content · long name, deep path':
          diagnosticsScreenLongestContent,
      'Compact 320 pt · one session': diagnosticsScreenCompact,
      'Release-like build · diag disabled': diagnosticsScreenDisabled,
    },
    expectedText: const <String, String>{
      // Only the reference listing carries the live session's `(current)` row.
      'Sessions · newest first': '2026-07-03T10-30-15-123Z-client.jsonl '
          '(current)',
      // The placeholder row that replaces the list when nothing was found.
      'Empty · no session files': 'No session files yet',
      // NB: this string is also present in the empty state, because the two
      'Loader failed · degrades to empty': 'Appears once a session file exists',
      // NOT the session title: on this state the export section alone is
      'Longest content · long name, deep path': _kSimulatorDiagDir,
      'Compact 320 pt · one session': '2026-06-30T07-14-52-000Z-jeeber.jsonl',
      'Release-like build · diag disabled':
          'Diagnostics is only available in dev builds.',
    },
  );

  // The listing body is a `CircularProgressIndicator`, i.e. a repeating
  group('DiagnosticsScreen previews · Loading · listing files', () {
    Future<void> pumpLoading(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(previewCanvas(diagnosticsScreenLoading, locale));
      await tester.pump(const Duration(milliseconds: 16));
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Loading · listing files · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpLoading(tester, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Loading · listing files renders its own state', (
      WidgetTester tester,
    ) async {
      await pumpLoading(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // The whole body is replaced while the listing runs: no export section,
      expect(find.byKey(const Key('diagnostics-session-list')), findsNothing);
      expect(find.byKey(const Key('diag-row-dir-path')), findsNothing);
      expect(find.byKey(const Key('diag-row-empty')), findsNothing);
      // …and nothing names what is being awaited. `_load` flushes the
      expect(find.byType(Text), findsOneWidget); // the app bar title only
      expect(find.text('Diagnostics'), findsOneWidget);
    });
  });

  // The pair this section exists for. `_enabledBody` reads
  group('DiagnosticsScreen previews · empty vs failed listing', () {
    testWidgets('a THROWN listing renders the empty state, character for '
        'character', (WidgetTester tester) async {
      await pumpPreview(tester, diagnosticsScreenEmpty);
      final Set<String> empty = _visibleText(tester);

      // Tear the tree down between pumps: the two previews build the same
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpPreview(tester, diagnosticsScreenLoadFailed);
      final Set<String> failed = _visibleText(tester);

      expect(empty, isNotEmpty);
      expect(failed, empty);
    });

    testWidgets('the failed listing offers no error and no retry', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, diagnosticsScreenLoadFailed);

      expect(find.byKey(const Key('diag-row-empty')), findsOneWidget);
      expect(find.byKey(const Key('diag-session-row-0')), findsNothing);
      expect(find.textContaining('Try again'), findsNothing);
      expect(find.textContaining('EACCES'), findsNothing);
      // The one surviving affordance is the app bar action, which re-runs the
      expect(find.byKey(const Key('diag-refresh')), findsOneWidget);
    });
  });

  group('DiagnosticsScreen preview specifics', () {
    // NB: one preview per test. Pumping a second preview into the same tester
    testWidgets('the phone previews pin a 390 pt frame, not the canvas width', (
      WidgetTester tester,
    ) async {
      // The harness pumps an 800 pt surface: a preview that left its width to
      await pumpPreview(tester, diagnosticsScreenSessions);

      expect(tester.getSize(find.byType(DiagnosticsScreen)).width, 390);
    });

    testWidgets('the compact preview pins the 320 x 568 floor', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, diagnosticsScreenCompact);

      expect(
        tester.getSize(find.byType(DiagnosticsScreen)),
        const Size(320, 568),
      );
    });

    testWidgets('the reference listing marks ONLY the live session (current) '
        'and formats both sizes', (WidgetTester tester) async {
      await pumpPreview(tester, diagnosticsScreenSessions);

      expect(find.byKey(const Key('diag-session-row-0')), findsOneWidget);
      expect(find.byKey(const Key('diag-session-row-1')), findsOneWidget);
      expect(find.text('2026-07-02T08-00-00-000Z-jeeber.jsonl'), findsOneWidget);
      expect(find.textContaining('(current)'), findsOneWidget);
      expect(find.textContaining('12.4 KB'), findsOneWidget);
      expect(find.textContaining('532 B'), findsOneWidget);
    });

    testWidgets('the empty state disables both export rows rather than '
        'offering a path it does not have', (WidgetTester tester) async {
      await pumpPreview(tester, diagnosticsScreenEmpty);

      expect(
        tester
            .widget<OmdsSettingsRow>(find.byKey(const Key('diag-row-dir-path')))
            .enabled,
        isFalse,
      );
      expect(
        tester
            .widget<OmdsSettingsRow>(find.byKey(const Key('diag-row-adb')))
            .enabled,
        isFalse,
      );
      expect(find.text('No session directory yet'), findsOneWidget);
    });

    testWidgets('the longest-content state shows the simulator container path '
        'and the adb pull FALLBACK, not run-as', (WidgetTester tester) async {
      await pumpPreview(tester, diagnosticsScreenLongestContent);

      // Not an Android app-data path, so `DiagExport.adbPullCommand` cannot
      expect(find.textContaining('adb pull "'), findsOneWidget);
      expect(find.textContaining('run-as'), findsNothing);
      expect(
        find.textContaining('CoreSimulator/Devices'),
        findsNWidgets(2), // the folder row and the adb one-liner row
      );
    });

    testWidgets('the longest session title survives — once you scroll past the '
        'export section that pushed it off-screen', (WidgetTester tester) async {
      await pumpPreview(tester, diagnosticsScreenLongestContent);

      // The two export subtitles are unbroken machine strings with no
      expect(find.text('$_kLongestSessionName (current)'), findsNothing);

      await tester.scrollUntilVisible(
        find.byKey(const Key('diag-session-row-0')),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('$_kLongestSessionName (current)'), findsOneWidget);
      expect(find.textContaining('9.8 MB'), findsOneWidget);
    });

    testWidgets('the release-like build shows the notice, no list — but keeps '
        'the refresh action', (WidgetTester tester) async {
      await pumpPreview(tester, diagnosticsScreenDisabled);

      expect(find.byKey(const Key('diag-disabled-message')), findsOneWidget);
      expect(find.byKey(const Key('diagnostics-session-list')), findsNothing);
      expect(find.byKey(const Key('diag-session-row-0')), findsNothing);
      // The app bar action survives the gate: it is wired to `_refresh`, which
      expect(find.byKey(const Key('diag-refresh')), findsOneWidget);
    });
  });
}
