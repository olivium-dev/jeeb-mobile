// Unit guard for `SearchCubit` — the 4-state free-text search state machine
// (Sprint-5 Stream C; coverage added Sprint-6 Stream D).
//
// The widget-level `search_screen_test.dart` drives the cubit indirectly
// through the screens; this file pins the cubit contract in ISOLATION so a
// regression in the state machine is attributed precisely, independent of any
// widget wiring:
//   * blank / whitespace-only query → resets to idle and NEVER hits the wire;
//   * a real query → loading → loaded (results may be empty → "no results");
//   * a typed `SearchRepositoryException` → failed with the SAME failure;
//   * any other throw → failed + `SearchFailure.unknown` (never leaks raw);
//   * the query is trimmed before it reaches the repository;
//   * a new query clears a prior error while loading (clearError);
//   * `retry()` re-runs the LAST query, and is inert before any query ran.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/features/search/application/search_cubit.dart';
import 'package:jeeb_mobile/features/search/application/search_state.dart';
import 'package:jeeb_mobile/features/search/domain/search_repository.dart';

class _MockSearchRepository extends Mock implements SearchRepository {}

void main() {
  late _MockSearchRepository repository;

  setUp(() {
    repository = _MockSearchRepository();
  });

  SearchCubit build() => SearchCubit(repository: repository);

  const orderHit = SearchResult(
    id: 'r-1',
    kind: SearchResultKind.order,
    title: 'Order d-1',
    refId: 'd-1',
  );

  group('starting state', () {
    test('is idle, blank, empty, no error', () {
      final cubit = build();
      addTearDown(cubit.close);
      expect(cubit.state.status, SearchStatus.idle);
      expect(cubit.state.query, '');
      expect(cubit.state.results, isEmpty);
      expect(cubit.state.hasResults, isFalse);
      expect(cubit.state.error, isNull);
    });
  });

  group('blank query — never fires a request', () {
    blocTest<SearchCubit, SearchState>(
      'empty string stays idle and does NOT call the repository',
      build: build,
      act: (c) => c.search(''),
      verify: (c) {
        verifyNever(() => repository.search(any()));
        expect(c.state.status, SearchStatus.idle);
        expect(c.state.query, '');
      },
    );

    blocTest<SearchCubit, SearchState>(
      'whitespace-only string is treated as blank (trimmed) — no request',
      build: build,
      act: (c) => c.search('   \t  '),
      verify: (c) {
        verifyNever(() => repository.search(any()));
        expect(c.state.status, SearchStatus.idle);
      },
    );

    blocTest<SearchCubit, SearchState>(
      'a blank query AFTER a loaded result clears back to a fresh idle state',
      build: build,
      setUp: () =>
          when(() => repository.search('book')).thenAnswer((_) async => [orderHit]),
      act: (c) async {
        await c.search('book');
        await c.search('   ');
      },
      expect: () => [
        // loading 'book'
        predicate<SearchState>(
          (s) => s.status == SearchStatus.loading && s.query == 'book',
        ),
        // loaded with the hit
        predicate<SearchState>(
          (s) => s.status == SearchStatus.loaded && s.hasResults,
        ),
        // blank → fresh idle (query reset to '', results cleared)
        predicate<SearchState>(
          (s) =>
              s.status == SearchStatus.idle &&
              s.query == '' &&
              s.results.isEmpty &&
              s.error == null,
        ),
      ],
    );
  });

  group('successful query', () {
    blocTest<SearchCubit, SearchState>(
      'transitions loading → loaded with the returned results',
      build: build,
      setUp: () => when(() => repository.search('book'))
          .thenAnswer((_) async => [orderHit]),
      act: (c) => c.search('book'),
      expect: () => [
        predicate<SearchState>(
          (s) =>
              s.status == SearchStatus.loading &&
              s.query == 'book' &&
              s.error == null,
        ),
        predicate<SearchState>(
          (s) =>
              s.status == SearchStatus.loaded &&
              s.query == 'book' &&
              s.results.length == 1 &&
              s.results.single.refId == 'd-1' &&
              s.hasResults,
        ),
      ],
    );

    blocTest<SearchCubit, SearchState>(
      'empty result list → loaded with hasResults == false (the "no results" '
      'surface, NOT a failure)',
      build: build,
      setUp: () => when(() => repository.search('zzz'))
          .thenAnswer((_) async => const <SearchResult>[]),
      act: (c) => c.search('zzz'),
      expect: () => [
        predicate<SearchState>((s) => s.status == SearchStatus.loading),
        predicate<SearchState>(
          (s) =>
              s.status == SearchStatus.loaded &&
              s.results.isEmpty &&
              !s.hasResults &&
              s.error == null,
        ),
      ],
    );

    blocTest<SearchCubit, SearchState>(
      'the query is TRIMMED before it reaches the repository',
      build: build,
      setUp: () => when(() => repository.search('book'))
          .thenAnswer((_) async => [orderHit]),
      act: (c) => c.search('   book   '),
      verify: (_) {
        verify(() => repository.search('book')).called(1);
        // The padded form is never sent.
        verifyNever(() => repository.search('   book   '));
      },
    );
  });

  group('failure mapping', () {
    for (final failure in SearchFailure.values) {
      blocTest<SearchCubit, SearchState>(
        'SearchRepositoryException($failure) → failed with that exact failure',
        build: build,
        setUp: () => when(() => repository.search('book'))
            .thenThrow(SearchRepositoryException(failure)),
        act: (c) => c.search('book'),
        expect: () => [
          predicate<SearchState>((s) => s.status == SearchStatus.loading),
          predicate<SearchState>(
            (s) =>
                s.status == SearchStatus.failed &&
                s.error == failure &&
                s.results.isEmpty,
          ),
        ],
      );
    }

    blocTest<SearchCubit, SearchState>(
      'an UNTYPED throw is mapped to SearchFailure.unknown (never leaks the raw '
      'exception)',
      build: build,
      setUp: () =>
          when(() => repository.search('book')).thenThrow(StateError('boom')),
      act: (c) => c.search('book'),
      expect: () => [
        predicate<SearchState>((s) => s.status == SearchStatus.loading),
        predicate<SearchState>(
          (s) =>
              s.status == SearchStatus.failed &&
              s.error == SearchFailure.unknown &&
              s.results.isEmpty,
        ),
      ],
    );

    blocTest<SearchCubit, SearchState>(
      'failed results are cleared (a prior loaded list does not survive an '
      'error)',
      build: build,
      setUp: () {
        when(() => repository.search('ok'))
            .thenAnswer((_) async => [orderHit]);
        when(() => repository.search('bad'))
            .thenThrow(const SearchRepositoryException(SearchFailure.network));
      },
      act: (c) async {
        await c.search('ok');
        await c.search('bad');
      },
      verify: (c) {
        expect(c.state.status, SearchStatus.failed);
        expect(c.state.results, isEmpty);
        expect(c.state.error, SearchFailure.network);
      },
    );
  });

  group('clearError on a fresh query', () {
    blocTest<SearchCubit, SearchState>(
      'a new query starts loading with the previous error CLEARED',
      build: build,
      setUp: () {
        when(() => repository.search('bad')).thenThrow(
          const SearchRepositoryException(SearchFailure.unauthorized),
        );
        when(() => repository.search('good'))
            .thenAnswer((_) async => [orderHit]);
      },
      act: (c) async {
        await c.search('bad');
        await c.search('good');
      },
      expect: () => [
        predicate<SearchState>((s) => s.status == SearchStatus.loading),
        predicate<SearchState>(
          (s) =>
              s.status == SearchStatus.failed &&
              s.error == SearchFailure.unauthorized,
        ),
        // Re-search: loading state must NOT carry the stale error.
        predicate<SearchState>(
          (s) =>
              s.status == SearchStatus.loading &&
              s.query == 'good' &&
              s.error == null,
        ),
        predicate<SearchState>(
          (s) => s.status == SearchStatus.loaded && s.hasResults,
        ),
      ],
    );
  });

  group('retry', () {
    blocTest<SearchCubit, SearchState>(
      're-runs the LAST query (error-state CTA recovers to loaded)',
      build: build,
      setUp: () {
        var calls = 0;
        when(() => repository.search('book')).thenAnswer((_) async {
          calls++;
          if (calls == 1) {
            throw const SearchRepositoryException(SearchFailure.network);
          }
          return [orderHit];
        });
      },
      act: (c) async {
        await c.search('book');
        await c.retry();
      },
      verify: (c) {
        // The same query was sent twice (initial + retry).
        verify(() => repository.search('book')).called(2);
        expect(c.state.status, SearchStatus.loaded);
        expect(c.state.hasResults, isTrue);
        expect(c.state.error, isNull);
      },
    );

    blocTest<SearchCubit, SearchState>(
      'retry() before any query ran is inert — the empty query never hits the '
      'wire',
      build: build,
      act: (c) => c.retry(),
      verify: (c) {
        verifyNever(() => repository.search(any()));
        expect(c.state.status, SearchStatus.idle);
      },
    );
  });
}
