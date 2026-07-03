import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/notifications/application/badge_count_cubit.dart';

void main() {
  group('BadgeCountCubit', () {
    blocTest<BadgeCountCubit, BadgeCounts>(
      'increments the unread total by one per push',
      build: BadgeCountCubit.new,
      act: (cubit) {
        cubit.increment();
        cubit.increment();
        cubit.increment();
      },
      expect: () => const [
        BadgeCounts(unread: 1),
        BadgeCounts(unread: 2),
        BadgeCounts(unread: 3),
      ],
    );

    blocTest<BadgeCountCubit, BadgeCounts>(
      'a new_request push bumps BOTH the unread total and the feed-tab '
      'request count (G3)',
      build: BadgeCountCubit.new,
      act: (cubit) {
        cubit.increment(isNewRequest: true);
        cubit.increment(); // chat/offer noise — must NOT badge the feed tab
        cubit.increment(isNewRequest: true);
      },
      expect: () => const [
        BadgeCounts(unread: 1, newRequests: 1),
        BadgeCounts(unread: 2, newRequests: 1),
        BadgeCounts(unread: 3, newRequests: 2),
      ],
    );

    blocTest<BadgeCountCubit, BadgeCounts>(
      'clear zeroes everything (inbox entry surfaces every push)',
      build: () => BadgeCountCubit(
        initial: const BadgeCounts(unread: 5, newRequests: 2),
      ),
      act: (cubit) => cubit.clear(),
      expect: () => const [BadgeCounts()],
    );

    blocTest<BadgeCountCubit, BadgeCounts>(
      'clear is a no-op when already zero (avoid pointless rebuilds)',
      build: BadgeCountCubit.new,
      act: (cubit) => cubit.clear(),
      expect: () => const <BadgeCounts>[],
    );

    blocTest<BadgeCountCubit, BadgeCounts>(
      'clearNewRequests zeroes ONLY the feed-tab count — the inbox total '
      'stays until the inbox is opened',
      build: () => BadgeCountCubit(
        initial: const BadgeCounts(unread: 5, newRequests: 2),
      ),
      act: (cubit) => cubit.clearNewRequests(),
      expect: () => const [BadgeCounts(unread: 5)],
    );

    blocTest<BadgeCountCubit, BadgeCounts>(
      'clearNewRequests is a no-op at zero (settles instead of looping)',
      build: () => BadgeCountCubit(initial: const BadgeCounts(unread: 3)),
      act: (cubit) => cubit.clearNewRequests(),
      expect: () => const <BadgeCounts>[],
    );
  });
}
