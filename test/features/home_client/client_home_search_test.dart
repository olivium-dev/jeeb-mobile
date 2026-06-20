// home-disc-customer-home-search: the interactive home search filter. Verifies
// the ClientHomeState `visible*` getters apply the query (case-insensitive over
// title/items/destination/jeeber/displayId) and the cubit's setQuery emits.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_state.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_request.dart';

class _MockRepo extends Mock implements ClientHomeRepository {}

ClientHomeRequest _req(
  String id, {
  String title = 'Pharmacy run',
  String destination = 'Ashrafieh, Beirut',
  String? items,
  String? jeeber,
  ClientRequestStatus status = ClientRequestStatus.searching,
}) =>
    ClientHomeRequest(
      id: id,
      title: title,
      destinationLabel: destination,
      itemsSummary: items,
      jeeberName: jeeber,
      status: status,
    );

void main() {
  group('ClientHomeState search filter', () {
    final state = ClientHomeState(
      status: ClientHomeStatus.ready,
      inProgress: [
        _req('a', title: 'Pharmacy run', status: ClientRequestStatus.accepted),
        _req('b', title: 'Grocery haul', items: 'milk, eggs', jeeber: 'Sami'),
      ],
      pending: [_req('c', title: 'Bakery pickup')],
      replies: [_req('d', title: 'Pharmacy refill')],
    );

    test('empty query returns every row', () {
      final s = state.copyWith(query: '');
      expect(s.hasQuery, isFalse);
      expect(s.visibleInProgress.length, 2);
      expect(s.visiblePending.length, 1);
      expect(s.visibleReplies.length, 1);
    });

    test('matches the title (case-insensitive)', () {
      final s = state.copyWith(query: 'PHARMACY');
      expect(s.hasQuery, isTrue);
      expect(s.visibleInProgress.map((r) => r.id), ['a']);
      expect(s.visibleReplies.map((r) => r.id), ['d']);
    });

    test('matches items summary', () {
      final s = state.copyWith(query: 'eggs');
      expect(s.visibleInProgress.map((r) => r.id), ['b']);
    });

    test('matches Jeeber name', () {
      final s = state.copyWith(query: 'sami');
      expect(s.visibleInProgress.map((r) => r.id), ['b']);
    });

    test('matches destination', () {
      final s = state.copyWith(query: 'ashrafieh');
      // a + b both carry the default destination.
      expect(s.visibleInProgress.map((r) => r.id).toSet(), {'a', 'b'});
    });

    test('a non-matching query yields no rows (drives the no-results state)',
        () {
      final s = state.copyWith(query: 'zzzz');
      expect(s.visibleInProgress, isEmpty);
      expect(s.visiblePending, isEmpty);
      expect(s.visibleReplies, isEmpty);
      // The raw lists are untouched (server snapshot preserved).
      expect(s.inProgress.length, 2);
    });

    test('visibleFor mirrors the per-tab getters', () {
      final s = state.copyWith(query: 'pharmacy');
      expect(s.visibleFor(ClientHomeTab.inProgress).map((r) => r.id), ['a']);
      expect(s.visibleFor(ClientHomeTab.pendingRequests), isEmpty);
      expect(s.visibleFor(ClientHomeTab.replies).map((r) => r.id), ['d']);
    });
  });

  group('ClientHomeCubit.setQuery', () {
    blocTest<ClientHomeCubit, ClientHomeState>(
      'emits the new query',
      build: () => ClientHomeCubit(
        repository: _MockRepo(),
        greetingNameProvider: () => null,
      ),
      act: (c) => c.setQuery('milk'),
      expect: () => [
        predicate<ClientHomeState>((s) => s.query == 'milk', 'query=milk'),
      ],
    );

    blocTest<ClientHomeCubit, ClientHomeState>(
      'an unchanged query does not re-emit',
      build: () => ClientHomeCubit(
        repository: _MockRepo(),
        greetingNameProvider: () => null,
      ),
      act: (c) {
        c.setQuery('x');
        c.setQuery('x');
      },
      expect: () => [
        predicate<ClientHomeState>((s) => s.query == 'x'),
      ],
    );
  });
}
