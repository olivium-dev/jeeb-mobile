import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/features/otp_handover/application/otp_handover_cubit.dart';
import 'package:jeeb_mobile/features/otp_handover/application/otp_handover_state.dart';
import 'package:jeeb_mobile/features/otp_handover/domain/handover_code_store.dart';
import 'package:jeeb_mobile/features/otp_handover/domain/otp_handover_repository.dart';
import 'package:jeeb_mobile/features/otp_handover/domain/otp_handover_result.dart';

class _MockRepo extends Mock implements OtpHandoverRepository {}

/// In-memory [HandoverCodeStore] — deterministic, no prefs plumbing.
class _MemoryStore implements HandoverCodeStore {
  final Map<String, String> rows = {};

  @override
  Future<void> save({required String deliveryId, required String code}) async {
    rows[deliveryId] = code;
  }

  @override
  Future<String?> read({required String deliveryId}) async => rows[deliveryId];

  @override
  Future<void> clear({required String deliveryId}) async {
    rows.remove(deliveryId);
  }
}

void main() {
  late _MockRepo repo;
  late _MemoryStore store;

  setUp(() {
    repo = _MockRepo();
    store = _MemoryStore();
  });

  OtpHandoverCubit clientCubit({HandoverCodeStore? codeStore}) =>
      OtpHandoverCubit(
        repository: repo,
        deliveryId: 'DLV-770001',
        isClient: true,
        codeStore: codeStore,
      );

  OtpHandoverCubit jeeberCubit() => OtpHandoverCubit(
        repository: repo,
        deliveryId: 'DLV-770001',
        isClient: false,
        codeStore: store,
      );

  group('Client view — code sourcing (G4)', () {
    test('gateway-returned code is exposed AND persisted locally', () async {
      when(() => repo.fetchHandoverCode(deliveryId: any(named: 'deliveryId')))
          .thenAnswer((_) async => const OtpFetchResult(code: '1234'));

      final cubit = clientCubit(codeStore: store);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.mode, OtpHandoverViewMode.ready);
      expect(cubit.state.handoverCode, '1234');
      expect(store.rows['DLV-770001'], '1234',
          reason: 'a gateway-returned code must be persisted for restarts');
      await cubit.close();
    });

    test(
        'G4 restart resilience: a LOCALLY persisted code renders WITHOUT any '
        'network call (no SMS side effect)', () async {
      store.rows['DLV-770001'] = '4321';

      final cubit = clientCubit(codeStore: store);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.mode, OtpHandoverViewMode.ready);
      expect(cubit.state.handoverCode, '4321');
      verifyNever(
        () => repo.fetchHandoverCode(deliveryId: any(named: 'deliveryId')),
      );
      await cubit.close();
    });

    test('emits error when fetch fails (network)', () async {
      when(() => repo.fetchHandoverCode(deliveryId: any(named: 'deliveryId')))
          .thenThrow(const OtpHandoverException(OtpHandoverErrorKind.network));

      final cubit = clientCubit(codeStore: store);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.mode, OtpHandoverViewMode.error);
      await cubit.close();
    });

    // G4 fallback: the LIVE gateway GET /otp is an SMS trigger — it returns
    test('live SMS-trigger shape → ready + smsSent, no code, no error',
        () async {
      when(() => repo.fetchHandoverCode(deliveryId: any(named: 'deliveryId')))
          .thenAnswer((_) async => const OtpFetchResult(smsTriggered: true));

      final cubit = clientCubit(codeStore: store);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.mode, OtpHandoverViewMode.ready);
      expect(cubit.state.smsSent, isTrue);
      expect(cubit.state.handoverCode, isNull);
      expect(cubit.state.errorMessage, isNull);
      await cubit.close();
    });

    test('resendSms re-hits the trigger endpoint and stays on smsSent',
        () async {
      when(() => repo.fetchHandoverCode(deliveryId: any(named: 'deliveryId')))
          .thenAnswer((_) async => const OtpFetchResult(smsTriggered: true));

      final cubit = clientCubit(codeStore: store);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.smsSent, isTrue);

      await cubit.resendSms();

      expect(cubit.state.mode, OtpHandoverViewMode.ready);
      expect(cubit.state.smsSent, isTrue);
      verify(
        () => repo.fetchHandoverCode(deliveryId: any(named: 'deliveryId')),
      ).called(2);
      await cubit.close();
    });

    test('parse miss (no code, no triggered flag) → honest error + retry',
        () async {
      when(() => repo.fetchHandoverCode(deliveryId: any(named: 'deliveryId')))
          .thenThrow(const OtpHandoverException(OtpHandoverErrorKind.parse));

      final cubit = clientCubit(codeStore: store);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.mode, OtpHandoverViewMode.error);
      expect(cubit.state.smsSent, isFalse);
      await cubit.close();
    });

    test('a broken store read falls through to the gateway path', () async {
      when(() => repo.fetchHandoverCode(deliveryId: any(named: 'deliveryId')))
          .thenAnswer((_) async => const OtpFetchResult(smsTriggered: true));

      final cubit = OtpHandoverCubit(
        repository: repo,
        deliveryId: 'DLV-770001',
        isClient: true,
        codeStore: _ThrowingStore(),
      );
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.mode, OtpHandoverViewMode.ready);
      expect(cubit.state.smsSent, isTrue);
      await cubit.close();
    });
  });

  group('Jeeber view', () {
    test('starts in ready state without fetching a code', () {
      when(() => repo.fetchHandoverCode(deliveryId: any(named: 'deliveryId')))
          .thenAnswer(
        (_) async => const OtpFetchResult(code: '9999'),
      ); // should never be called
      final cubit = jeeberCubit();
      expect(cubit.state.mode, OtpHandoverViewMode.ready);
      verifyNever(
        () => repo.fetchHandoverCode(deliveryId: any(named: 'deliveryId')),
      );
      cubit.close();
    });

    test('AC2: emits success on correct OTP and clears the stored code',
        () async {
      store.rows['DLV-770001'] = '1234';
      when(() => repo.submitOtp(
            deliveryId: any(named: 'deliveryId'),
            otp: any(named: 'otp'),
          )).thenAnswer(
        (_) async => const OtpHandoverResult(success: true),
      );

      final cubit = jeeberCubit();
      await cubit.submitOtp('1234');

      expect(cubit.state.mode, OtpHandoverViewMode.success);
      // Single-use code — the persisted copy is dropped after handover.
      await Future<void>.delayed(Duration.zero);
      expect(store.rows.containsKey('DLV-770001'), isFalse);
      await cubit.close();
    });

    test('AC3: increments wrongAttempts and shakeKey on invalid OTP', () async {
      when(() => repo.submitOtp(
            deliveryId: any(named: 'deliveryId'),
            otp: any(named: 'otp'),
          )).thenThrow(
        const OtpHandoverException(OtpHandoverErrorKind.invalidOtp),
      );

      final cubit = jeeberCubit();
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

      final cubit = jeeberCubit();
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

      final cubit = jeeberCubit();
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

      final cubit = jeeberCubit();
      await cubit.submitOtp('1234');
      expect(cubit.state.escalate, isTrue);

      cubit.dismissEscalate();
      expect(cubit.state.escalate, isFalse);
      await cubit.close();
    });
  });
}

/// Store whose reads always throw — exercises the fall-through-to-gateway
/// guard in `_readStoredCode`.
class _ThrowingStore implements HandoverCodeStore {
  @override
  Future<void> save({required String deliveryId, required String code}) async {}

  @override
  Future<String?> read({required String deliveryId}) async =>
      throw StateError('prefs unavailable');

  @override
  Future<void> clear({required String deliveryId}) async {}
}
