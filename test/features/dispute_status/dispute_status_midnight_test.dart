// M3-32 per-element Midnight assertions for DisputeStatusScreen.
//
// Goldens are evidence, not gates (02-STUDY-NOTES, wave-C fixup): the shared
// comparator tolerates 5% pixel diff, so a stepper-ink swap or a spinner
// re-inking can pass every golden unchanged. Every value this row moved is read
// back off the built widget here.
//
// Derived screen — no tile of its own. R3 (live tracking) carries the lifecycle
// band, R13 (OTP handover) carries the field and the glass strips.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_stepper.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_top_bar.dart';
import 'package:jeeb_mobile/features/dispute_status/domain/dispute_status_repository.dart';
import 'package:jeeb_mobile/features/dispute_status/presentation/dispute_status_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _CannedRepository implements DisputeStatusRepository {
  const _CannedRepository(this.dispute);

  final DisputeStatus dispute;

  @override
  Future<DisputeStatus> fetchDispute(String disputeId) async => dispute;
}

class _FailingRepository implements DisputeStatusRepository {
  const _FailingRepository();

  @override
  Future<DisputeStatus> fetchDispute(String disputeId) async {
    throw const DisputeStatusRepositoryException(DisputeStatusFailure.network);
  }
}

class _PendingRepository implements DisputeStatusRepository {
  _PendingRepository();

  final Completer<DisputeStatus> _held = Completer<DisputeStatus>();

  @override
  Future<DisputeStatus> fetchDispute(String disputeId) => _held.future;
}

const DisputeStatus _pendingDispute = DisputeStatus(
  id: 'dsp-1',
  state: DisputeState.pending,
  orderRef: 'ORD-1',
);

const DisputeStatus _closedDispute = DisputeStatus(
  id: 'dsp-2',
  state: DisputeState.closed,
  orderRef: 'ORD-2',
);

Widget _harness(DisputeStatusRepository repo) {
  final router = GoRouter(
    initialLocation: '/disputes/dsp-1',
    routes: [
      GoRoute(
        path: '/disputes/:id',
        builder: (_, s) => DisputeStatusScreen(
          disputeId: s.pathParameters['id'] ?? '',
          repository: repo,
        ),
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    theme: AppTheme.midnight(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    // JeebEmptyState's radar loops by design; pumpAndSettle only settles under
    // reduce motion (02-STUDY-NOTES wave-B regression attribution).
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
  );
}

void main() {
  Future<void> pump(WidgetTester tester, DisputeStatusRepository repo) async {
    await tester.pumpWidget(_harness(repo));
    await tester.pumpAndSettle();
  }

  JeebMidnightField field(WidgetTester tester) =>
      tester.widget<JeebMidnightField>(find.byType(JeebMidnightField));

  JeebEmptyState emptyState(WidgetTester tester) =>
      tester.widget<JeebEmptyState>(find.byType(JeebEmptyState));

  Text stepLabel(WidgetTester tester, String identifier) => tester.widget<Text>(
    find.descendant(
      of: find.bySemanticsIdentifier(identifier),
      matching: find.byType(Text),
    ),
  );

  group('field — derived from R13', () {
    testWidgets('content variant, glow centreUpper, no wash, decor still', (
      tester,
    ) async {
      await pump(tester, const _CannedRepository(_pendingDispute));

      final f = field(tester);
      // R13's only radial: `520px 440px at 50% 42%`, no rings, no twinkles.
      expect(f.variant, JeebFieldVariant.content);
      expect(f.glowPlacement, JeebFieldGlowPlacement.centerUpper);
      // R13 declares zero periwinkle — glow and wash are separate layers.
      expect(f.washPlacement, isNull);
      // M3 standing ruling: no motion beyond what kit widgets animate.
      expect(f.animateDecor, isFalse);
    });

    testWidgets('the field is not covered by an opaque scaffold', (
      tester,
    ) async {
      await pump(tester, const _CannedRepository(_pendingDispute));

      final scaffold = tester.widget<Scaffold>(
        find.descendant(
          of: find.byType(JeebMidnightField),
          matching: find.byType(Scaffold),
        ),
      );
      expect(scaffold.backgroundColor, Colors.transparent);
    });

    testWidgets('the header is the in-body bar, never a Material app bar', (
      tester,
    ) async {
      await pump(tester, const _CannedRepository(_pendingDispute));

      expect(find.byType(JeebTopBar), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(OMDSAppBar), findsNothing);
    });
  });

  group('lifecycle band — derived from R3', () {
    testWidgets('is the kit BAR form with the accent fill-through', (
      tester,
    ) async {
      await pump(tester, const _CannedRepository(_pendingDispute));

      final stepper = tester.widget<JeebStepper>(find.byType(JeebStepper));
      // R3 draws bars; the node form belongs to no Midnight tile.
      expect(stepper.stepCount, 3);
      expect(stepper.labels, isEmpty);
      expect(stepper.doneInk, JeebStepperDoneInk.accent);
      expect(stepper.currentIndex, 0);
    });

    testWidgets('a closed dispute advances the band to the last step', (
      tester,
    ) async {
      await pump(tester, const _CannedRepository(_closedDispute));

      final stepper = tester.widget<JeebStepper>(find.byType(JeebStepper));
      expect(stepper.currentIndex, 2);
    });

    testWidgets('all three frozen step identifiers stay addressable', (
      tester,
    ) async {
      await pump(tester, const _CannedRepository(_pendingDispute));

      for (final id in const <String>[
        'dispute_status_stepper',
        'dispute_status_step_submitted',
        'dispute_status_step_review',
        'dispute_status_step_resolved',
      ]) {
        expect(find.bySemanticsIdentifier(id), findsOneWidget, reason: id);
      }
    });

    testWidgets('the active label is accent w800, the others muted 10.5', (
      tester,
    ) async {
      await pump(tester, const _CannedRepository(_pendingDispute));

      final context = tester.element(find.byType(JeebStepper));
      final scheme = Theme.of(context).colorScheme;
      final accent = context.jeebRoles.accent;

      final active = stepLabel(tester, 'dispute_status_step_pending');
      expect(active.style?.color, accent);
      expect(active.style?.fontWeight, FontWeight.w800);
      // Board `font-size:10.5px` — the `label` rung, not `caption` (11.5).
      expect(active.style?.fontSize, 10.5);

      for (final id in const <String>[
        'dispute_status_step_fixed',
        'dispute_status_step_closed',
      ]) {
        final other = stepLabel(tester, id);
        expect(other.style?.color, scheme.onSurfaceVariant, reason: id);
        expect(other.style?.color, isNot(accent), reason: id);
        expect(other.style?.fontSize, 10.5, reason: id);
      }
    });
  });

  group('pre-load frames — the empty family', () {
    testWidgets('loading is the radar skeleton, discs dropped, no spinner', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(_PendingRepository()));
      await tester.pumpAndSettle();

      final state = emptyState(tester);
      expect(state.variant, JeebEmptyStateVariant.radar);
      expect(state.status, JeebEmptyStateStatus.loading);
      // No second party on this surface to name.
      expect(state.medallions, isEmpty);
      expect(state.identifier, 'dispute_status_loading');
      // The OMDS spinner this row deleted defaulted to `colorScheme.primary`,
      // which IS #D73B00 under Midnight — an orange spend on a cold read.
      expect(find.byType(OmdsLoadingState), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('error is the same illustration, danger-tinted', (
      tester,
    ) async {
      await pump(tester, const _FailingRepository());

      final state = emptyState(tester);
      expect(state.variant, JeebEmptyStateVariant.radar);
      expect(state.status, JeebEmptyStateStatus.error);
      expect(state.identifier, 'dispute_status_error');
      // The hand-rolled 64px error glyph this row deleted.
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('the retry is the glass pill, never a lit CTA', (tester) async {
      await pump(tester, const _FailingRepository());

      final retry = tester.widget<JeebCtaButton>(
        find.descendant(
          of: find.bySemanticsIdentifier('dispute_status_retry_cta'),
          matching: find.byType(JeebCtaButton),
        ),
      );
      expect(retry.variant, JeebCtaVariant.outline);
      expect(retry.variant, isNot(JeebCtaVariant.accent));
      expect(retry.variant, isNot(JeebCtaVariant.primary));
      // R13's glass pill runs the full content box.
      expect(retry.expand, isTrue);
    });
  });

  group('empty evidence block', () {
    testWidgets('an attached set draws the grouped card, not the empty block', (
      tester,
    ) async {
      await pump(
        tester,
        const _CannedRepository(
          DisputeStatus(
            id: 'dsp-3',
            state: DisputeState.open,
            evidence: DisputeEvidenceSummary(photoCount: 2),
          ),
        ),
      );

      expect(
        find.bySemanticsIdentifier('dispute_status_evidence_summary'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('dispute_status_evidence_empty'),
        findsNothing,
      );
    });

    testWidgets(
      'an empty set draws E4 inline, never a heading over dead space',
      (tester) async {
        await pump(tester, const _CannedRepository(_pendingDispute));

        final empty = tester.widget<JeebEmptyState>(
          find.byType(JeebEmptyState),
        );
        // Wave-C ruling 9: parcel IS "nothing in the box".
        expect(empty.variant, JeebEmptyStateVariant.parcel);
        expect(empty.status, JeebEmptyStateStatus.empty);
        // Inline block inside the scroll list, not a screen-owning illustration.
        expect(empty.compact, isTrue);
        expect(empty.identifier, 'dispute_status_evidence_empty');
        // The frozen summary id still renders around it.
        expect(
          find.bySemanticsIdentifier('dispute_status_evidence_summary'),
          findsOneWidget,
        );
      },
    );
  });

  group('orange budget', () {
    testWidgets('the docked support act stays periwinkle', (tester) async {
      await pump(tester, const _CannedRepository(_pendingDispute));

      final support = tester.widget<JeebCtaButton>(
        find.descendant(
          of: find.bySemanticsIdentifier('dispute_status_support'),
          matching: find.byType(JeebCtaButton),
        ),
      );
      // "When in doubt: not orange" (M0-2 ruling 3) — no tile draws an orange
      // act here, so the band is the screen's only accent.
      expect(support.variant, JeebCtaVariant.primary);
    });

    testWidgets('the band is the ONLY orange ink on the loaded frame', (
      tester,
    ) async {
      await pump(tester, const _CannedRepository(_pendingDispute));

      final context = tester.element(find.byType(JeebTopBar));
      final scheme = Theme.of(context).colorScheme;
      // Sanity: under Midnight `primary` IS the brand orange, so a non-CTA
      // reading `.primary` is a budget leak, not a navy tint.
      expect(scheme.primary, context.jeebRoles.accent);

      final band = tester
          .widgetList<Text>(
            find.descendant(
              of: find.bySemanticsIdentifier('dispute_status_stepper'),
              matching: find.byType(Text),
            ),
          )
          .toSet();
      // R3's active label is the one sanctioned accent run.
      expect(band.where((t) => t.style?.color == scheme.primary), hasLength(1));
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        if (band.contains(text)) continue;
        expect(text.style?.color, isNot(scheme.primary), reason: text.data);
      }
      for (final icon in tester.widgetList<Icon>(find.byType(Icon))) {
        expect(icon.color, isNot(scheme.primary));
      }
    });
  });
}
