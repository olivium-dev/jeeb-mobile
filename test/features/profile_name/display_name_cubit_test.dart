// Unit tests for DisplayNameCubit (profile-name lane): submit lifecycle,

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/session/profile_refresh_signals.dart';
import 'package:jeeb_mobile/features/profile_name/application/display_name_cubit.dart';
import 'package:jeeb_mobile/features/profile_name/domain/display_name_repository.dart';

class _RecordingRepository implements DisplayNameRepository {
  _RecordingRepository({this.throws = false});

  final bool throws;
  final List<String> submitted = <String>[];

  @override
  Future<void> submitDisplayName(String name) async {
    if (throws) {
      throw const DisplayNameRepositoryException(DisplayNameFailure.network);
    }
    submitted.add(name);
  }
}

void main() {
  group('DisplayNameCubit', () {
    test('submit → saving → saved and PUTs the trimmed name', () async {
      final repo = _RecordingRepository();
      final cubit = DisplayNameCubit(repository: repo);
      final statuses = <DisplayNameStatus>[];
      final sub = cubit.stream.listen((s) => statuses.add(s.status));

      await cubit.submit('  Ahmad ');
      // Stream delivery is a microtask behind emit — flush before asserting.
      await Future<void>.delayed(Duration.zero);

      expect(repo.submitted, ['Ahmad']);
      expect(statuses,
          [DisplayNameStatus.saving, DisplayNameStatus.saved]);
      expect(cubit.state.status, DisplayNameStatus.saved);
      await sub.cancel();
      await cubit.close();
    });

    test('blank submit is a no-op (skip is the separate exit)', () async {
      final repo = _RecordingRepository();
      final cubit = DisplayNameCubit(repository: repo);
      await cubit.submit('   ');
      expect(repo.submitted, isEmpty);
      expect(cubit.state.status, DisplayNameStatus.idle);
      await cubit.close();
    });

    test('failed PUT emits failure — fail-soft, never a throw', () async {
      final cubit = DisplayNameCubit(
        repository: _RecordingRepository(throws: true),
      );
      await cubit.submit('Ahmad');
      expect(cubit.state.status, DisplayNameStatus.failure);
      await cubit.close();
    });

    test('null repository (fixture mode) resolves as saved', () async {
      final cubit = DisplayNameCubit();
      await cubit.submit('Ahmad');
      expect(cubit.state.status, DisplayNameStatus.saved);
      await cubit.close();
    });

    test('successful save broadcasts a profile-changed signal', () async {
      final signals = ProfileRefreshSignals();
      var fired = 0;
      final sub = signals.stream.listen((_) => fired++);
      final cubit = DisplayNameCubit(
        repository: _RecordingRepository(),
        refreshSignals: signals,
      );

      await cubit.submit('Ahmad');
      await Future<void>.delayed(Duration.zero);

      expect(fired, 1);
      await cubit.close();
      await sub.cancel();
      await signals.dispose();
    });

    test('failed save does NOT broadcast a profile change', () async {
      final signals = ProfileRefreshSignals();
      var fired = 0;
      final sub = signals.stream.listen((_) => fired++);
      final cubit = DisplayNameCubit(
        repository: _RecordingRepository(throws: true),
        refreshSignals: signals,
      );

      await cubit.submit('Ahmad');
      await Future<void>.delayed(Duration.zero);

      expect(fired, 0);
      await cubit.close();
      await sub.cancel();
      await signals.dispose();
    });
  });
}
