// TEST-05: the three home tabs' error rungs must be findable by their PINNED
// identifiers and their Retry must actually fire a SECOND fetch.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/presentation/tabs/in_progress_tab.dart';
import 'package:jeeb_mobile/features/home_client/presentation/tabs/pending_requests_tab.dart';
import 'package:jeeb_mobile/features/home_client/presentation/tabs/replies_tab.dart';

import '../../core/widgets/jeeb/jeeb_failure_test_harness.dart';
import '../../support/midnight_test_harness.dart';

class _AlwaysFailingRepository implements ClientHomeRepository {
  const _AlwaysFailingRepository();

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async =>
      throw const NetworkFailure(offline: true);
}

Widget _harness(ClientHomeCubit cubit, Widget tab, Locale locale) => wrapMidnight(
  BlocProvider<ClientHomeCubit>.value(value: cubit, child: tab),
  locale: locale,
);

typedef _Case = ({String name, String block, String retry, Widget tab});

final List<_Case> _cases = <_Case>[
  (
    name: 'in progress',
    block: 'in_progress_error_state',
    retry: 'in_progress_retry_cta',
    tab: const InProgressTab(onTrack: _noop, onOpenChat: _noop),
  ),
  (
    name: 'pending',
    block: 'pending_error_state',
    retry: 'pending_retry_cta',
    tab: const PendingRequestsTab(),
  ),
  (
    name: 'replies',
    block: 'replies_error_state',
    retry: 'replies_retry_cta',
    tab: const RepliesTab(),
  ),
];

void _noop(Object? _) {}

void main() {
  for (final _Case c in _cases) {
    for (final Locale locale in kFailureLocales) {
      testWidgets(
        '${c.name} · ${locale.languageCode}: ${c.block} retry refetches',
        (WidgetTester tester) async {
          useReduceMotion(tester);
          final ClientHomeCubit cubit = ClientHomeCubit(
            repository: const _AlwaysFailingRepository(),
            greetingNameProvider: () => 'Sami',
          );
          addTearDown(cubit.close);
          await cubit.load();
          await tester.pumpWidget(_harness(cubit, c.tab, locale));
          await tester.pumpAndSettle();

          expect(find.bySemanticsIdentifier(c.block), findsOneWidget);
          expect(find.bySemanticsIdentifier(c.retry), findsOneWidget);

          final int before = cubit.debugFetchCount;
          await tester.tap(find.bySemanticsIdentifier(c.retry));
          await tester.pumpAndSettle();
          expect(cubit.debugFetchCount, greaterThan(before));
        },
      );
    }
  }
}
