// MIDNIGHT M3-02 adoption instruments (escalate / dispute-open-evidence).
//
// Goldens are blind to a token re-point (the comparator tolerates 5% pixel
// diff), so every value this lane moved is read back off the built widget here.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/theme/jeeb_radii.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/features/escalate/application/escalate_cubit.dart';
import 'package:jeeb_mobile/features/escalate/domain/escalate_repository.dart';
import 'package:jeeb_mobile/features/escalate/presentation/escalate_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _Repo implements EscalateRepository {
  const _Repo({this.failWith, this.stall = false});
  final EscalateErrorKind? failWith;
  final bool stall;

  @override
  Future<EscalateEvidence> fetchEvidence({required String deliveryId}) async =>
      const EscalateEvidence(
        chatSnapshotUrl: 'https://cdn.jeeb.app/snapshots/conv-1.html',
        chatMessageCount: 3,
        timeline: <EscalateTimelineEntry>[
          EscalateTimelineEntry(status: 'Ordered'),
        ],
      );

  @override
  Future<EscalateResult> submitEscalation({
    required String deliveryId,
    required EscalateReason reason,
    String? comment,
    List<String> photoPaths = const <String>[],
    String? voicePath,
    EscalateEvidence evidence = EscalateEvidence.empty,
  }) {
    if (stall) return Completer<EscalateResult>().future;
    final EscalateErrorKind? failure = failWith;
    if (failure != null) {
      return Future<EscalateResult>.error(EscalateException(failure));
    }
    return Future<EscalateResult>.value(
      const EscalateResult(caseId: 'dispute-1', status: 'open'),
    );
  }
}

class _EvidenceProbeRepo extends _Repo {
  int fetches = 0;

  @override
  Future<EscalateEvidence> fetchEvidence({required String deliveryId}) async {
    fetches++;
    return super.fetchEvidence(deliveryId: deliveryId);
  }
}

Widget _harness(EscalateCubit cubit) => MaterialApp(
  theme: AppTheme.midnight(),
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const <LocalizationsDelegate<Object?>>[
    SyncAppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  // Midnight primitives loop ∞ (02-STUDY-NOTES M0-4).
  builder: (BuildContext context, Widget? child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child!,
  ),
  home: BlocProvider<EscalateCubit>.value(
    value: cubit,
    child: const EscalateScreen(),
  ),
);

EscalateCubit _cubit([EscalateRepository repo = const _Repo()]) =>
    EscalateCubit(repository: repo, deliveryId: 'dlv-1');

/// The card surface of one reason row: the only rounded box inside it that
/// carries the kit's `lg` radius (the radio glyph is an icon, not a box).
BoxDecoration _rowDecoration(WidgetTester tester, String identifier) {
  final Finder finder = find.descendant(
    of: find.bySemanticsIdentifier(identifier),
    matching: find.byWidgetPredicate((Widget w) {
      if (w is! DecoratedBox) return false;
      final Decoration d = w.decoration;
      return d is BoxDecoration &&
          d.borderRadius == BorderRadius.circular(JeebRadii.lg);
    }),
  );
  expect(finder, findsOneWidget);
  return tester.widget<DecoratedBox>(finder).decoration as BoxDecoration;
}

void main() {
  Future<BuildContext> pump(WidgetTester tester, EscalateCubit cubit) async {
    await tester.pumpWidget(_harness(cubit));
    await tester.pumpAndSettle();
    return tester.element(find.byType(EscalateScreen));
  }

  testWidgets('mounts the content field: centre-upper glow, no wash, still', (
    WidgetTester tester,
  ) async {
    await pump(tester, _cubit());

    final JeebMidnightField field = tester.widget<JeebMidnightField>(
      find.byType(JeebMidnightField),
    );
    expect(field.variant, JeebFieldVariant.content);
    expect(field.glowPlacement, JeebFieldGlowPlacement.centerUpper);
    // R13 declares no periwinkle wash; painting one would mirror the layers.
    expect(field.washPlacement, isNull);
    expect(field.animateDecor, isFalse);
  });

  testWidgets('the selected reason row is R9 lit: orange-20 fill, 2px accent', (
    WidgetTester tester,
  ) async {
    final BuildContext context = await pump(tester, _cubit());
    final JeebSemanticColors semantics = Theme.of(
      context,
    ).extension<JeebSemanticColors>()!;

    await tester.tap(find.text('Damaged item'));
    await tester.pumpAndSettle();

    final BoxDecoration lit = _rowDecoration(tester, 'dispute_reason_damaged');
    expect(lit.color, semantics.accentSelectedFill);
    final Border border = lit.border! as Border;
    expect(border.top.width, 2);
    expect(border.top.color, context.jeebRoles.accent);
    // R9's lit row is the one card that carries a glow.
    expect(lit.boxShadow, isNotEmpty);

    final BoxDecoration rest = _rowDecoration(tester, 'dispute_reason_fraud');
    expect(rest.color, semantics.glassFill);
    expect((rest.border! as Border).top.width, 1);
    expect(rest.boxShadow, anyOf(isNull, isEmpty));
  });

  testWidgets('the rest radio ring is the glassBorderVivid rung', (
    WidgetTester tester,
  ) async {
    final BuildContext context = await pump(tester, _cubit());
    final JeebSemanticColors semantics = Theme.of(
      context,
    ).extension<JeebSemanticColors>()!;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final Icon ring = tester.widget<Icon>(
      find
          .descendant(
            of: find.bySemanticsIdentifier('dispute_reason_fraud'),
            matching: find.byIcon(Icons.radio_button_unchecked),
          )
          .first,
    );
    expect(ring.color, semantics.glassBorderVivid);
    // The 14% outline is the wrong rung for a radio ring (§3).
    expect(ring.color, isNot(scheme.outline));
  });

  testWidgets('the discard action is danger-SOFT, never full-strength error', (
    WidgetTester tester,
  ) async {
    final EscalateCubit cubit = _cubit();
    final BuildContext context = await pump(tester, cubit);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    cubit.setVoice('dispute_voice.m4a');
    await tester.pumpAndSettle();

    final Text discard = tester.widget<Text>(find.text('Re-record'));
    expect(discard.style!.color, scheme.onErrorContainer);
    expect(discard.style!.color, isNot(scheme.error));
  });

  testWidgets('the support escape link is the sanctioned orange text link', (
    WidgetTester tester,
  ) async {
    final BuildContext context = await pump(tester, _cubit());

    final Text link = tester.widget<Text>(find.text('Contact support'));
    expect(link.style!.color, context.jeebRoles.accent);
    // Not the periwinkle `text` variant it shipped as.
    expect(
      link.style!.color,
      isNot(Theme.of(context).colorScheme.onSurfaceVariant),
    );
  });

  testWidgets('the photo chip close glyph reads on the white selected slab', (
    WidgetTester tester,
  ) async {
    final EscalateCubit cubit = _cubit();
    final BuildContext context = await pump(tester, cubit);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    cubit.addPhoto('dispute_photo_1.jpg');
    await tester.pumpAndSettle();

    final Icon close = tester.widget<Icon>(find.byIcon(Icons.close).first);
    expect(close.color, scheme.onInverseSurface);
    // White-on-white: the pre-Midnight ink was invisible on the selected pill.
    expect(close.color, isNot(scheme.onPrimary));
  });

  testWidgets('does not request or render a client evidence preview', (
    WidgetTester tester,
  ) async {
    final repository = _EvidenceProbeRepo();
    await pump(tester, _cubit(repository));

    expect(repository.fetches, 0);
    expect(
      find.bySemanticsIdentifier('dispute_evidence_timeline'),
      findsNothing,
    );
    expect(find.bySemanticsIdentifier('dispute_evidence_chat'), findsNothing);
    expect(find.text('Live tracking'), findsNothing);
    expect(find.bySemanticsIdentifier('dispute_submit_cta'), findsOneWidget);
  });

  testWidgets('submitting is the loading empty family, not an OMDS spinner', (
    WidgetTester tester,
  ) async {
    final EscalateCubit stalled = _cubit(const _Repo(stall: true));
    await pump(tester, stalled);
    stalled.setReason(EscalateReason.damaged);
    unawaited(stalled.submit());
    // Two frames: the emit reaches the builder on the stream's next tick.
    await tester.pump();
    await tester.pump();

    final JeebEmptyState loading = tester.widget<JeebEmptyState>(
      find.byType(JeebEmptyState),
    );
    expect(find.bySemanticsIdentifier('dispute_submitting'), findsOneWidget);
    expect(loading.status, JeebEmptyStateStatus.loading);
    expect(loading.variant, JeebEmptyStateVariant.parcel);
  });

  testWidgets('error is the error empty family and keeps a way out', (
    WidgetTester tester,
  ) async {
    final EscalateCubit failing = _cubit(
      const _Repo(failWith: EscalateErrorKind.server),
    );
    await pump(tester, failing);
    failing.setReason(EscalateReason.damaged);
    await failing.submit();
    await tester.pumpAndSettle();

    // The identifier now sits ON the block the kit draws (JeebFailureBlock →
    // JeebEmptyState), so the finder targets it directly.
    expect(find.bySemanticsIdentifier('dispute_error'), findsOneWidget);
    final JeebEmptyState error = tester.widget<JeebEmptyState>(
      find.byType(JeebEmptyState),
    );
    expect(error.effectiveStatus, JeebEmptyStateStatus.error);
    expect(error.reason, JeebEmptyStateReason.failed);
    expect(error.variant, JeebEmptyStateVariant.parcel);
    expect(error.action, isNotNull);
    expect(
      find.bySemanticsIdentifier('dispute_error_retry_cta'),
      findsOneWidget,
    );
  });
}
