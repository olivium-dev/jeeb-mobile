// M3-38 per-element Midnight assertions for DiagnosticsScreen.
//
// Goldens are evidence, not gates (02-STUDY-NOTES, wave-C fixup): the shared
// comparator tolerates 5% pixel diff, so re-inking a 19px glyph or swapping an
// OMDSAppBar for the in-body bar can pass every golden unchanged. Every value
// this row moved is read back off the built widget here.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/diagnostics/diag.dart';
import 'package:jeeb_mobile/core/diagnostics/diagnostics_screen.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_outlined_card.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_section_label.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_top_bar.dart';

final ThemeData _midnight = AppTheme.midnight();

/// A listing that never lands — holds the loading frame.
Future<List<DiagSessionFileInfo>> _pending() =>
    Completer<List<DiagSessionFileInfo>>().future;

Future<List<DiagSessionFileInfo>> _failing() =>
    Future<List<DiagSessionFileInfo>>.error(StateError('EACCES'));

final List<DiagSessionFileInfo> _sessions = <DiagSessionFileInfo>[
  DiagSessionFileInfo(
    path: '/data/user/0/app.jeeb.mobile.dev/files/diag/'
        '2026-07-03T10-30-15-123Z-client.jsonl',
    name: '2026-07-03T10-30-15-123Z-client.jsonl',
    sizeBytes: 12 * 1024,
    modified: DateTime(2026, 7, 3, 12, 30),
    isCurrent: true,
  ),
];

Widget _host(Future<List<DiagSessionFileInfo>> Function() loader) => MaterialApp(
      theme: _midnight,
      // The kit's illustrations loop forever by design; reduce motion is what
      // makes `pumpAndSettle` terminate (02-STUDY-NOTES, wave-B).
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: DiagnosticsScreen(
        sessionsLoader: loader,
        shareLauncher: (_) async {},
        clipboardWriter: (_) async {},
      ),
    );

void main() {
  setUp(() {
    Diag.enabledOverride = true;
    Diag.sink = (_) {};
  });

  tearDown(Diag.resetForTest);

  Future<void> pump(
    WidgetTester tester,
    Future<List<DiagSessionFileInfo>> Function() loader,
  ) async {
    await tester.pumpWidget(_host(loader));
    await tester.pumpAndSettle();
  }

  JeebEmptyState emptyState(WidgetTester tester) =>
      tester.widget<JeebEmptyState>(find.byType(JeebEmptyState));

  group('DiagnosticsScreen — R22 chrome', () {
    testWidgets('mounts the content field, glow topEnd, decor still',
        (tester) async {
      await pump(tester, () async => _sessions);

      final field =
          tester.widget<JeebMidnightField>(find.byType(JeebMidnightField));
      // Carried from settings_screen.dart: R22's only radial is top-end.
      expect(field.variant, JeebFieldVariant.content);
      expect(field.glowPlacement, JeebFieldGlowPlacement.topEnd);
      // R22 declares zero periwinkle.
      expect(field.washPlacement, isNull);
      // R22 is board-still, and a dev tool has even less claim to motion.
      expect(field.animateDecor, isFalse);
    });

    testWidgets('draws the in-body back bar, not a Material app bar',
        (tester) async {
      await pump(tester, () async => _sessions);

      final bar = tester.widget<JeebTopBar>(find.byType(JeebTopBar));
      expect(bar.identifier, DiagnosticsScreen.backIdentifier);
      // The pre-Midnight chrome this row deleted.
      expect(find.byType(OMDSAppBar), findsNothing);
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(OmdsSettingsSection), findsNothing);
      expect(find.byType(OmdsSettingsRow), findsNothing);
    });

    testWidgets('the refresh action re-homed onto the top bar slot',
        (tester) async {
      await pump(tester, () async => _sessions);

      final bar = tester.widget<JeebTopBar>(find.byType(JeebTopBar));
      expect(bar.trailing?.identifier, DiagnosticsScreen.refreshIdentifier);
      expect(bar.trailing?.icon, Icons.refresh);
      expect(
        find.bySemanticsIdentifier(DiagnosticsScreen.refreshIdentifier),
        findsOneWidget,
      );
    });

    testWidgets('the bands are section label + grouped glass card',
        (tester) async {
      await pump(tester, () async => _sessions);

      // Export and Sessions.
      expect(find.byType(JeebSectionLabel), findsNWidgets(2));
      final cards = tester
          .widgetList<JeebOutlinedCard>(find.byType(JeebOutlinedCard))
          .toList();
      expect(cards, hasLength(2));
      for (final card in cards) {
        // `grouped` — rows own their padding, the card owns the dividers.
        expect(card.dividers, isTrue);
        expect(card.state, JeebCardState.normal);
      }
    });
  });

  group('DiagnosticsScreen — orange budget', () {
    testWidgets('leading glyphs take the surface title ink, never primary',
        (tester) async {
      await pump(tester, () async => _sessions);

      // `OmdsSettingsRow` defaults its leading glyph to `colorScheme.primary`,
      // which under Midnight IS #D73B00 — one orange glyph per row.
      for (final glyph in <IconData>[
        Icons.folder_outlined,
        Icons.terminal_outlined,
        Icons.description_outlined,
      ]) {
        final icon = tester.widget<Icon>(find.byIcon(glyph));
        expect(icon.color, _midnight.colorScheme.onSurface, reason: '$glyph');
        expect(icon.color, isNot(_midnight.colorScheme.primary));
      }
    });

    testWidgets('the row trailing actions are muted ink, never primary',
        (tester) async {
      await pump(tester, () async => _sessions);

      final muted =
          _midnight.extension<JeebSemanticColors>()!.mutedText;
      for (final key in <Key>[
        const Key('diag-share-0'),
        const Key('diag-copy-0'),
      ]) {
        final button = tester.widget<IconButton>(find.byKey(key));
        expect(button.color, muted, reason: '$key');
        expect(button.color, isNot(_midnight.colorScheme.primary));
      }
    });
  });

  group('DiagnosticsScreen — the four states', () {
    testWidgets('loading is the radar skeleton, discs dropped, no spinner',
        (tester) async {
      await tester.pumpWidget(_host(_pending));
      await tester.pump(const Duration(milliseconds: 16));

      final state = emptyState(tester);
      expect(state.variant, JeebEmptyStateVariant.radar);
      expect(state.status, JeebEmptyStateStatus.loading);
      // No second party on this surface to name.
      expect(state.medallions, isEmpty);
      expect(state.identifier, DiagnosticsScreen.loadingIdentifier);
      // The kit withholds a CTA while loading; nothing should be passed.
      expect(state.action, isNull);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('empty is the inline radar, not a settings row',
        (tester) async {
      await pump(tester, () async => const <DiagSessionFileInfo>[]);

      final state = tester.widget<JeebEmptyState>(
        find.byKey(const Key('diag-row-empty')),
      );
      // Inline: this is a band inside the list, not the whole screen.
      expect(state.compact, isTrue);
      expect(state.variant, JeebEmptyStateVariant.radar);
      expect(state.status, JeebEmptyStateStatus.empty);
      expect(state.identifier, DiagnosticsScreen.sessionsEmptyIdentifier);
      // The stream IS live here, still waiting for a session to be written, so
      // the kit's broadcast core is honest and is NOT overridden.
      expect(state.center, isNull);
      // The export band stays: its rows are the fallback when nothing listed.
      expect(find.byKey(const Key('diag-row-dir-path')), findsOneWidget);
    });

    testWidgets('error is the same illustration, danger-tinted, with a retry',
        (tester) async {
      await pump(tester, _failing);

      final state = emptyState(tester);
      expect(state.variant, JeebEmptyStateVariant.radar);
      expect(state.status, JeebEmptyStateStatus.error);
      expect(state.identifier, DiagnosticsScreen.errorIdentifier);
      // A thrown listing used to render the empty state character for
      // character, so "the folder is unreadable" read as "no files yet".
      expect(find.byKey(const Key('diag-row-empty')), findsNothing);
    });

    testWidgets('retry is the glass pill, never an orange act', (tester) async {
      await pump(tester, _failing);

      final cta = tester.widget<JeebCtaButton>(find.byType(JeebCtaButton));
      // R22 draws no orange CTA; `accent` here would spend the budget (§2.2).
      expect(cta.variant, JeebCtaVariant.outline);
      expect(cta.expand, isFalse);
      expect(
        find.bySemanticsIdentifier(DiagnosticsScreen.retryIdentifier),
        findsOneWidget,
      );
    });

    testWidgets('retry re-runs the listing', (tester) async {
      var calls = 0;
      Future<List<DiagSessionFileInfo>> loader() {
        calls++;
        if (calls == 1) return _failing();
        return Future<List<DiagSessionFileInfo>>.value(_sessions);
      }

      await pump(tester, loader);
      expect(emptyState(tester).status, JeebEmptyStateStatus.error);

      await tester.tap(find.byType(JeebCtaButton));
      await tester.pumpAndSettle();

      expect(calls, 2);
      expect(find.byKey(const Key('diag-session-row-0')), findsOneWidget);
    });

    testWidgets('the disabled gate is an empty, and drops the refresh action',
        (tester) async {
      Diag.enabledOverride = false;
      await pump(tester, () async => _sessions);

      final state = emptyState(tester);
      expect(state.identifier, DiagnosticsScreen.disabledIdentifier);
      expect(state.status, JeebEmptyStateStatus.empty);
      expect(find.text('Diagnostics is only available in dev builds.'),
          findsOneWidget);
      // The stream is OFF, so the kit's lit broadcast core would be a lie —
      // the same override E2's failure form makes (wave-B ruling).
      expect(state.center, isNotNull);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      // The action used to survive the gate and run a directory listing whose
      // result no body would ever render (SCREENS_WAVE03_FINDINGS).
      final bar = tester.widget<JeebTopBar>(find.byType(JeebTopBar));
      expect(bar.trailing, isNull);
    });
  });
}
