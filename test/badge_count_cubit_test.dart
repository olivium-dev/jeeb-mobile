import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/notifications/application/badge_count_cubit.dart';

void main() {
  group('BadgeCountCubit', () {
    blocTest<BadgeCountCubit, int>(
      'increments by one',
      build: BadgeCountCubit.new,
      act: (cubit) {
        cubit.increment();
        cubit.increment();
        cubit.increment();
      },
      expect: () => [1, 2, 3],
    );

    blocTest<BadgeCountCubit, int>(
      'clear emits 0 when non-zero',
      build: () => BadgeCountCubit(initial: 5),
      act: (cubit) => cubit.clear(),
      expect: () => [0],
    );

    blocTest<BadgeCountCubit, int>(
      'clear is a no-op when already 0 (avoid pointless rebuilds)',
      build: BadgeCountCubit.new,
      act: (cubit) => cubit.clear(),
      expect: () => <int>[],
    );
  });
}
