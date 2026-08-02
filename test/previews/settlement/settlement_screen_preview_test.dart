// Render tests for the SettlementScreen previews.

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
    settlementScreenTappedStatementIds.clear();
    settlementScreenOpenedPdfPaths.clear();
  });

  // Every preview whose surface actually settles. The three that hold a
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
      'Ready · paid + pending': 'Jun 22 – Jun 28',
      'Empty · no statements yet': 'No settlement statements yet.',
      // Hardcoded ENGLISH, straight out of `SettlementCubit._mapError` — not
      'Error · offline': 'No internet connection',
      'Unavailable · no seam': 'Statements unavailable.',
      'Ready · longest content': _longWeekLabel,
    },
  );

  /// `OmdsLoadingState` wraps a `CircularProgressIndicator`, whose controller
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
        expect(find.byIcon(Icons.download), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
      },
    );

    testWidgets(
      'KNOWN: the per-row export spinner lays out at ZERO width, so the '
      'trailing column is blank rather than busy',
      (WidgetTester tester) async {
        // `_StatementRow` renders `SizedBox(width: 20, height: 20, child:
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
        expect(find.text('Unable to save PDF file'), findsOneWidget);
        expect(find.byType(SnackBar), findsOneWidget);
        // The list is still there underneath, unchanged...
        expect(find.text('Jun 22 – Jun 28'), findsOneWidget);
        // ...and `_onStateChange` has ALREADY called `acknowledgeExport()`, so
        expect(find.byIcon(Icons.download), findsNWidgets(2));
      },
    );
  });

  group('SettlementScreen preview specifics', () {
    // Each state gets its OWN test. Every preview here is the same widget tree

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
      await pumpPreview(tester, settlementScreenReady);

      await tester.tap(find.text('Jun 29 – Jul 5'));
      await tester.pumpAndSettle();

      expect(settlementScreenTappedStatementIds, <String>['stmt-2']);
    });

    testWidgets('a download tap forwards the file path to the route', (
      WidgetTester tester,
    ) async {
      // The successful-export path, which has no designed surface of its own:
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
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, settlementScreenReady);

      final SemanticsNode row = tester.getSemantics(
        find.bySemanticsIdentifier('settlement_statement_row_stmt-1'),
      );
      expect(row.label, 'Jun 22 – Jun 28\nUSD 184.50\nPaid');
      // The summary label the developer wrote is on a DIFFERENT node, which is
      expect(find.bySemanticsLabel('USD 184.50 — Paid'), findsOneWidget);

      // Disposed here rather than in a tearDown: the handle check runs BEFORE
      handle.dispose();
    });

    testWidgets(
      'KNOWN: settlement_download_<id> is a labelless button with no tap '
      'action in front of the real one',
      (WidgetTester tester) async {
        // The identifier an automation harness would target resolves to the
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
      await pumpPreview(tester, settlementScreenUnavailable);

      expect(find.text('Statements unavailable.'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('the loaded surface, by contrast, does have a back arrow', (
      WidgetTester tester,
    ) async {
      // The control for the assertion above: same screen, same host, one arrow
      await pumpPreview(tester, settlementScreenEmpty);

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets(
      'KNOWN: a statement the gateway did not label renders a blank title line',
      (WidgetTester tester) async {
        // `SettlementStatement.fromJson` defaults `weekLabel` to `''` when
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
