// M3-03 · the waiting screen adopts E2 (empty — waiting for offers).
//
// Per-element assertions, NOT goldens: the comparator tolerates 5% pixel diff,
// so a token re-point on the countdown dot or the field anchor passes a golden
// unchanged. Every expectation here reads the value off the widget.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/theme/jeeb_radii.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/theme/jeeb_shadows.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_glass_card.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/application/waiting_cubit.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/data/fake_waiting_repository.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/domain/waiting_repository.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/domain/waiting_request.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/presentation/no_offer_timeout_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

final DateTime _now = DateTime.utc(2026, 6, 18, 9);

WaitingRequest _seed({
  WaitingRequestPhase phase = WaitingRequestPhase.broadcasting,
  int notified = 6,
  int offers = 0,
  Duration? remaining = const Duration(minutes: 4, seconds: 30),
}) => WaitingRequest(
  requestId: 'req-midnight-001',
  phase: phase,
  notifiedCount: notified,
  offerCount: offers,
  receivedAt: _now,
  remainingAtReceipt: remaining,
  displayId: 'ORD-5001',
  tier: 'express',
  title: 'Pharmacy run',
);

Widget _harness(WaitingRepository repository) => MaterialApp(
  theme: AppTheme.midnight(),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const <LocalizationsDelegate<Object?>>[
    SyncAppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: NoOfferTimeoutScreen(
    requestId: 'req-midnight-001',
    repository: repository,
    cubitFactory: (repo, requestId) => WaitingCubit(
      repository: repo,
      requestId: requestId,
      now: () => _now,
      refreshSignals: const Stream<void>.empty(),
      clockTicks: const Stream<void>.empty(),
    ),
  ),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child!,
  ),
);

Future<void> _pump(WidgetTester tester, WaitingRepository repository) async {
  await tester.pumpWidget(_harness(repository));
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final view = binding.platformDispatcher.views.first;
    // The board canvas — the illustration is 300 wide and the block gutters 36.
    view.physicalSize = const Size(440, 956);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });

  group('M3-03 — E2 adoption', () {
    testWidgets('the field is E2s own glow: content, centerUpper, NO wash', (
      tester,
    ) async {
      await _pump(tester, FakeWaitingRepository(seed: _seed()));

      final field = tester.widget<JeebMidnightField>(
        find.byType(JeebMidnightField),
      );
      expect(field.variant, JeebFieldVariant.content);
      expect(
        field.glowPlacement,
        JeebFieldGlowPlacement.centerUpper,
        reason: 'board: radial-gradient(520px 460px at 50% 42%)',
      );
      expect(
        field.washPlacement,
        isNull,
        reason:
            'E2 declares no periwinkle wash — adopting one paints a layer '
            'the tile does not have',
      );
      expect(field.glowColor, isNull, reason: 'content already carries .22');
      expect(field.animateDecor, isFalse);
    });

    testWidgets('every state draws the radar, never E1', (tester) async {
      for (final (WaitingRepository repo, String label)
          in <(WaitingRepository, String)>[
            (FakeWaitingRepository(seed: _seed()), 'broadcasting'),
            (
              FakeWaitingRepository(seed: _seed(remaining: Duration.zero)),
              'no offers yet',
            ),
            (
              FakeWaitingRepository(
                seed: _seed(
                  phase: WaitingRequestPhase.expired,
                  remaining: null,
                ),
              ),
              'terminal',
            ),
            (
              FakeWaitingRepository(
                failure: const WaitingException(WaitingFailure.network),
              ),
              'error',
            ),
          ]) {
        await _pump(tester, repo);
        final block = tester.widget<JeebEmptyState>(
          find.byType(JeebEmptyState),
        );
        expect(
          block.variant,
          JeebEmptyStateVariant.radar,
          reason: '$label must draw E2s radar',
        );
      }
    });

    testWidgets('the error form danger-tints and drops the live core', (
      tester,
    ) async {
      await _pump(
        tester,
        FakeWaitingRepository(
          failure: const WaitingException(WaitingFailure.network),
        ),
      );

      final block = tester.widget<JeebEmptyState>(find.byType(JeebEmptyState));
      // `reason:` now derives the rung, so `status:` stays at its default.
      expect(block.effectiveStatus, JeebEmptyStateStatus.error);
      expect(
        block.center,
        isNotNull,
        reason: 'a failed read must not bloom a live broadcast core',
      );
      expect(block.identifier, 'waiting_error_state');
    });

    testWidgets('the countdown capsule is E2s glass pill with a lit dot', (
      tester,
    ) async {
      await _pump(tester, FakeWaitingRepository(seed: _seed()));

      final capsule = tester.widget<JeebGlassCard>(
        find.byType(JeebGlassCard).first,
      );
      expect(capsule.identifier, 'waiting_countdown');
      expect(
        capsule.radius,
        JeebRadii.pill,
        reason: 'board: border-radius 999px',
      );

      final context = tester.element(find.byType(JeebEmptyState));
      final accent = context.jeebRoles.accent;
      final dot = tester.widget<DecoratedBox>(
        find.byKey(const Key('waiting-countdown-dot')),
      );
      final decoration = dot.decoration as BoxDecoration;
      expect(decoration.color, accent, reason: 'board: var(--jeeb-orange)');
      expect(decoration.shape, BoxShape.circle);
      expect(
        decoration.boxShadow,
        JeebShadows.glowDot,
        reason: 'board: 0 0 10px rgba(215,59,0,.8)',
      );
    });

    testWidgets('the pending capsule spends no orange', (tester) async {
      await _pump(tester, FakeWaitingRepository(seed: _seed(remaining: null)));

      expect(
        find.byKey(const Key('waiting-countdown-dot')),
        findsNothing,
        reason: 'no live window means no lit dot',
      );

      final context = tester.element(find.byType(JeebEmptyState));
      final muted = Theme.of(
        context,
      ).extension<JeebSemanticColors>()!.mutedText;
      final glyph = tester.widget<Icon>(
        find.descendant(
          of: find.bySemanticsIdentifier('waiting_countdown'),
          matching: find.byType(Icon),
        ),
      );
      expect(glyph.color, muted);
      expect(glyph.color, isNot(context.jeebRoles.accent));
    });

    testWidgets('the footer is E2s glass pill over a periwinkle text link', (
      tester,
    ) async {
      await _pump(tester, FakeWaitingRepository(seed: _seed()));

      final retarget = tester.widget<JeebCtaButton>(
        find.descendant(
          of: find.bySemanticsIdentifier('waiting_retarget_cta'),
          matching: find.byType(JeebCtaButton),
        ),
      );
      expect(
        retarget.variant,
        JeebCtaVariant.outline,
        reason: 'board: rgba(255,255,255,.08) fill, .16 border, white ink',
      );

      final cancel = tester.widget<JeebCtaButton>(
        find.descendant(
          of: find.bySemanticsIdentifier('waiting_cancel_cta'),
          matching: find.byType(JeebCtaButton),
        ),
      );
      expect(
        cancel.variant,
        JeebCtaVariant.text,
        reason: 'board: bare 13.5/w600 #8A93D8 line under the pill',
      );
    });

    testWidgets('the arrived-offers CTA stays periwinkle — E2 draws no orange '
        'act', (tester) async {
      await _pump(
        tester,
        FakeWaitingRepository(
          seed: _seed(phase: WaitingRequestPhase.offersArrived, offers: 3),
        ),
      );

      final review = tester.widget<JeebCtaButton>(
        find.descendant(
          of: find.bySemanticsIdentifier('waiting_review_offers_cta'),
          matching: find.byType(JeebCtaButton),
        ),
      );
      expect(review.variant, JeebCtaVariant.primary);
      expect(review.variant, isNot(JeebCtaVariant.accent));
    });

    testWidgets('the terminal core takes an outcome quartet, never error', (
      tester,
    ) async {
      await _pump(
        tester,
        FakeWaitingRepository(
          seed: _seed(phase: WaitingRequestPhase.expired, remaining: null),
        ),
      );

      final context = tester.element(find.byType(JeebEmptyState));
      final roles = context.jeebRoles;
      final block = tester.widget<JeebEmptyState>(find.byType(JeebEmptyState));
      expect(
        block.status,
        JeebEmptyStateStatus.empty,
        reason: 'an expired request is an outcome, not a system error',
      );

      final core = tester.widget<DecoratedBox>(
        find.byKey(const Key('waiting-terminal-core')),
      );
      final decoration = core.decoration as BoxDecoration;
      expect(decoration.color, roles.warningContainer);
      expect(decoration.color, isNot(Theme.of(context).colorScheme.error));
    });
  });
}
