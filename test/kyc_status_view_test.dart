import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_footer.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_info_note.dart';
import 'package:jeeb_mobile/features/kyc/application/kyc_poll_schedule.dart';
import 'package:jeeb_mobile/features/kyc/application/kyc_wizard_cubit.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_gateway.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_submission.dart';
import 'package:jeeb_mobile/features/kyc/presentation/kyc_status_view.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';

import 'support/sync_app_localizations.dart';

const _oneProbeSchedule = KycPollSchedule(
  tiers: [
    KycPollTier(until: Duration(seconds: 1), interval: Duration(seconds: 1)),
  ],
  tailInterval: Duration(seconds: 1),
  maxElapsed: Duration(seconds: 1),
  maxScheduledProbes: 45,
  maxResumeProbes: 8,
);

class _StatusGateway extends FakeKycGateway {
  _StatusGateway(this.serverStatus)
    : super(initial: KycSubmission(status: serverStatus));

  KycStatus serverStatus;
  int statusCalls = 0;

  @override
  Future<KycSubmission> fetchStatus() async {
    statusCalls++;
    return KycSubmission(status: serverStatus);
  }
}

class _Harness {
  const _Harness({required this.gateway, required this.cubit});

  final _StatusGateway gateway;
  final KycWizardCubit cubit;

  static Future<_Harness> withStatus(KycStatus status) async {
    final gateway = _StatusGateway(status);
    final cubit = KycWizardCubit(
      pickerService: StubPhotoPickerService(),
      gateway: gateway,
    );
    if (status != KycStatus.notSubmitted) await cubit.loadStatus();
    gateway.statusCalls = 0;
    return _Harness(gateway: gateway, cubit: cubit);
  }

  Future<void> close() => cubit.close();
}

class _FlipCase {
  const _FlipCase({
    required this.probesBeforeFlip,
    required this.nextInterval,
    required this.terminalStatus,
  });

  final int probesBeforeFlip;
  final Duration nextInterval;
  final KycStatus terminalStatus;
}

Widget _host(
  _Harness harness, {
  Locale locale = const Locale('en'),
  KycPollSchedule schedule = KycPollSchedule.standard,
}) {
  return wrapForTest(
    BlocProvider<KycWizardCubit>.value(
      value: harness.cubit,
      child: Scaffold(
        body: SafeArea(child: KycStatusView(pollSchedule: schedule)),
      ),
    ),
    locale: locale,
  );
}

Finder _byIdentifier(String id) {
  return find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.identifier == id,
  );
}

List<Duration> _publishedIntervals() {
  return [
    for (var probe = 0; probe < 10; probe++) const Duration(seconds: 3),
    for (var probe = 0; probe < 18; probe++) const Duration(seconds: 15),
    for (var probe = 0; probe < 10; probe++) const Duration(minutes: 1),
  ];
}

Future<void> _pumpInterval(WidgetTester tester, Duration interval) async {
  await tester.pump(interval);
  await tester.pump();
}

Future<void> _pumpIntervals(
  WidgetTester tester,
  Iterable<Duration> intervals,
) async {
  for (final interval in intervals) {
    await _pumpInterval(tester, interval);
  }
}

Future<void> _disposeHarness(WidgetTester tester, _Harness harness) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await harness.close();
}

Future<void> _pumpToExpiry(WidgetTester tester) {
  return _pumpIntervals(tester, _publishedIntervals());
}

void main() {
  testWidgets(
    'FM5-F11-W1: the poll interval steps 3s to 15s to 60s and the request count follows the published schedule',
    (tester) async {
      final harness = await _Harness.withStatus(KycStatus.pending);
      await tester.pumpWidget(_host(harness));

      await _pumpInterval(tester, const Duration(milliseconds: 2999));
      expect(harness.gateway.statusCalls, 0);
      await _pumpInterval(tester, const Duration(milliseconds: 1));
      expect(harness.gateway.statusCalls, 1);
      await _pumpIntervals(tester, List.filled(9, const Duration(seconds: 3)));
      expect(harness.gateway.statusCalls, 10);
      await _pumpInterval(tester, const Duration(milliseconds: 14999));
      expect(harness.gateway.statusCalls, 10);
      await _pumpInterval(tester, const Duration(milliseconds: 1));
      expect(harness.gateway.statusCalls, 11);
      await _pumpIntervals(
        tester,
        List.filled(17, const Duration(seconds: 15)),
      );
      expect(harness.gateway.statusCalls, 28);
      await _pumpInterval(tester, const Duration(seconds: 59));
      expect(harness.gateway.statusCalls, 28);
      await _pumpInterval(tester, const Duration(seconds: 1));
      expect(harness.gateway.statusCalls, 29);
      await _pumpIntervals(tester, List.filled(9, const Duration(minutes: 1)));
      expect(harness.gateway.statusCalls, 38);

      await _disposeHarness(tester, harness);
    },
  );

  testWidgets(
    'FM5-F11-W2: the automatic poller stops at the 15-minute bound after exactly 38 requests',
    (tester) async {
      final harness = await _Harness.withStatus(KycStatus.pending);
      await tester.pumpWidget(_host(harness));

      await _pumpToExpiry(tester);
      expect(harness.gateway.statusCalls, 38);
      await _pumpInterval(tester, const Duration(hours: 1));
      expect(harness.gateway.statusCalls, 38);

      await _disposeHarness(tester, harness);
    },
  );

  testWidgets(
    'FM5-F11-W3: at expiry the OMDS re-check CTA is promoted and the expired state is machine-assertable',
    (tester) async {
      final harness = await _Harness.withStatus(KycStatus.pending);
      await tester.pumpWidget(_host(harness));
      await _pumpToExpiry(tester);

      expect(_byIdentifier('kyc_status_poll_expired'), findsOneWidget);
      expect(
        find.text(
          "We've stopped checking automatically. "
          'Tap Check again to look for a decision.',
        ),
        findsOneWidget,
      );
      // Promotion is now the kit variant, not a hand-passed fill: the primary
      // JeebCtaButton IS the navy pill + JeebShadows.ctaNavy.
      final cta = tester.widget<JeebCtaButton>(
        find.byKey(KycStatusView.checkAgainCtaKey),
      );
      expect(cta.variant, JeebCtaVariant.primary);
      expect(
        tester.getTopLeft(find.byKey(KycStatusView.checkAgainCtaKey)).dy,
        lessThan(tester.getTopLeft(_byIdentifier('kyc_status_topup_cta')).dy),
      );

      await _disposeHarness(tester, harness);
    },
  );

  testWidgets(
    'FM5-F11-W4: the re-check CTA is visible from the first frame before expiry',
    (tester) async {
      final harness = await _Harness.withStatus(KycStatus.pending);
      await tester.pumpWidget(_host(harness));

      expect(find.byKey(KycStatusView.checkAgainCtaKey), findsOneWidget);
      expect(find.text('Check again'), findsOneWidget);
      expect(_byIdentifier('kyc_status_poll_expired'), findsNothing);
      // Not promoted while the automatic poller is still running.
      expect(
        tester
            .widget<JeebCtaButton>(find.byKey(KycStatusView.checkAgainCtaKey))
            .variant,
        JeebCtaVariant.outline,
      );
      expect(
        tester.getTopLeft(_byIdentifier('kyc_status_topup_cta')).dy,
        lessThan(
          tester.getTopLeft(find.byKey(KycStatusView.checkAgainCtaKey)).dy,
        ),
      );

      await _disposeHarness(tester, harness);
    },
  );

  testWidgets(
    'FM5-F11-W5: tapping the re-check CTA issues exactly one request and never re-arms the automatic poller',
    (tester) async {
      final harness = await _Harness.withStatus(KycStatus.pending);
      await tester.pumpWidget(_host(harness, schedule: _oneProbeSchedule));
      await _pumpInterval(tester, const Duration(seconds: 1));
      expect(harness.gateway.statusCalls, 1);

      await tester.tap(find.byKey(KycStatusView.checkAgainCtaKey));
      await tester.pump();
      expect(harness.gateway.statusCalls, 2);
      await _pumpInterval(tester, const Duration(hours: 1));
      expect(harness.gateway.statusCalls, 2);

      await _disposeHarness(tester, harness);
    },
  );

  testWidgets(
    'FM5-F11-W6: an approval landing 5s after mount is surfaced at the 6s probe',
    (tester) async {
      final harness = await _Harness.withStatus(KycStatus.pending);
      await tester.pumpWidget(_host(harness));

      await _pumpInterval(tester, const Duration(seconds: 3));
      expect(harness.gateway.statusCalls, 1);
      await _pumpInterval(tester, const Duration(seconds: 2));
      harness.gateway.serverStatus = KycStatus.approved;
      await _pumpInterval(tester, const Duration(seconds: 1));
      expect(harness.gateway.statusCalls, 2);
      expect(find.byKey(KycStatusView.approvedTitleKey), findsOneWidget);

      await _disposeHarness(tester, harness);
    },
  );

  testWidgets(
    'FM5-F11-W7: a flip to approved is observed within one tier interval and cancels the poller',
    (tester) async {
      const cases = [
        _FlipCase(
          probesBeforeFlip: 1,
          nextInterval: Duration(seconds: 3),
          terminalStatus: KycStatus.approved,
        ),
        _FlipCase(
          probesBeforeFlip: 10,
          nextInterval: Duration(seconds: 15),
          terminalStatus: KycStatus.approved,
        ),
        _FlipCase(
          probesBeforeFlip: 28,
          nextInterval: Duration(minutes: 1),
          terminalStatus: KycStatus.approved,
        ),
        _FlipCase(
          probesBeforeFlip: 1,
          nextInterval: Duration(seconds: 3),
          terminalStatus: KycStatus.rejected,
        ),
      ];
      final intervals = _publishedIntervals();
      for (final testCase in cases) {
        final harness = await _Harness.withStatus(KycStatus.pending);
        await tester.pumpWidget(_host(harness));
        await _pumpIntervals(tester, intervals.take(testCase.probesBeforeFlip));
        expect(harness.gateway.statusCalls, testCase.probesBeforeFlip);
        harness.gateway.serverStatus = testCase.terminalStatus;
        await _pumpInterval(tester, testCase.nextInterval);
        final terminalCount = harness.gateway.statusCalls;
        expect(terminalCount, testCase.probesBeforeFlip + 1);
        final terminalTitle = testCase.terminalStatus == KycStatus.approved
            ? KycStatusView.approvedTitleKey
            : KycStatusView.rejectedTitleKey;
        expect(find.byKey(terminalTitle), findsOneWidget);
        await _pumpInterval(tester, const Duration(hours: 1));
        expect(harness.gateway.statusCalls, terminalCount);
        await _disposeHarness(tester, harness);
      }
    },
  );

  testWidgets(
    'FM5-F11-W8: dispose cancels everything and no timer outlives the widget',
    (tester) async {
      final harness = await _Harness.withStatus(KycStatus.pending);
      await tester.pumpWidget(_host(harness));
      await _pumpInterval(tester, const Duration(seconds: 3));
      expect(harness.gateway.statusCalls, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpInterval(tester, const Duration(hours: 1));
      expect(harness.gateway.statusCalls, 1);
      await harness.close();
    },
  );

  testWidgets(
    'FM5-F11-W9: backgrounding pauses the poller and an inactive transient does not',
    (tester) async {
      final harness = await _Harness.withStatus(KycStatus.pending);
      await tester.pumpWidget(_host(harness));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await _pumpInterval(tester, const Duration(seconds: 3));
      expect(harness.gateway.statusCalls, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await _pumpInterval(tester, const Duration(minutes: 5));
      expect(harness.gateway.statusCalls, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(harness.gateway.statusCalls, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(harness.gateway.statusCalls, 2);

      await _disposeHarness(tester, harness);
    },
  );

  testWidgets(
    'FM5-F11-W10: a view that mounts already approved issues zero status requests',
    (tester) async {
      final harness = await _Harness.withStatus(KycStatus.approved);
      await tester.pumpWidget(_host(harness));

      expect(find.byKey(KycStatusView.approvedTitleKey), findsOneWidget);
      await _pumpInterval(tester, const Duration(minutes: 1));
      expect(harness.gateway.statusCalls, 0);

      await _disposeHarness(tester, harness);
    },
  );

  testWidgets(
    'FM5-F11-W11: notSubmitted still counts as pending and is polled',
    (tester) async {
      final harness = await _Harness.withStatus(KycStatus.notSubmitted);
      await tester.pumpWidget(_host(harness));

      await _pumpInterval(tester, const Duration(milliseconds: 2999));
      expect(harness.gateway.statusCalls, 0);
      await _pumpInterval(tester, const Duration(milliseconds: 1));
      expect(harness.gateway.statusCalls, 1);

      await _disposeHarness(tester, harness);
    },
  );

  // redesign-2026-08 (screen 22's companion): the re-skin is composed from the
  // Jeeb kit, not from bespoke containers — a docked CTA footer of kit buttons
  // over a kit info note. Locks the swap so a later edit cannot quietly
  // reintroduce a hand-rolled grey panel or an OMDS pill here.
  testWidgets(
    'redesign-2026-08: the pending body is a JeebCtaFooter of JeebCtaButtons '
    'over a JeebInfoNote',
    (tester) async {
      final harness = await _Harness.withStatus(KycStatus.pending);
      await tester.pumpWidget(_host(harness, schedule: _oneProbeSchedule));

      expect(find.byType(JeebCtaFooter), findsOneWidget);
      // Top up · Check again · Back to profile.
      expect(find.byType(JeebCtaButton), findsNWidgets(3));
      expect(
        find.descendant(
          of: _byIdentifier('kyc_status_topup_allowed_note'),
          matching: find.byType(JeebInfoNote),
        ),
        findsOneWidget,
      );

      await _disposeHarness(tester, harness);
    },
  );

  testWidgets(
    'FM5-F11-W12: the pending body and re-check CTA render in Arabic RTL',
    (tester) async {
      final harness = await _Harness.withStatus(KycStatus.pending);
      await tester.pumpWidget(_host(harness, locale: const Locale('ar')));

      expect(find.text('تحقق مرة أخرى'), findsOneWidget);
      final titleContext = tester.element(
        find.byKey(KycStatusView.pendingTitleKey),
      );
      expect(Directionality.of(titleContext), TextDirection.rtl);

      await _disposeHarness(tester, harness);
    },
  );
}
