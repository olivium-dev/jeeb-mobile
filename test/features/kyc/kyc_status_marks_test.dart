// Wave-3 motion wiring (08-MOTION-SPEC §2.8/§2.5, screen 22): the KYC status
// terminals lead with Lottie marks instead of flat glyphs.
//
//   pending  → kyc-review.json  (LOOPS — the review genuinely is ongoing)
//   approved → success-check.json (ONE-SHOT — the shared terminal mark)
//
// Reduce-motion must still render a frame: a looping mark freezes at frame 0, a
// one-shot settles at its last. Neither state is ever blank.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

import 'package:jeeb_mobile/features/kyc/application/kyc_poll_schedule.dart';
import 'package:jeeb_mobile/features/kyc/application/kyc_wizard_cubit.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_gateway.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_submission.dart';
import 'package:jeeb_mobile/features/kyc/presentation/kyc_status_view.dart';
import 'package:jeeb_mobile/features/kyc/presentation/widgets/kyc_status_marks.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';

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
  // Bounded pumps only: the pending mark loops, so nothing here may settle.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

LottieBuilder _lottieUnder(WidgetTester tester, Type markType) =>
    tester.widget<LottieBuilder>(
      find.descendant(
        of: find.byType(markType),
        matching: find.byType(LottieBuilder),
      ),
    );

void main() {
  testWidgets('pending leads with the looping review mark, not a glyph', (
    tester,
  ) async {
    final cubit = await _cubit(KycStatus.pending);
    addTearDown(cubit.close);
    await _pumpStatus(tester, cubit);

    expect(find.byType(KycReviewMark), findsOneWidget);
    expect(find.byIcon(Icons.hourglass_top_rounded), findsNothing);
    // The looping file is player-driven, never controller-driven.
    expect(_lottieUnder(tester, KycReviewMark).animate, isTrue);
    // The pending contract is untouched.
    expect(find.byKey(KycStatusView.pendingTitleKey), findsOneWidget);
    expect(find.byKey(KycStatusView.checkAgainCtaKey), findsOneWidget);
  });

  testWidgets('reduce-motion freezes the review mark on its first frame', (
    tester,
  ) async {
    final cubit = await _cubit(KycStatus.pending);
    addTearDown(cubit.close);
    await _pumpStatus(tester, cubit, disableAnimations: true);

    expect(find.byType(KycReviewMark), findsOneWidget);
    expect(_lottieUnder(tester, KycReviewMark).animate, isFalse);
  });

  testWidgets('approved leads with the one-shot success mark', (tester) async {
    final cubit = await _cubit(KycStatus.approved);
    addTearDown(cubit.close);
    await _pumpStatus(tester, cubit);

    expect(find.byType(KycApprovedMark), findsOneWidget);
    expect(find.byIcon(Icons.verified_rounded), findsNothing);
    // A controller is what makes it a one-shot rather than a loop.
    expect(_lottieUnder(tester, KycApprovedMark).controller, isNotNull);
    expect(find.byKey(KycStatusView.approvedTitleKey), findsOneWidget);
    expect(find.bySemanticsIdentifier('kyc_status_feed_cta'), findsOneWidget);
  });

  testWidgets('the two glyph-only terminals keep their icons', (tester) async {
    final rejected = await _cubit(KycStatus.rejected);
    addTearDown(rejected.close);
    await _pumpStatus(tester, rejected);

    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(find.byType(KycReviewMark), findsNothing);
    expect(find.byType(KycApprovedMark), findsNothing);
  });
}
