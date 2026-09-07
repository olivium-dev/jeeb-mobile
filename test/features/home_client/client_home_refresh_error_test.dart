// LR-11 / OFF-14 / F8: a refresh that fails over rows keeps the rows, says so
// on a dismissible band, and a later success clears it.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_refresh_failed_note.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_state.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_request.dart';

import '../../core/widgets/jeeb/jeeb_failure_test_harness.dart';
import '../../support/midnight_test_harness.dart';

const ClientHomeRequest _row = ClientHomeRequest(
  id: 'ip-1',
  title: 'ORD-4001',
  displayId: 'ORD-4001',
  status: ClientRequestStatus.accepted,
  destinationLabel: 'Achrafieh',
  itemsSummary: 'One box',
  tier: ClientRequestTier.express,
);

const ClientHomeRequest _pendingRow = ClientHomeRequest(
  id: 'pd-1',
  title: 'ORD-4002',
  displayId: 'ORD-4002',
  status: ClientRequestStatus.searching,
  destinationLabel: 'Hamra',
  itemsSummary: 'One bag',
  tier: ClientRequestTier.express,
);

/// First read succeeds; every read after it throws, until [healed].
class _ColdOkThenFailing implements ClientHomeRepository {
  _ColdOkThenFailing();

  int reads = 0;
  bool healed = false;

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async {
    if (reads++ == 0 || healed) {
      return const ClientHomeSnapshot(inProgress: <ClientHomeRequest>[_row]);
    }
    throw const NetworkFailure(offline: true);
  }
}

/// Cold load fills both tab buckets; every read after it loses ONE bucket.
class _ColdOkThenPartial implements ClientHomeRepository {
  int reads = 0;

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async {
    if (reads++ == 0) {
      return const ClientHomeSnapshot(
        inProgress: <ClientHomeRequest>[_row],
        pending: <ClientHomeRequest>[_pendingRow],
      );
    }
    return const ClientHomeSnapshot(
      inProgress: <ClientHomeRequest>[_row],
      requestsFailure: NetworkFailure(offline: true),
    );
  }
}

void main() {
  test('a warm partial failure keeps the dead bucket\'s rows', () async {
    final ClientHomeCubit cubit = ClientHomeCubit(
      repository: _ColdOkThenPartial(),
      greetingNameProvider: () => 'Sami',
    );
    addTearDown(cubit.close);

    await cubit.load();
    expect(cubit.state.pending, hasLength(1));

    await cubit.refresh();
    expect(cubit.state.status, ClientHomeStatus.ready);
    // R6: the refresh lost the requests read — the rows stay, the band speaks.
    expect(cubit.state.pending, hasLength(1));
    expect(cubit.state.pendingError, isNull);
    expect(cubit.state.repliesError, isNull);
    expect(cubit.state.refreshError, isA<NetworkFailure>());
    expect(cubit.state.inProgress, hasLength(1));
  });

  test('a COLD partial failure still marks the dead bucket', () async {
    final _ColdOkThenPartial repo = _ColdOkThenPartial()..reads = 1;
    final ClientHomeCubit cubit = ClientHomeCubit(
      repository: repo,
      greetingNameProvider: () => 'Sami',
    );
    addTearDown(cubit.close);

    await cubit.load();
    expect(cubit.state.status, ClientHomeStatus.ready);
    expect(cubit.state.pendingError, isA<NetworkFailure>());
    expect(cubit.state.refreshError, isNull);
  });

  test('a failed refresh keeps status ready and the rows', () async {
    final _ColdOkThenFailing repo = _ColdOkThenFailing();
    final ClientHomeCubit cubit = ClientHomeCubit(
      repository: repo,
      greetingNameProvider: () => 'Sami',
    );
    addTearDown(cubit.close);

    await cubit.load();
    expect(cubit.state.status, ClientHomeStatus.ready);

    await cubit.refresh();
    expect(cubit.state.status, ClientHomeStatus.ready);
    expect(cubit.state.inProgress, hasLength(1));
    expect(cubit.state.refreshError, isA<NetworkFailure>());

    cubit.acknowledgeRefreshError();
    expect(cubit.state.refreshError, isNull);

    await cubit.refresh();
    expect(cubit.state.refreshError, isA<NetworkFailure>());

    repo.healed = true;
    await cubit.refresh();
    expect(cubit.state.refreshError, isNull);
  });

  for (final Locale locale in kFailureLocales) {
    testWidgets('${locale.languageCode}: the warm band renders and dismisses', (
      WidgetTester tester,
    ) async {
      useReduceMotion(tester);
      final ClientHomeCubit cubit = ClientHomeCubit(
        repository: _ColdOkThenFailing(),
        greetingNameProvider: () => 'Sami',
      );
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.refresh();

      await tester.pumpWidget(
        wrapMidnight(
          BlocProvider<ClientHomeCubit>.value(
            value: cubit,
            child: BlocBuilder<ClientHomeCubit, ClientHomeState>(
              builder: (BuildContext context, ClientHomeState state) =>
                  state.refreshError == null
                  ? const SizedBox.shrink()
                  : JeebRefreshFailedNote(
                      failure: state.refreshError!,
                      identifier: 'client_home_refresh_failed_note',
                      onDismiss: cubit.acknowledgeRefreshError,
                    ),
            ),
          ),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('client_home_refresh_failed_note'),
        findsOneWidget,
      );
      await tester.tap(
        find.bySemanticsIdentifier(
          'client_home_refresh_failed_note_dismiss_cta',
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsIdentifier('client_home_refresh_failed_note'),
        findsNothing,
      );
    });
  }
}
