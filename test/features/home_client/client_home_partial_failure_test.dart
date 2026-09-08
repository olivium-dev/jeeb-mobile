// ES-10 / F7 / OFF-15: one dead bucket no longer erases the buckets that
// loaded, and a FormatException counts as a failure — never as an empty tab.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_state.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_request.dart';
import 'package:jeeb_mobile/features/home_client/presentation/tabs/in_progress_tab.dart';
import 'package:jeeb_mobile/features/home_client/presentation/tabs/replies_tab.dart';

import '../../core/widgets/jeeb/jeeb_failure_test_harness.dart';
import '../../support/midnight_test_harness.dart';

class _SeededRepository implements ClientHomeRepository {
  const _SeededRepository(this.snapshot);

  final ClientHomeSnapshot snapshot;

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async => snapshot;
}

const ClientHomeRequest _reply = ClientHomeRequest(
  id: 'rep-1',
  title: 'ORD-7001',
  displayId: 'ORD-7001',
  status: ClientRequestStatus.offersReceived,
  destinationLabel: 'Hamra, Beirut',
  itemsSummary: 'Coffee beans',
  tier: ClientRequestTier.express,
  offerCount: 2,
);

ClientHomeCubit _cubit(ClientHomeSnapshot snapshot) => ClientHomeCubit(
  repository: _SeededRepository(snapshot),
  greetingNameProvider: () => 'Sami',
);

void main() {
  group('partial failure', () {
    test('one dead bucket stays READY, and marks only that bucket', () async {
      final ClientHomeCubit cubit = _cubit(
        const ClientHomeSnapshot(
          replies: <ClientHomeRequest>[_reply],
          inProgressFailure: NetworkFailure(offline: true),
        ),
      );
      addTearDown(cubit.close);
      await cubit.load();

      expect(cubit.state.status, ClientHomeStatus.ready);
      expect(cubit.state.inProgressError, isA<NetworkFailure>());
      expect(cubit.state.repliesError, isNull);
      expect(cubit.state.replies, hasLength(1));
    });

    test('every primary read dead → FAILED with the first failure', () async {
      final ClientHomeCubit cubit = _cubit(
        const ClientHomeSnapshot(
          requestsFailure: ServerFailure(status: 500),
          inProgressFailure: NetworkFailure(),
        ),
      );
      addTearDown(cubit.close);
      await cubit.load();

      expect(cubit.state.status, ClientHomeStatus.failed);
      expect(cubit.state.error, isA<ServerFailure>());
    });

    test('a parse failure is a failure, not an empty', () async {
      final ClientHomeCubit cubit = _cubit(
        const ClientHomeSnapshot(
          requestsFailure: UnknownFailure(parse: true),
        ),
      );
      addTearDown(cubit.close);
      await cubit.load();

      expect(cubit.state.status, ClientHomeStatus.ready);
      expect(cubit.state.pendingError, isA<UnknownFailure>());
      expect((cubit.state.pendingError! as UnknownFailure).parse, isTrue);
    });

    test('a throttle alone never reaches FAILED', () async {
      final ClientHomeCubit cubit = _cubit(
        const ClientHomeSnapshot(rateLimited: true),
      );
      addTearDown(cubit.close);
      await cubit.load();

      expect(cubit.state.status, isNot(ClientHomeStatus.failed));
    });
  });

  for (final Locale locale in kFailureLocales) {
    testWidgets(
      '${locale.languageCode}: In-Progress shows its error while Replies '
      'renders its list',
      (WidgetTester tester) async {
        useReduceMotion(tester);
        final ClientHomeCubit cubit = _cubit(
          const ClientHomeSnapshot(
            replies: <ClientHomeRequest>[_reply],
            inProgressFailure: NetworkFailure(offline: true),
          ),
        );
        addTearDown(cubit.close);
        await cubit.load();

        await tester.pumpWidget(
          wrapMidnight(
            BlocProvider<ClientHomeCubit>.value(
              value: cubit,
              child: const Column(
                children: <Widget>[
                  InProgressTab(),
                  RepliesTab(),
                ],
              ),
            ),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsIdentifier('in_progress_error_state'),
          findsOneWidget,
        );
        // Replies loaded, so NEITHER its empty nor its error rung shows.
        expect(
          find.bySemanticsIdentifier('replies_error_state'),
          findsNothing,
        );
        expect(
          find.bySemanticsIdentifier('replies_empty_state'),
          findsNothing,
        );
        expect(
          find.bySemanticsIdentifier('in_progress_empty_state'),
          findsNothing,
        );
      },
    );
  }
}
