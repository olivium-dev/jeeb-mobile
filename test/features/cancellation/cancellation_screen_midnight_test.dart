// M3-04 · per-element assertions for the Midnight adoption of the cancellation
// screen. Goldens tolerate 5% pixel diff, so a token re-point on a Ø22 disc or
// a CTA fill is invisible to them — every value here is read off the widget.
//
// The screen is derived from R9 (the board never drew it), so the assertions
// that matter most are the ones where it must NOT follow R9: R9 spends orange
// on its affirmative act, and this act is destructive.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_omds_tokens.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_info_note.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_outlined_card.dart';
import 'package:jeeb_mobile/features/cancellation/domain/cancellation_repository.dart';
import 'package:jeeb_mobile/features/cancellation/domain/cancellation_result.dart';
import 'package:jeeb_mobile/features/cancellation/presentation/cancellation_screen.dart';
import 'package:jeeb_mobile/features/cancellation/presentation/cubit/cancellation_state.dart';
import 'package:jeeb_mobile/features/cancellation/presentation/widgets/cancellation_reason_group.dart';
import 'package:jeeb_mobile/features/cancellation/presentation/widgets/cancellation_success_sheet.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _InertRepository implements CancellationRepository {
  const _InertRepository();

  @override
  Future<CancellationResult> cancel({
    required String deliveryId,
    required String reason,
    String? otherDetails,
  }) async =>
      const CancellationResult(deliveryId: 'd1', weeklyCount: 1);
}

Widget _host(Widget child) {
  return OmdsColorTokensProvider(
    tokens: jeebMidnightOmdsTokens,
    child: MaterialApp(
      theme: AppTheme.midnight(),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object?>>[
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // JeebEmptyState's illustrations loop ∞ by design (02-STUDY-NOTES
      // §Motion): pumpAndSettle only terminates under reduce motion.
      builder: (context, inner) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: inner!,
      ),
      home: child,
    ),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  CancellationState? initialState,
  bool isJeeber = false,
}) async {
  await tester.pumpWidget(
    _host(
      CancellationScreen(
        deliveryId: 'd1',
        isJeeber: isJeeber,
        repository: const _InertRepository(),
        initialState: initialState,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ColorScheme _scheme(WidgetTester tester) => Theme.of(
      tester.element(find.byType(CancellationScreen)),
    ).colorScheme;

Container _mark(WidgetTester tester, String reason) => tester.widget<Container>(
      find.descendant(
        of: find.byKey(CancellationReasonGroup.markKey(reason)),
        matching: find.byType(Container),
      ),
    );

void main() {
  group('M3-04 field (R9 carry-over)', () {
    testWidgets('content variant, top-start ORANGE glow, no periwinkle wash, '
        'still', (tester) async {
      await _pump(tester);
      final field = tester.widget<JeebMidnightField>(
        find.byType(JeebMidnightField),
      );

      expect(field.variant, JeebFieldVariant.content);
      expect(
        field.glowPlacement,
        JeebFieldGlowPlacement.topStart,
        reason: 'nearest tile R9 declares one orange radial top-start',
      );
      expect(
        field.washPlacement,
        isNull,
        reason: 'wave-C: R4/R9/R17 declare ZERO periwinkle — a wash here '
            'would paint the wrong layer',
      );
      expect(
        field.animateDecor,
        isFalse,
        reason: 'motion ruling 1 — a tile-less M3 screen earns no novelty '
            'motion',
      );
    });
  });

  group('M3-04 destructive ink (where it must NOT follow R9)', () {
    testWidgets('picked reason mark is danger-soft, not the accent disc',
        (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Changed my mind'));
      await tester.pumpAndSettle();

      final scheme = _scheme(tester);
      final decoration =
          _mark(tester, 'changed_mind').decoration! as BoxDecoration;

      expect(decoration.color, scheme.onErrorContainer);
      expect(decoration.color, isNot(scheme.primary));
      expect(decoration.shape, BoxShape.circle);

      final check = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(CancellationReasonGroup.markKey('changed_mind')),
          matching: find.byType(Icon),
        ),
      );
      expect(
        check.color,
        scheme.onError,
        reason: '§1 — white on the red family fails AA; page navy passes',
      );
    });

    testWidgets('unpicked mark rings at glassBorderVivid, 2px', (tester) async {
      await _pump(tester);
      final decoration =
          _mark(tester, 'changed_mind').decoration! as BoxDecoration;
      final side = decoration.border!.top;

      expect(
        side.color,
        JeebSemanticColors.midnight().glassBorderVivid,
        reason: '§3 — glassBorderVivid was added for exactly the radio ring',
      );
      expect(side.width, CancellationReasonGroup.markRingWidth);
      expect(
        side.color,
        isNot(_scheme(tester).surfaceContainerHighest),
        reason: 'the opaque navy rung this shipped on is not a glass border',
      );
    });

    testWidgets('picked row is the neutral fill swap, never accentSelected',
        (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Changed my mind'));
      await tester.pumpAndSettle();

      final card = tester.widget<JeebOutlinedCard>(
        find.ancestor(
          of: find.byKey(CancellationReasonGroup.markKey('changed_mind')),
          matching: find.byType(JeebOutlinedCard),
        ),
      );
      expect(card.state, JeebCardState.selected);
      expect(
        card.state,
        isNot(JeebCardState.accentSelected),
        reason: 'R9 lights its row orange because its tile draws it; no tile '
            'draws this destructive screen',
      );
    });

    testWidgets('CTA is the glass pill, never the accent pill', (tester) async {
      await _pump(tester);
      final cta = tester.widget<JeebCtaButton>(find.byType(JeebCtaButton));

      expect(cta.variant, JeebCtaVariant.outline);
      expect(
        cta.variant,
        isNot(JeebCtaVariant.accent),
        reason: 'theme ruling 3 — when in doubt: not orange',
      );
    });

    testWidgets('success sheet glyph is the cancelled-status ink, not orange',
        (tester) async {
      await tester.pumpWidget(
        _host(
          CancellationSuccessSheet(
            result: const CancellationResult(deliveryId: 'd1', weeklyCount: 1),
            onDone: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scheme = Theme.of(
        tester.element(find.byType(CancellationSuccessSheet)),
      ).colorScheme;
      final glyph = tester.widget<Icon>(find.byType(Icon));

      expect(glyph.icon, Icons.cancel);
      expect(
        glyph.color,
        scheme.onSecondaryContainer,
        reason: "R21 draws a cancelled order's glyph in inkSoft",
      );
      expect(glyph.color, isNot(scheme.primary));
    });
  });

  group('M3-04 states', () {
    testWidgets('idle draws the picker and the docked CTA', (tester) async {
      await _pump(tester);

      expect(find.byType(CancellationReasonGroup), findsOneWidget);
      expect(find.byType(JeebCtaButton), findsOneWidget);
      expect(find.byType(JeebInfoNote), findsNothing);
      expect(find.byType(JeebEmptyState), findsNothing);
    });

    testWidgets('loading disables the CTA and keeps the picker', (tester) async {
      await _pump(tester, initialState: const CancellationLoading());

      final cta = tester.widget<JeebCtaButton>(find.byType(JeebCtaButton));
      expect(cta.isEnabled, isFalse);
      expect(find.byType(CancellationReasonGroup), findsOneWidget);
    });

    testWidgets('5xx draws a persistent error strip, not a snackbar',
        (tester) async {
      await _pump(tester, initialState: const CancellationError('boom'));

      final note = tester.widget<JeebInfoNote>(find.byType(JeebInfoNote));
      expect(note.tone, JeebInfoNoteTone.error);
      expect(
        find.byType(SnackBar),
        findsNothing,
        reason: 'the state used to flash and vanish, leaving nothing on screen',
      );
      expect(
        find.byType(CancellationReasonGroup),
        findsOneWidget,
        reason: 'the selection stays live so retry is one tap away',
      );
    });

    testWidgets('409 is the empty family: E3 street, picker and CTA gone',
        (tester) async {
      await _pump(tester, initialState: const CancellationTooLate());

      final empty = tester.widget<JeebEmptyState>(find.byType(JeebEmptyState));
      expect(empty.variant, JeebEmptyStateVariant.street);
      expect(empty.status, JeebEmptyStateStatus.empty);
      expect(find.byType(CancellationReasonGroup), findsNothing);
      expect(
        find.byType(JeebCtaButton),
        findsNothing,
        reason: 'nothing left to confirm once the delivery is moving',
      );
    });
  });

  group('M3-04 frozen identifiers survive', () {
    testWidgets('every pass-1 id is still on a real element', (tester) async {
      await _pump(tester);

      for (final String id in <String>[
        'cancellation_root',
        'cancellation_back',
        'cancellation_reason_changed_mind',
        'cancellation_reason_other',
        'cancellation_submit_cta',
      ]) {
        expect(
          find.bySemanticsIdentifier(id),
          findsOneWidget,
          reason: '$id is frozen',
        );
      }

      await tester.tap(find.text('Other'));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsIdentifier('cancellation_other_field'),
        findsOneWidget,
      );
    });
  });
}
