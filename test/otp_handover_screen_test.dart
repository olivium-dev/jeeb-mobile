import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/core/formatting/money_format.dart';
import 'package:jeeb_mobile/features/delivery_status/domain/jeeber_summary.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/live_tracking_repository.dart';
import 'package:jeeb_mobile/features/otp_handover/application/otp_handover_cubit.dart';
import 'package:jeeb_mobile/features/otp_handover/application/otp_handover_state.dart';
import 'package:jeeb_mobile/features/otp_handover/domain/otp_handover_repository.dart';
import 'package:jeeb_mobile/features/otp_handover/domain/otp_handover_result.dart';
import 'package:jeeb_mobile/features/otp_handover/presentation/otp_handover_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'support/midnight_test_harness.dart';
import 'support/sync_app_localizations.dart';

class _MockRepo extends Mock implements OtpHandoverRepository {}

/// Best-effort arrival source for the redesign-2026-08 banner. Returns a fixed
/// snapshot, or throws when [failure] is set (the banner must then simply not
/// render — it may never fault the code display).
class _StubTracking implements LiveTrackingRepository {
  _StubTracking({this.info, this.failure});

  final DeliveryTrackingInfo? info;
  final Object? failure;

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async {
    final boom = failure;
    if (boom != null) throw boom;
    return info!;
  }
}

DeliveryTrackingInfo _tracking({
  TrackingStage stage = TrackingStage.atDoor,
  String name = 'Karim',
  String vehicle = 'Scooter',
  double? price = 8,
  String? currency = 'USD',
}) {
  return DeliveryTrackingInfo(
    deliveryId: 'DLV-770001',
    currentStage: stage,
    stageTimestamps: const {},
    jeeber: JeeberSummary(displayName: name, vehicleLabel: vehicle),
    price: price,
    currency: currency,
  );
}

Widget _screen(
  OtpHandoverCubit cubit, {
  required bool isClient,
  Locale locale = const Locale('en'),
}) {
  return wrapForTest(
    BlocProvider<OtpHandoverCubit>.value(
      value: cubit,
      child: OtpHandoverScreen(
        deliveryId: 'DLV-770001',
        isClient: isClient,
      ),
    ),
    locale: locale,
  );
}

/// The live [AppLocalizations] the pumped screen is rendering with, so copy
/// assertions read the ARB instead of a literal — the redesign batch re-values
/// three of these keys in place and the assertions must survive it.
AppLocalizations _l10nOf(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(OtpHandoverScreen)));

void main() {
  late _MockRepo repo;

  setUp(() => repo = _MockRepo());

  group('Client view', () {
    testWidgets('AC1: renders the OTP code as one tile per digit when ready',
        (tester) async {
      when(() =>
              repo.fetchHandoverCode(deliveryId: any(named: 'deliveryId')))
          .thenAnswer((_) async => const OtpFetchResult(code: '1234'));

      final cubit = OtpHandoverCubit(
        repository: repo,
        deliveryId: 'DLV-770001',
        isClient: true,
      );

      await tester.pumpWidget(_screen(cubit, isClient: true));
      // Let the cubit's constructor-triggered fetch resolve. A bare
      await tester.pump();

      // redesign-2026-08 screen 13: the code is four navy tiles, so the digits
      // are four separate `Text`s rather than the old single `'1234'` string.
      expect(find.byKey(const Key('otpHandover.codeDisplay')), findsOneWidget);
      for (final digit in const ['1', '2', '3', '4']) {
        expect(find.text(digit), findsOneWidget,
            reason: 'each digit gets its own tile');
      }
      await cubit.close();
    });

    testWidgets('shows share instruction and do-not-share reminder',
        (tester) async {
      when(() =>
              repo.fetchHandoverCode(deliveryId: any(named: 'deliveryId')))
          .thenAnswer((_) async => const OtpFetchResult(code: '5678'));

      final cubit = OtpHandoverCubit(
        repository: repo,
        deliveryId: 'DLV-770001',
        isClient: true,
      );

      await tester.pumpWidget(_screen(cubit, isClient: true));
      // Pump a frame so the constructor-triggered fetch resolves (see AC1).
      await tester.pump();

      // Asserted through the getters, not literals: the redesign l10n batch
      // re-values both keys in place and the intent ("the instruction and the
      // safety reminder are on screen") is what this test owns.
      final l10n = _l10nOf(tester);
      expect(find.text(l10n.otpClientShareInstruction), findsOneWidget);
      expect(find.text(l10n.otpClientDoNotShare), findsOneWidget);
      await cubit.close();
    });

    // G4 (sprint-009 P0): the live gateway's GET /otp is an SMS trigger with
    testWidgets(
        'G4 fallback: no code → SMS-sent message + resend, NO entry grid',
        (tester) async {
      when(() =>
              repo.fetchHandoverCode(deliveryId: any(named: 'deliveryId')))
          .thenAnswer((_) async => const OtpFetchResult(smsTriggered: true));

      final cubit = OtpHandoverCubit(
        repository: repo,
        deliveryId: 'DLV-770001',
        isClient: true,
      );

      await tester.pumpWidget(_screen(cubit, isClient: true));
      await tester.pump();

      expect(find.text("We've sent your code by SMS"), findsOneWidget);
      expect(find.byKey(const Key('otpHandover.resendSms')), findsOneWidget);
      // The customer-side surface must not offer code ENTRY.
      expect(find.byKey(const Key('otpHandover.input')), findsNothing);
      expect(find.byKey(const Key('otpHandover.submit')), findsNothing);
      await cubit.close();
    });

    testWidgets('G4 fallback: resend CTA re-triggers the SMS endpoint',
        (tester) async {
      when(() =>
              repo.fetchHandoverCode(deliveryId: any(named: 'deliveryId')))
          .thenAnswer((_) async => const OtpFetchResult(smsTriggered: true));

      final cubit = OtpHandoverCubit(
        repository: repo,
        deliveryId: 'DLV-770001',
        isClient: true,
      );

      await tester.pumpWidget(_screen(cubit, isClient: true));
      await tester.pump();

      await tester.tap(find.byKey(const Key('otpHandover.resendSms')));
      await tester.pump();
      await tester.pump();

      verify(
        () => repo.fetchHandoverCode(deliveryId: any(named: 'deliveryId')),
      ).called(2);
      await cubit.close();
    });
  });

  // redesign-2026-08 screen 13 (`tpl 799-804`): the orange arrival banner. It
  // is garnish over the code — every one of these asserts that it either says
  // something true or is not there at all.
  group('Client arrival banner', () {
    setUp(() {
      when(() =>
              repo.fetchHandoverCode(deliveryId: any(named: 'deliveryId')))
          .thenAnswer((_) async => const OtpFetchResult(code: '1234'));
    });

    OtpHandoverCubit client({LiveTrackingRepository? tracking}) =>
        OtpHandoverCubit(
          repository: repo,
          deliveryId: 'DLV-770001',
          isClient: true,
          deliveryInfo: tracking,
        );

    testWidgets('absent when no arrival was loaded', (tester) async {
      final cubit = client();

      await tester.pumpWidget(_screen(cubit, isClient: true));
      await tester.pump();

      expect(find.bySemanticsIdentifier('otp_handover_arrival'), findsNothing);
      expect(find.byKey(const Key('otpHandover.codeDisplay')), findsOneWidget);
      await cubit.close();
    });

    testWidgets('renders name, vehicle and the formatted cash due',
        (tester) async {
      final cubit = client(tracking: _StubTracking(info: _tracking()));

      await tester.pumpWidget(_screen(cubit, isClient: true));
      await tester.pump(); // code
      await tester.pump(); // arrival

      expect(
        find.bySemanticsIdentifier('otp_handover_arrival'),
        findsOneWidget,
      );
      expect(find.text('Karim is at your door'), findsOneWidget);
      expect(
        find.text('Scooter · ${MoneyFormat.format(8)} cash ready'),
        findsOneWidget,
        reason: 'money goes through the one app-wide formatter, LTR-isolated',
      );
      await cubit.close();
    });

    testWidgets('drops the cash clause entirely when the delivery has no price',
        (tester) async {
      final cubit = client(
        tracking: _StubTracking(
          info: _tracking(
            stage: TrackingStage.inTransit,
            price: null,
            currency: null,
          ),
        ),
      );

      await tester.pumpWidget(_screen(cubit, isClient: true));
      await tester.pump();
      await tester.pump();

      expect(find.text('Karim is on the way'), findsOneWidget);
      // Vehicle label alone — the banner never invents an amount.
      expect(find.text('Scooter'), findsOneWidget);
      expect(find.textContaining('cash ready'), findsNothing);
      await cubit.close();
    });

    testWidgets('is suppressed once the delivery is already delivered',
        (tester) async {
      final cubit = client(
        tracking: _StubTracking(
          info: _tracking(stage: TrackingStage.delivered),
        ),
      );

      await tester.pumpWidget(_screen(cubit, isClient: true));
      await tester.pump();
      await tester.pump();

      expect(
        find.bySemanticsIdentifier('otp_handover_arrival'),
        findsNothing,
        reason: 'post-handover both "at your door" and "on the way" are lies',
      );
      await cubit.close();
    });

    // R1 density: the board's lower ~40 % is genuinely empty, which only works
    // if the page can SCROLL once the text scale eats that slack. A bare
    // Column + Spacer asserts here.
    testWidgets('survives 200 % text scale by scrolling, not overflowing',
        (tester) async {
      final cubit = client(tracking: _StubTracking(info: _tracking()));

      await tester.pumpWidget(
        wrapForTest(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: BlocProvider<OtpHandoverCubit>.value(
              value: cubit,
              child: const OtpHandoverScreen(
                deliveryId: 'DLV-770001',
                isClient: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      await cubit.close();
    });

    testWidgets('a failed arrival read still leaves the code on screen',
        (tester) async {
      final cubit = client(
        tracking: _StubTracking(failure: StateError('tracking down')),
      );

      await tester.pumpWidget(_screen(cubit, isClient: true));
      await tester.pump();
      await tester.pump();

      expect(find.bySemanticsIdentifier('otp_handover_arrival'), findsNothing);
      expect(find.byKey(const Key('otpHandover.codeDisplay')), findsOneWidget);
      expect(cubit.state.mode, OtpHandoverViewMode.ready,
          reason: 'the banner is garnish; it may never fault the screen');
      await cubit.close();
    });
  });

  group('Jeeber view', () {
    testWidgets('AC1: OTP input and verify button are rendered', (tester) async {
      final cubit = OtpHandoverCubit(
        repository: repo,
        deliveryId: 'DLV-770001',
        isClient: false,
      );

      await tester.pumpWidget(_screen(cubit, isClient: false));
      await tester.pump();

      expect(find.text('Verify OTP'), findsOneWidget);
      expect(find.text('Enter the OTP from the Client'), findsOneWidget);
      await cubit.close();
    });

    testWidgets('AC2: done screen shown after successful verify', (tester) async {
      when(() => repo.submitOtp(
            deliveryId: any(named: 'deliveryId'),
            otp: any(named: 'otp'),
          )).thenAnswer((_) async => const OtpHandoverResult(success: true));

      final cubit = OtpHandoverCubit(
        repository: repo,
        deliveryId: 'DLV-770001',
        isClient: false,
      );

      await tester.pumpWidget(_screen(cubit, isClient: false));
      await tester.pump();

      await cubit.submitOtp('1234');
      await tester.pump();

      expect(find.text('Delivery Complete!'), findsOneWidget);
      expect(find.text('Rate your Jeeber'), findsOneWidget);
      await cubit.close();
    });

    testWidgets('AC3: wrong code shows inline error + attempts hint',
        (tester) async {
      when(() => repo.submitOtp(
            deliveryId: any(named: 'deliveryId'),
            otp: any(named: 'otp'),
          )).thenThrow(
        const OtpHandoverException(OtpHandoverErrorKind.invalidOtp),
      );

      final cubit = OtpHandoverCubit(
        repository: repo,
        deliveryId: 'DLV-770001',
        isClient: false,
      );

      await tester.pumpWidget(_screen(cubit, isClient: false));
      await tester.pump();

      await cubit.submitOtp('0000');
      await tester.pump();

      // The inline line is the SHARED invalid-code copy now, not a per-screen
      // literal, and the counter is the six-sibling plural set.
      final l10n = _l10nOf(tester);
      expect(find.text(l10n.errorInvalidCode), findsOneWidget);
      // 1 attempt used → 2 remaining
      expect(find.text(l10n.otpHandoverAttemptsRemaining(2)), findsOneWidget);
      await cubit.close();
    });
  });

  group('Arabic locale', () {
    testWidgets('Jeeber verify button renders in Arabic', (tester) async {
      final cubit = OtpHandoverCubit(
        repository: repo,
        deliveryId: 'DLV-770001',
        isClient: false,
      );

      await tester.pumpWidget(
        wrapForTest(
          BlocProvider<OtpHandoverCubit>.value(
            value: cubit,
            child: const OtpHandoverScreen(
              deliveryId: 'DLV-770001',
              isClient: false,
            ),
          ),
          locale: const Locale('ar'),
        ),
      );
      await tester.pump();

      expect(find.text('التحقق'), findsOneWidget);
      await cubit.close();
    });

    // The single most important RTL property on this screen: a 4-digit door
    // code must NOT reorder inside an Arabic ancestor. `JeebCodeCells` pins the
    // tile row to an LTR isolate, so the first tile carries the first digit.
    testWidgets('code tiles keep issue order in Arabic (LTR isolate)',
        (tester) async {
      when(() =>
              repo.fetchHandoverCode(deliveryId: any(named: 'deliveryId')))
          .thenAnswer((_) async => const OtpFetchResult(code: '2144'));

      final cubit = OtpHandoverCubit(
        repository: repo,
        deliveryId: 'DLV-770001',
        isClient: true,
        deliveryInfo: _StubTracking(info: _tracking()),
      );

      await tester.pumpWidget(
        wrapForTest(
          BlocProvider<OtpHandoverCubit>.value(
            value: cubit,
            child: const OtpHandoverScreen(
              deliveryId: 'DLV-770001',
              isClient: true,
            ),
          ),
          locale: const Locale('ar'),
        ),
      );
      await tester.pump();
      await tester.pump();

      final tiles = tester.widgetList<Text>(find.byType(Text)).where(
            (t) => t.data != null && RegExp(r'^\d$').hasMatch(t.data!),
          );
      expect(tiles.map((t) => t.data).join(), '2144',
          reason: 'digits must never mirror — a reordered code opens no door');

      // The banner row mirrors: its avatar sits on the RIGHT under RTL.
      final banner = find.bySemanticsIdentifier('otp_handover_arrival');
      expect(banner, findsOneWidget);
      final avatarBox = tester.getRect(
        find.descendant(of: banner, matching: find.text('K')),
      );
      final headlineBox = tester.getRect(
        find.descendant(
          of: banner,
          matching: find.textContaining('Karim'),
        ),
      );
      expect(avatarBox.center.dx, greaterThan(headlineBox.center.dx),
          reason: 'EdgeInsetsDirectional + Row must mirror the whole banner');
      await cubit.close();
    });
  });

  // TEST-04 — the three rungs are findable by identifier, in both locales, and
  // no assertion depends on the retired `'network'` / `'invalid_otp'` tokens.
  group('rungs · identifier triple', () {
    for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('loading is findable ($locale)', (tester) async {
        final cubit = OtpHandoverCubit(
          repository: _StalledRepo(),
          deliveryId: 'DLV-770001',
          isClient: true,
        );
        await tester.pumpWidget(
          _screen(cubit, isClient: true, locale: locale),
        );
        await tester.pump();

        expect(
          find.bySemanticsIdentifier('otp_handover_loading'),
          findsOneWidget,
        );
        await cubit.close();
      });

      testWidgets('error carries an identified retry ($locale)',
          (tester) async {
        final cubit = OtpHandoverCubit(
          repository: _FailingRepo(),
          deliveryId: 'DLV-770001',
          isClient: true,
        );
        useReduceMotion(tester);
        await tester.pumpWidget(
          _screen(cubit, isClient: true, locale: locale),
        );
        // The error illustration breathes, so this pumps bounded frames.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(cubit.state.mode, OtpHandoverViewMode.error);
        expect(cubit.state.errorKind, OtpHandoverErrorKind.network);
        expect(
          find.bySemanticsIdentifier('otp_handover_error'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('otp_handover_retry_cta'),
          findsOneWidget,
        );
        await cubit.close();
      });
    }
  });
}

/// Never answers: holds the cold rung open.
class _StalledRepo implements OtpHandoverRepository {
  @override
  Future<OtpFetchResult> fetchHandoverCode({required String deliveryId}) =>
      Completer<OtpFetchResult>().future;

  @override
  Future<OtpHandoverResult> submitOtp({
    required String deliveryId,
    required String otp,
  }) => Completer<OtpHandoverResult>().future;
}

/// A transport failure on the cold read.
class _FailingRepo implements OtpHandoverRepository {
  @override
  Future<OtpFetchResult> fetchHandoverCode({required String deliveryId}) async =>
      throw const OtpHandoverException(OtpHandoverErrorKind.network);

  @override
  Future<OtpHandoverResult> submitOtp({
    required String deliveryId,
    required String otp,
  }) async => throw const OtpHandoverException(OtpHandoverErrorKind.network);
}
