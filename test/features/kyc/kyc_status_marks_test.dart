// M5/A4 + M5/B3 — what heads each KYC terminal, and how it behaves.
//
//   pending  → STILL glyph. The looping `kyc-review.json` scan-line is gone:
//              R23 is board-static, and the board can express idle motion, so
//              its silence there is the designer's decision, not an omission.
//   approved → success-check.json, played ONCE, on a user-triggered transition
//              the frozen board export could never have depicted.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

import 'package:jeeb_mobile/core/theme/jeeb_midnight_palette.dart';
import 'package:jeeb_mobile/features/kyc/application/kyc_poll_schedule.dart';
import 'package:jeeb_mobile/features/kyc/application/kyc_wizard_cubit.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_gateway.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_submission.dart';
import 'package:jeeb_mobile/features/kyc/presentation/kyc_status_view.dart';
import 'package:jeeb_mobile/features/kyc/presentation/widgets/kyc_status_marks.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';

import '../../support/lottie_ink.dart';
import '../../support/sync_app_localizations.dart';

/// A one-probe schedule keeps the pending body's poller from firing during
/// these render-only cases.
const _quietSchedule = KycPollSchedule(
  tiers: [
    KycPollTier(until: Duration(hours: 1), interval: Duration(hours: 1)),
  ],
  tailInterval: Duration(hours: 1),
  maxElapsed: Duration(hours: 1),
  maxScheduledProbes: 1,
  maxResumeProbes: 1,
);

Future<KycWizardCubit> _cubit(KycStatus status) async {
  final cubit = KycWizardCubit(
    pickerService: StubPhotoPickerService(),
    gateway: FakeKycGateway(initial: KycSubmission(status: status)),
  );
  if (status != KycStatus.notSubmitted) await cubit.loadStatus();
  return cubit;
}

Future<void> _pumpStatus(
  WidgetTester tester,
  KycWizardCubit cubit, {
  bool disableAnimations = false,
}) async {
  await tester.pumpWidget(
    wrapForTest(
      BlocProvider<KycWizardCubit>.value(
        value: cubit,
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: disableAnimations),
            child: const Scaffold(
              body: SafeArea(
                child: KycStatusView(pollSchedule: _quietSchedule),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  // Bounded pumps only — the approved mark is mid-flight at this point.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// The [AnimationController] actually driving the approved mark's composition.
AnimationController _approvedController(WidgetTester tester) =>
    tester.widget<LottieBuilder>(
          find.descendant(
            of: find.byType(KycApprovedMark),
            matching: find.byType(LottieBuilder),
          ),
        ).controller!
        as AnimationController;

void main() {
  group('A4 — the pending terminal is still', () {
    testWidgets('it leads with the glyph and paints no Lottie at all', (
      tester,
    ) async {
      final cubit = await _cubit(KycStatus.pending);
      addTearDown(cubit.close);
      await _pumpStatus(tester, cubit);

      expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
      expect(
        find.byType(LottieBuilder),
        findsNothing,
        reason: 'R23 is board-static: nothing on it may idle',
      );
      // The pending contract is untouched by the removal.
      expect(find.byKey(KycStatusView.pendingTitleKey), findsOneWidget);
      expect(find.byKey(KycStatusView.checkAgainCtaKey), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('kyc_status_topup_allowed_note'),
        findsOneWidget,
      );
    });

    testWidgets('and it is still under reduce motion too — same still glyph', (
      tester,
    ) async {
      final cubit = await _cubit(KycStatus.pending);
      addTearDown(cubit.close);
      await _pumpStatus(tester, cubit, disableAnimations: true);

      expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
      expect(find.byType(LottieBuilder), findsNothing);
    });
  });

  group('B3 — the approved terminal plays its success mark once', () {
    testWidgets('it replaces the glyph and is controller-driven', (
      tester,
    ) async {
      final cubit = await _cubit(KycStatus.approved);
      addTearDown(cubit.close);
      await _pumpStatus(tester, cubit);

      expect(find.byType(KycApprovedMark), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsNothing);
      // A controller is what makes it a one-shot rather than a loop.
      expect(_approvedController(tester), isNotNull);
      expect(find.byKey(KycStatusView.approvedTitleKey), findsOneWidget);
      expect(find.bySemanticsIdentifier('kyc_status_feed_cta'), findsOneWidget);
    });

    testWidgets('it runs forward, then settles and STAYS settled', (
      tester,
    ) async {
      final cubit = await _cubit(KycStatus.approved);
      addTearDown(cubit.close);
      await _pumpStatus(tester, cubit);

      final AnimationController c = _approvedController(tester);
      await tester.pump(const Duration(milliseconds: 200));
      expect(c.isAnimating, isTrue, reason: 'the beat is live mid-flight');
      expect(c.value, greaterThan(0));
      expect(c.value, lessThan(1));

      await tester.pump(c.duration!);
      expect(c.value, 1.0);
      expect(c.isAnimating, isFalse, reason: 'one-shot: it may never re-arm');

      await tester.pump(c.duration!);
      expect(c.value, 1.0);
      expect(c.isAnimating, isFalse);
    });

    testWidgets('reduce motion holds the settled check and NEVER animates', (
      tester,
    ) async {
      final cubit = await _cubit(KycStatus.approved);
      addTearDown(cubit.close);
      await _pumpStatus(tester, cubit, disableAnimations: true);

      final AnimationController c = _approvedController(tester);
      expect(c.isAnimating, isFalse);
      expect(
        c.value,
        1.0,
        reason: 'the confirmation still reads; nothing moves to deliver it',
      );

      await tester.pump(const Duration(milliseconds: 400));
      expect(c.isAnimating, isFalse);
      expect(c.value, 1.0);
    });

    // The mark sits on the wizard's `content` field, whose base washes
    // surfaceHigh → surface → page, so its ink must clear ALL of them.
    test('its authored ink reads on every navy the field washes through', () {
      final Set<Color> ink = lottieSolidColors(
        'assets/animations/success-check.json',
      );
      expect(ink, hasLength(2), reason: 'a green disc and a navy tick');

      const Color success = Color(0xFF3BB273);
      expect(
        ink.any((Color c) => closeToColor(JeebMidnight.page).matches(c, {})),
        isTrue,
      );
      expect(ink.any((Color c) => closeToColor(success).matches(c, {})), isTrue);

      for (final Color navy in <Color>[
        JeebMidnight.page,
        JeebMidnight.surface,
        JeebMidnight.surfaceHigh,
        JeebMidnight.surfaceHighest,
      ]) {
        expect(inkContrast(success, navy), greaterThanOrEqualTo(4.5),
            reason: '$navy');
      }
      // And the navy tick cut back out of the disc it sits in.
      expect(
        inkContrast(JeebMidnight.page, success),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  testWidgets('the three glyph terminals keep their icons', (tester) async {
    final rejected = await _cubit(KycStatus.rejected);
    addTearDown(rejected.close);
    await _pumpStatus(tester, rejected);

    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(find.byType(KycApprovedMark), findsNothing);
    expect(find.byType(LottieBuilder), findsNothing);
  });
}
