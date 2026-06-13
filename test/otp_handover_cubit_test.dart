import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/features/otp_handover/application/otp_handover_cubit.dart';
import 'package:jeeb_mobile/features/otp_handover/application/otp_handover_state.dart';
import 'package:jeeb_mobile/features/otp_handover/domain/otp_handover_repository.dart';
import 'package:jeeb_mobile/features/otp_handover/domain/otp_handover_result.dart';

class _MockRepo extends Mock implements OtpHandoverRepository {}

void main() {
  late _MockRepo repo;

  setUp(() => repo = _MockRepo());

  OtpHandoverCubit _clientCubit() => OtpHandoverCubit(
        repository: repo,
        deliveryId: 'DLV-770001',
        isClient: true,
      );

  OtpHandoverCubit _jeeberCubit() => OtpHandoverCubit(
        repository: repo,
        deliveryId: 'DLV-770001',
        isClient: false,
      );

  group('Client view', () {
    test('fetches and exposes the handover code', () async {
      when(() => repo.fetchHandoverCode(deliveryId: any(named: 'deliveryId')))
          .thenAnswer((_) async => '1234');

      final cubit = _clientCubit();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.mode, OtpHandoverViewMode.ready);
      expect(cubit.state.handoverCode, '1234');
      await cubit.close();
    });

    test('emits error when fetch fails', () async {
      when(() => repo.fetchHandoverCode(deliveryId: any(named: 'deliveryId')))
          .thenThrow(const OtpHandoverException(OtpHandoverErrorKind.network));

      final cubit = _clientCubit();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.mode, OtpHandoverViewMode.error);
      await cubit.close();
    });
  });

  group('Jeeber view', () {
    test('starts in ready state without fetching a code', () {
      when(() => repo.fetchHandoverCode(deliveryId: any(named: 'deliveryId')))
          .thenAnswer((_) async => '9999'); // should never be called
      final cubit = _jeeberCubit();
      expect(cubit.state.mode, OtpHandoverViewMode.ready);
      verifyNever(
        () => repo.fetchHandoverCode(deliveryId: any(named: 'deliveryId')),
      );
      cubit.close();
    });

    test('AC2: emits success on correct OTP', () async {
      when(() => repo.submitOtp(
            deliveryId: any(named: 'deliveryId'),
            otp: any(named: 'otp'),
          )).thenAnswer(
        (_) async => const OtpHandoverResult(success: true),
      );

      final cubit = _jeeberCubit();
      await cubit.submitOtp('1234');

      expect(cubit.state.mode, OtpHandoverViewMode.success);
      await cubit.close();
    });

    test('AC3: increments wrongAttempts and shakeKey on invalid OTP', () async {
      when(() => repo.submitOtp(
            deliveryId: any(named: 'deliveryId'),
            otp: any(named: 'otp'),
          )).thenThrow(
        const OtpHandoverException(OtpHandoverErrorKind.invalidOtp),
      );

      final cubit = _jeeberCubit();
      await cubit.submitOtp('0000');

      expect(cubit.state.wrongAttempts, 1);
      expect(cubit.state.shakeKey, 1);
      expect(cubit.state.escalate, isFalse);
      await cubit.close();
    });

    test('AC4: sets escalate=true after 3 wrong codes', () async {
      when(() => repo.submitOtp(
            deliveryId: any(named: 'deliveryId'),
            otp: any(named: 'otp'),
          )).thenThrow(
        const OtpHandoverException(OtpHandoverErrorKind.invalidOtp),
      );

      final cubit = _jeeberCubit();
      await cubit.submitOtp('0000');
      await cubit.submitOtp('0000');
      await cubit.submitOtp('0000');

      expect(cubit.state.wrongAttempts, OtpHandoverState.maxAttempts);
      expect(cubit.state.escalate, isTrue);
      await cubit.close();
    });

    test('AC4: 423 locked response immediately sets escalate=true', () async {
      when(() => repo.submitOtp(
            deliveryId: any(named: 'deliveryId'),
            otp: any(named: 'otp'),
          )).thenThrow(
        const OtpHandoverException(OtpHandoverErrorKind.locked),
      );

      final cubit = _jeeberCubit();
      await cubit.submitOtp('1234');

      expect(cubit.state.escalate, isTrue);
      await cubit.close();
    });

    test('dismissEscalate clears escalate flag', () async {
      when(() => repo.submitOtp(
            deliveryId: any(named: 'deliveryId'),
            otp: any(named: 'otp'),
          )).thenThrow(
        const OtpHandoverException(OtpHandoverErrorKind.locked),
      );

      final cubit = _jeeberCubit();
      await cubit.submitOtp('1234');
      expect(cubit.state.escalate, isTrue);

      cubit.dismissEscalate();
      expect(cubit.state.escalate, isFalse);
      await cubit.close();
    });
  });
}
