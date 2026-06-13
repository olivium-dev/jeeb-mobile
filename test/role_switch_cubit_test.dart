import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/settings/application/role_switch_cubit.dart';
import 'package:jeeb_mobile/features/settings/domain/role_switch_repository.dart';

/// In-memory [RoleSwitchRepository] for tests.
class _FakeRoleSwitchRepository implements RoleSwitchRepository {
  _FakeRoleSwitchRepository({this.result = RoleSwitchResult.success});

  RoleSwitchResult result;

  @override
  Future<RoleSwitchResult> switchRole(String role) async {
    if (result == RoleSwitchResult.success) return result;
    if (result == RoleSwitchResult.kycGated) return RoleSwitchResult.kycGated;
    throw const RoleSwitchException('network error');
  }
}

class _ThrowingRoleSwitchRepository implements RoleSwitchRepository {
  @override
  Future<RoleSwitchResult> switchRole(String role) async {
    throw const RoleSwitchException('network failed');
  }
}

void main() {
  group('RoleSwitchCubit', () {
    test('initial state has client role', () {
      final cubit = RoleSwitchCubit(
        repository: _FakeRoleSwitchRepository(),
      );
      expect(cubit.state.activeRole, equals('client'));
      expect(cubit.state.isInFlight, isFalse);
      cubit.close();
    });

    blocTest<RoleSwitchCubit, RoleSwitchState>(
      'AC1: switchTo updates activeRole on 200',
      build: () => RoleSwitchCubit(
        repository: _FakeRoleSwitchRepository(),
      ),
      act: (cubit) => cubit.switchTo('jeeber'),
      expect: () => [
        const RoleSwitchState(
          activeRole: 'client',
          isInFlight: true,
          kycGated: false,
          hasError: false,
        ),
        const RoleSwitchState(
          activeRole: 'jeeber',
          isInFlight: false,
          kycGated: false,
          hasError: false,
        ),
      ],
    );

    blocTest<RoleSwitchCubit, RoleSwitchState>(
      'AC2: switchTo sets kycGated on 403',
      build: () => RoleSwitchCubit(
        repository: _FakeRoleSwitchRepository(result: RoleSwitchResult.kycGated),
      ),
      act: (cubit) => cubit.switchTo('jeeber'),
      expect: () => [
        const RoleSwitchState(
          activeRole: 'client',
          isInFlight: true,
          kycGated: false,
          hasError: false,
        ),
        const RoleSwitchState(
          activeRole: 'client',
          isInFlight: false,
          kycGated: true,
          hasError: false,
        ),
      ],
    );

    blocTest<RoleSwitchCubit, RoleSwitchState>(
      'sets hasError on network failure',
      build: () => RoleSwitchCubit(
        repository: _ThrowingRoleSwitchRepository(),
      ),
      act: (cubit) => cubit.switchTo('jeeber'),
      expect: () => [
        const RoleSwitchState(
          activeRole: 'client',
          isInFlight: true,
          kycGated: false,
          hasError: false,
        ),
        const RoleSwitchState(
          activeRole: 'client',
          isInFlight: false,
          kycGated: false,
          hasError: true,
        ),
      ],
    );

    blocTest<RoleSwitchCubit, RoleSwitchState>(
      'no-op when already in target role',
      build: () => RoleSwitchCubit(
        repository: _FakeRoleSwitchRepository(),
      ),
      act: (cubit) => cubit.switchTo('client'), // same as initial
      expect: () => const <RoleSwitchState>[],
    );

    blocTest<RoleSwitchCubit, RoleSwitchState>(
      'clearKycGate clears the kycGated flag',
      build: () => RoleSwitchCubit(
        repository: _FakeRoleSwitchRepository(result: RoleSwitchResult.kycGated),
      ),
      act: (cubit) async {
        await cubit.switchTo('jeeber');
        cubit.clearKycGate();
      },
      skip: 2,
      expect: () => [
        const RoleSwitchState(
          activeRole: 'client',
          isInFlight: false,
          kycGated: false,
          hasError: false,
        ),
      ],
    );
  });
}
