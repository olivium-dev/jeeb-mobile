import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/features/otp_handover/application/otp_handover_cubit.dart';
import 'package:jeeb_mobile/features/otp_handover/domain/otp_handover_repository.dart';
import 'package:jeeb_mobile/features/otp_handover/domain/otp_handover_result.dart';
import 'package:jeeb_mobile/features/otp_handover/presentation/otp_handover_screen.dart';

import 'support/sync_app_localizations.dart';

class _MockRepo extends Mock implements OtpHandoverRepository {}

Widget _screen(OtpHandoverCubit cubit, {required bool isClient}) {
  return wrapForTest(
    BlocProvider<OtpHandoverCubit>.value(
      value: cubit,
      child: OtpHandoverScreen(
        deliveryId: 'DLV-770001',
        isClient: isClient,
      ),
    ),
  );
}

void main() {
  late _MockRepo repo;

  setUp(() => repo = _MockRepo());

  group('Client view', () {
    testWidgets('AC1: renders large OTP code when ready', (tester) async {
      when(() =>
              repo.fetchHandoverCode(deliveryId: any(named: 'deliveryId')))
          .thenAnswer((_) async => '1234');

      final cubit = OtpHandoverCubit(
        repository: repo,
        deliveryId: 'DLV-770001',
        isClient: true,
      );

      await tester.pumpWidget(_screen(cubit, isClient: true));
      // Let the cubit's constructor-triggered fetch resolve. A bare
      // `Future.delayed(Duration.zero)` never fires under the widget-test
      // fake clock until a frame is pumped, so we pump instead.
      await tester.pump();

      expect(find.text('1234'), findsOneWidget);
      await cubit.close();
    });

    testWidgets('shows share instruction and do-not-share reminder',
        (tester) async {
      when(() =>
              repo.fetchHandoverCode(deliveryId: any(named: 'deliveryId')))
          .thenAnswer((_) async => '5678');

      final cubit = OtpHandoverCubit(
        repository: repo,
        deliveryId: 'DLV-770001',
        isClient: true,
      );

      await tester.pumpWidget(_screen(cubit, isClient: true));
      // Pump a frame so the constructor-triggered fetch resolves (see AC1).
      await tester.pump();

      expect(find.text('Share this code with your Jeeber'), findsOneWidget);
      expect(
        find.text('Do not share until you receive your items'),
        findsOneWidget,
      );
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

      expect(
        find.text('Incorrect code — please try again'),
        findsOneWidget,
      );
      // 1 attempt used → 2 remaining
      expect(find.textContaining('2 attempt'), findsOneWidget);
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
  });
}
