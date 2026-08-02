// Render tests for the SettlementScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand.
//
// Every state pins a DISTINCT string, which matters more for a screen than for
// a widget: all nine previews are the same screen behind the same app bar,
// differing only in the fake they are constructed with. A suite that asserted
// "the app bar rendered" would pass with every preview wired to the same fake.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/settlement/presentation/settlement_screen.dart';

import '../preview_test_harness.dart';

/// The longest week label the fixtures carry — row 0 of the longest-content
/// page, and the string that tells that preview apart from every other.
const String _longWeekLabel =
    'Dec 29, 2025 – Jan 4, 2026 (year-boundary adjustment, includes the '
    'Dec 24 surge correction)';

void main() {
  setUpAll(loadPreviewArbs);

  setUp(() {
    // The previews record their route callbacks into these; they are the one
    // piece of state shared between tests in this file.
    settlementScreenTappedStatementIds.clear();
    settlementScreenOpenedPdfPaths.clear();
  });

  // Every preview whose surface actually settles. The three that hold a
  // `CircularProgressIndicator` — the two loading states and the exporting
  // state — get their own groups below, because an infinitely repeating
  // animation means `pumpAndSettle` never returns; so does the export failure,
  // whose snackbar would be gone by the time the surface settled.
  testPreviewsRender(
    'SettlementScreen',
    const <String, Widget Function()>{
      'Ready · paid + pending': settlementScreenReady,
      'Empty · no statements yet': settlementScreenEmpty,
      'Error · offline': settlementScreenOffline,
      'Unavailable · no seam': settlementScreenUnavailable,
      'Ready · longest content': settlementScreenLongestContent,
    },
    expectedText: const <String, String>{
      // The first fixture week. `Settlement Statements` (the app bar title)
      // would not do — every state including `Unavailable` shares it.
      'Ready · paid + pending': 'Jun 22 – Jun 28',
      'Empty · no statements yet': 'No settlement statements yet.',
      // Hardcoded ENGLISH, straight out of `SettlementCubit._mapError` — not
      // `l10n.settlementLoadError`, which this screen can never reach.
      'Error · offline': 'No internet connection',
      'Unavailable · no seam': 'Statements unavailable.',
      'Ready · longest content': _longWeekLabel,
    },
  );

  /// `OmdsLoadingState` wraps a `CircularProgressIndicator`, whose controller
  /// `repeat()`s forever, so `pumpAndSettle` — which `pumpPreview` calls —
  /// times out on any preview that shows one. These get the same three
  /// assertions the shared suite makes (builds in EN, builds in AR, renders
  /// its OWN state) driven by fixed pumps instead.
  ///
  /// Four pumps, not one: the export previews mount, schedule their drive in a
  /// post-frame callback, load, and only then export.
  Future<void> pumpSpinning(
    WidgetTester tester,
    Widget Function() preview, {
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(previewCanvas(preview, locale));
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  group('SettlementScreen previews · Loading · first read', () {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Loading · first read · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpSpinning(tester, settlementScreenLoading, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Loading · first read renders its own state', (
      WidgetTester tester,
    ) async {
      await pumpSpinning(tester, settlementScreenLoading);

      // The centered spinner is up...
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // ...and none of the settled surfaces is.
      expect(find.byType(Card), findsNothing);
      expect(find.text('No settlement statements yet.'), findsNothing);
      expect(find.text('No internet connection'), findsNothing);
    });
  });

  group('SettlementScreen previews · Error · unmapped failure', () {
    // `SettlementCubit.loadStatements` is `try { … } on SettlementException`,
    // so anything else out of the data layer escapes it. The future it
    // discards then completes with an error nobody awaits, which in a widget
    // test means an UNCAUGHT ASYNC ERROR — `tester.takeException()` never sees
    // it and the test would simply fail. `runZonedGuarded` catches it the way
    // the app's zone does, which is the only way to assert on this state at
    // all. That the assertion needs this machinery IS the finding.
    Future<Object?> pumpCatchingZoneError(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      Object? escaped;
      await runZonedGuarded(
        () async {
          await tester.pumpWidget(
            previewCanvas(settlementScreenUnmappedFailure, locale),
          );
          for (int i = 0; i < 4; i++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
        },
        (Object error, StackTrace stack) => escaped = error,
      );
      return escaped;
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Error · unmapped failure · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpCatchingZoneError(tester, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      'KNOWN: an unmapped failure escapes the cubit and strands the screen on '
      'its spinner',
      (WidgetTester tester) async {
        final Object? escaped = await pumpCatchingZoneError(tester);

        // The failure was never converted into a state...
        expect(
          escaped.toString(),
          contains('not a SettlementException'),
          reason: 'the throw should have escaped loadStatements() entirely',
        );
        // ...so the surface is the LOADING surface, forever: a spinner, no
        // message, and no retry. It is byte-identical to
        // `settlementScreenLoading`, which is why the two previews sit next to
        // each other in the canvas.
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(Card), findsNothing);
        expect(find.text('Unable to load statements.'), findsNothing);
        expect(find.widgetWithText(FilledButton, 'Retry'), findsNothing);
      },
    );
  });

  group('SettlementScreen previews · Exporting · PDF on the wire', () {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Exporting · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpSpinning(tester, settlementScreenExporting, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      'Exporting renders its own state: BOTH rows lose their download button '
      'for one row\'s export',
      (WidgetTester tester) async {
        await pumpSpinning(tester, settlementScreenExporting);

        // The list landed — this is not the loading state.
        expect(find.byType(Card), findsNWidgets(2));
        // `SettlementState.isExporting` is not keyed to a statement, so the
        // single download tapped on stmt-1 took stmt-2's button with it. And
        // `downloadPdf` early-returns while `isExporting`, so stmt-2 is not
        // merely busy — it is unreachable until this export finishes.
        expect(find.byIcon(Icons.download), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
      },
    );

    testWidgets(
      'KNOWN: the per-row export spinner lays out at ZERO width, so the '
      'trailing column is blank rather than busy',
      (WidgetTester tester) async {
        // `_StatementRow` renders `SizedBox(width: 20, height: 20, child:
        // OmdsLoadingState())`, but `OmdsLoadingState` is a 48 pt indicator
        // inside `EdgeInsets.all(Spacing.large)` — 88 pt of intrinsic width
        // forced into 20, which resolves the indicator itself to 0.
        //
        // This asserts the CURRENT behaviour. When the row is fixed it fails;
        // that is the signal to delete this test, not to widen it.
        await pumpSpinning(tester, settlementScreenExporting);

        final Size size =
            tester.getSize(find.byType(CircularProgressIndicator).first);

        expect(size.width, 0.0);
        // ...and it is not even the 20 pt the box budgeted vertically.
        expect(size.height, 48.0);
      },
    );
  });

  group('SettlementScreen previews · Export failed · transient snackbar', () {
    /// The snackbar animates in over ~250 ms and dismisses itself after four
    /// seconds, so this stops in between: long enough to see it, short enough
    /// that its timer has not fired.
    Future<void> pumpToSnackbar(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(previewCanvas(settlementScreenExportFailed, locale));
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(milliseconds: 400));
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Export failed · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpToSnackbar(tester, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      'Export failed renders its own state: a snackbar over a list that has '
      'already forgotten the failure',
      (WidgetTester tester) async {
        await pumpToSnackbar(tester);

        // The one string no other preview shows — and another of `_mapError`'s
        // hardcoded English messages, on a surface that is otherwise
        // localized.
        expect(find.text('Unable to save PDF file'), findsOneWidget);
        expect(find.byType(SnackBar), findsOneWidget);
        // The list is still there underneath, unchanged...
        expect(find.text('Jun 22 – Jun 28'), findsOneWidget);
        // ...and `_onStateChange` has ALREADY called `acknowledgeExport()`, so
        // the rows are back to their download buttons. Once the snackbar times
        // out, nothing on this screen records that an export failed and there
        // is no retry affordance anywhere.
        expect(find.byIcon(Icons.download), findsNWidgets(2));
      },
    );
  });

  group('SettlementScreen preview specifics', () {
    // Each state gets its OWN test. Every preview here is the same widget tree
    // differing only in the fake handed to it, so pumping a second preview
    // into the same tester would reuse the first preview's element and with it
    // the first preview's cubit.

    testWidgets('the ready preview shows the T-MOB-032 signature ids', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, settlementScreenReady);

      expect(find.bySemanticsIdentifier('settlement_root'), findsOneWidget);
      for (final String id in const <String>['stmt-1', 'stmt-2']) {
        expect(
          find.bySemanticsIdentifier('settlement_statement_row_$id'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('settlement_download_$id'),
          findsOneWidget,
        );
      }
    });

    testWidgets('a row tap forwards THAT row\'s statement to the route', (
      WidgetTester tester,
    ) async {
      // Proves the preview is honest to tap in, and that the id the route
      // would push (`/jeeber/settlement/:id`) is the row's own.
      await pumpPreview(tester, settlementScreenReady);

      await tester.tap(find.text('Jun 29 – Jul 5'));
      await tester.pumpAndSettle();

      expect(settlementScreenTappedStatementIds, <String>['stmt-2']);
    });

    testWidgets('a download tap forwards the file path to the route', (
      WidgetTester tester,
    ) async {
      // The successful-export path, which has no designed surface of its own:
      // the listener forwards the path and immediately acknowledges, so the
      // only observable effect is this callback.
      await pumpPreview(tester, settlementScreenReady);

      await tester.tap(
        find.bySemanticsIdentifier('settlement_download_stmt-1'),
      );
      await tester.pumpAndSettle();

      expect(
        settlementScreenOpenedPdfPaths,
        <String>['/tmp/statement-stmt-1.pdf'],
      );
      // And the surface is back to normal — nothing marks the row as exported.
      expect(find.byIcon(Icons.download), findsNWidgets(2));
    });

    testWidgets('KNOWN: every row announces its amount and status TWICE', (
      WidgetTester tester,
    ) async {
      // `_StatementRow` wraps the `Card` in
      // `Semantics(label: l10n.settlementRowSemantics(amount, status))` and
      // then wraps the `InkWell` inside it in
      // `Semantics(container: true, button: true)`. The inner container starts
      // a node of its own and merges the row's three Texts into it, so the
      // outer summary does not replace the row's content — it duplicates it on
      // a separate, non-interactive node.
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, settlementScreenReady);

      final SemanticsNode row = tester.getSemantics(
        find.bySemanticsIdentifier('settlement_statement_row_stmt-1'),
      );
      expect(row.label, 'Jun 22 – Jun 28\nUSD 184.50\nPaid');
      // The summary label the developer wrote is on a DIFFERENT node, which is
      // why the amount and the status are read out a second time.
      expect(find.bySemanticsLabel('USD 184.50 — Paid'), findsOneWidget);

      // Disposed here rather than in a tearDown: the handle check runs BEFORE
      // registered teardowns.
      handle.dispose();
    });

    testWidgets(
      'KNOWN: settlement_download_<id> is a labelless button with no tap '
      'action in front of the real one',
      (WidgetTester tester) async {
        // The identifier an automation harness would target resolves to the
        // OUTER `Semantics(button: true, container: true)` wrapper, which
        // carries no name and no `SemanticsAction.tap`. The node that actually
        // does anything is its unnamed child, whose only name is the
        // `Download PDF` tooltip.
        final SemanticsHandle handle = tester.ensureSemantics();
        await pumpPreview(tester, settlementScreenReady);

        final SemanticsNode outer = tester.getSemantics(
          find.bySemanticsIdentifier('settlement_download_stmt-1'),
        );
        final SemanticsData data = outer.getSemanticsData();

        expect(data.flagsCollection.isButton, isTrue);
        expect(data.label, isEmpty);
        expect(data.tooltip, isEmpty);
        expect(data.hasAction(SemanticsAction.tap), isFalse);

        // The real one, one level down.
        final List<SemanticsNode> children = <SemanticsNode>[];
        outer.visitChildren((SemanticsNode child) {
          children.add(child);
          return true;
        });
        expect(children, hasLength(1));
        final SemanticsData inner = children.single.getSemanticsData();
        expect(inner.hasAction(SemanticsAction.tap), isTrue);
        expect(inner.label, isEmpty);
        expect(inner.tooltip, 'Download PDF');

        handle.dispose();
      },
    );

    testWidgets('KNOWN: the unavailable fallback has no way back', (
      WidgetTester tester,
    ) async {
      // `_Unavailable` builds `OMDSAppBar(title: …)` without
      // `showBackButton`, and `automaticallyImplyLeading` finds nothing to
      // pop. The route is an orphan (zero inbound navigation), so a deep link
      // is how it is reached — and this is where it ends.
      await pumpPreview(tester, settlementScreenUnavailable);

      expect(find.text('Statements unavailable.'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('the loaded surface, by contrast, does have a back arrow', (
      WidgetTester tester,
    ) async {
      // The control for the assertion above: same screen, same host, one arrow
      // — so that test is about `_Unavailable` and not about the preview host.
      await pumpPreview(tester, settlementScreenEmpty);

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets(
      'KNOWN: a statement the gateway did not label renders a blank title line',
      (WidgetTester tester) async {
        // `SettlementStatement.fromJson` defaults `weekLabel` to `''` when
        // neither `weekLabel` nor `periodLabel` is present, and `_StatementRow`
        // prints it unguarded. Two such rows are in the longest-content page,
        // and the only thing telling them apart is their amount.
        await pumpPreview(tester, settlementScreenLongestContent);

        expect(find.text(''), findsNWidgets(2));
        expect(find.text('USD 0.00'), findsOneWidget);
        expect(find.text('USD 42.75'), findsOneWidget);
      },
    );
  });

  group('SettlementScreen previews · at the declared canvas box', () {
    /// A real device rather than the 800x600 test default: [Size] in logical
    /// pixels at dpr 1, so `physicalSize` is the box the preview declares.
    Future<void> pumpAtBox(
      WidgetTester tester,
      Widget Function() preview, {
      Locale locale = const Locale('en'),
      double textScale = 1.0,
      Size size = const Size(390, 844),
    }) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(previewCanvas(preview, locale));
      await tester.pumpAndSettle();
    }

    const Map<String, Widget Function()> settled = <String, Widget Function()>{
      'Ready · paid + pending': settlementScreenReady,
      'Empty · no statements yet': settlementScreenEmpty,
      'Error · offline': settlementScreenOffline,
      'Unavailable · no seam': settlementScreenUnavailable,
    };

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      for (final MapEntry<String, Widget Function()> entry in settled.entries) {
        testWidgets('${entry.key} · ${locale.languageCode} · 390x844', (
          WidgetTester tester,
        ) async {
          await pumpAtBox(tester, entry.value, locale: locale);

          expect(tester.takeException(), isNull);
        });
      }
    }

    // The error body is the one surface here with no scroll fallback — an
    // `OmdsErrorState` column holding a 64 pt icon, a wrapped message and the
    // retry CTA, and `_buildBody` does not centre or scroll it. It clears 200%
    // text on a 320x568 compact device today, which is worth pinning: the next
    // string that grows is the one that clips.
    for (final double scale in const <double>[1.5, 2.0]) {
      for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
        testWidgets(
          'Error · offline fits a 320x568 device at '
          '${(scale * 100).round()}% text · ${locale.languageCode}',
          (WidgetTester tester) async {
            await pumpAtBox(
              tester,
              settlementScreenOffline,
              locale: locale,
              textScale: scale,
              size: const Size(320, 568),
            );

            expect(tester.takeException(), isNull);
            expect(find.text('No internet connection'), findsOneWidget);
            expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
          },
        );
      }
    }

    // The longest-content preview declares the compact box, so this is the
    // rendering the canvas matrix actually draws. The obvious suspicion — that
    // a five-figure payout beside a two-line period label pushes the status
    // chip off the trailing edge — is NOT what happens: the label column is an
    // `Expanded` and the label wraps. Pinned so a future change to the row's
    // flex is noticed.
    for (final double scale in const <double>[1.0, 2.0]) {
      for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
        testWidgets(
          'Ready · longest content is clean on 320x568 at '
          '${(scale * 100).round()}% text · ${locale.languageCode}',
          (WidgetTester tester) async {
            await pumpAtBox(
              tester,
              settlementScreenLongestContent,
              locale: locale,
              textScale: scale,
              size: const Size(320, 568),
            );

            expect(tester.takeException(), isNull);
            expect(find.text(_longWeekLabel), findsOneWidget);
          },
        );
      }
    }
  });
}
