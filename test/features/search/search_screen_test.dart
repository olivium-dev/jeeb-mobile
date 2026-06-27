// Widget tests for the Sprint-5 Stream C search feature. Proves:
//   - SearchScreen renders its EXACT Semantics ids (search_root, search_input)
//     + the prompt empty state;
//   - submitting a non-blank query NAVIGATES to /search-results (the results
//     screen mounts: search_results_root);
//   - a blank submit is a no-op (no dead-end navigation);
//   - SearchResultsScreen renders the 4-state machine off an injected repo:
//     loaded(+rows) / no-results / unavailable / error;
//   - a result-row tap dispatches the deep-link for its kind.
//
// A minimal GoRouter with stub destination screens (each carrying a *_root id)
// backs the dispatch + navigation assertions, since context.goNamed/pushNamed
// needs a router.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jeeb_mobile/features/search/domain/search_repository.dart';
import 'package:jeeb_mobile/features/search/presentation/search_results_screen.dart';
import 'package:jeeb_mobile/features/search/presentation/search_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _ScriptedRepository implements SearchRepository {
  _ScriptedRepository(this._results, {this.throws});

  final List<SearchResult> _results;
  final SearchFailure? throws;
  final List<String> queries = <String>[];

  @override
  Future<List<SearchResult>> search(String query) async {
    queries.add(query);
    final f = throws;
    if (f != null) throw SearchRepositoryException(f);
    return _results;
  }
}

SearchResult _result(
  String id,
  SearchResultKind kind, {
  String? refId,
}) =>
    SearchResult(
      id: id,
      kind: kind,
      title: 'title-$id',
      subtitle: 'subtitle-$id',
      refId: refId,
    );

// A tiny stub screen exposing a root id so dispatch tests assert landing.
Widget _stub(String id) => Semantics(
      identifier: id,
      container: true,
      child: const Scaffold(body: SizedBox.expand()),
    );

/// Router whose `/search-results` builder injects [resultsRepo] (so the results
/// state is deterministic without DI).
Widget _harness({
  SearchRepository? resultsRepo,
  String initialLocation = '/search',
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/search',
        name: 'search',
        builder: (_, _) => const SearchScreen(),
      ),
      GoRoute(
        path: '/search-results',
        name: 'search-results',
        builder: (_, s) => SearchResultsScreen(
          query: s.uri.queryParameters['q'] ?? '',
          repository: resultsRepo,
        ),
      ),
      GoRoute(path: '/', name: 'shell', builder: (_, _) => _stub('shell_root')),
      GoRoute(
        path: '/orders/:id',
        name: 'delivery-detail',
        builder: (_, s) =>
            _stub('delivery_detail_root_${s.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/chat/:id',
        name: 'chat-detail',
        builder: (_, s) =>
            _stub('order_chat_root_${s.pathParameters['id']}'),
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
  );
}

void main() {
  Future<void> submitQuery(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
  }

  group('SearchScreen', () {
    testWidgets('renders search_root + search_input + prompt', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(find.bySemanticsIdentifier('search_root'), findsOneWidget);
      expect(find.bySemanticsIdentifier('search_input'), findsOneWidget);
      // Prompt empty state (the searchable-content explainer) renders.
      expect(find.text('Search Jeeb'), findsOneWidget);
    });

    testWidgets('submitting a query navigates to the results screen',
        (tester) async {
      await tester.pumpWidget(
        _harness(resultsRepo: _ScriptedRepository(const [])),
      );
      await tester.pumpAndSettle();

      await submitQuery(tester, 'pharmacy');

      expect(find.bySemanticsIdentifier('search_results_root'), findsOneWidget);
      expect(find.bySemanticsIdentifier('search_root'), findsNothing);
    });

    testWidgets('blank submit is a no-op (stays on compose, no dead-end)',
        (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      await submitQuery(tester, '   ');

      expect(find.bySemanticsIdentifier('search_root'), findsOneWidget);
      expect(find.bySemanticsIdentifier('search_results_root'), findsNothing);
    });
  });

  group('SearchResultsScreen', () {
    testWidgets(
        'blank-query deep-link (/search-results, no q) → idle PROMPT surface, '
        'NOT a permanent loading spinner (FIX #1)', (tester) async {
      // A blank/absent `q` makes the cubit emit idle (never fires a request).
      // The idle arm must render the prompt/empty surface — distinct from the
      // loading spinner. Single pump() (NOT pumpAndSettle): if idle still
      // collapsed into the OmdsLoadingState arm, the infinite
      // CircularProgressIndicator ticker would hang pumpAndSettle.
      await tester.pumpWidget(_harness(initialLocation: '/search-results'));
      await tester.pump();

      expect(find.bySemanticsIdentifier('search_results_root'), findsOneWidget);
      // Idle is the prompt surface (matches the compose /search screen prompt).
      expect(find.text('Search Jeeb'), findsOneWidget);
      // No fake/permanent loading spinner on a blank query.
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('loaded → renders search_result_<id> rows', (tester) async {
      final repo = _ScriptedRepository([
        _result('r1', SearchResultKind.order, refId: 'ord-1'),
        _result('r2', SearchResultKind.conversation, refId: 'conv-2'),
      ]);
      await tester.pumpWidget(
        _harness(
          resultsRepo: repo,
          initialLocation: '/search-results?q=milk',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsIdentifier('search_results_root'), findsOneWidget);
      expect(find.bySemanticsIdentifier('search_result_r1'), findsOneWidget);
      expect(find.bySemanticsIdentifier('search_result_r2'), findsOneWidget);
      expect(repo.queries, ['milk']);
    });

    testWidgets('no results → no-results empty state', (tester) async {
      await tester.pumpWidget(
        _harness(
          resultsRepo: _ScriptedRepository(const []),
          initialLocation: '/search-results?q=zzz',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No results'), findsOneWidget);
      expect(find.bySemanticsIdentifier('search_result_r1'), findsNothing);
    });

    testWidgets('endpoint absent (unavailable) → honest empty state, not error',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          resultsRepo:
              _ScriptedRepository(const [], throws: SearchFailure.unavailable),
          initialLocation: '/search-results?q=anything',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Search isn't available yet"), findsOneWidget);
      // Honest empty state, not a hard error glyph.
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('network failure → error state', (tester) async {
      await tester.pumpWidget(
        _harness(
          resultsRepo:
              _ScriptedRepository(const [], throws: SearchFailure.network),
          initialLocation: '/search-results?q=anything',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('order row tap → delivery-detail deep-link', (tester) async {
      await tester.pumpWidget(
        _harness(
          resultsRepo: _ScriptedRepository(
            [_result('r1', SearchResultKind.order, refId: 'ord-9')],
          ),
          initialLocation: '/search-results?q=milk',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsIdentifier('search_result_r1'));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('delivery_detail_root_ord-9'),
        findsOneWidget,
      );
    });

    testWidgets('conversation row tap → chat-detail deep-link', (tester) async {
      await tester.pumpWidget(
        _harness(
          resultsRepo: _ScriptedRepository(
            [_result('r2', SearchResultKind.conversation, refId: 'conv-7')],
          ),
          initialLocation: '/search-results?q=hi',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsIdentifier('search_result_r2'));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('order_chat_root_conv-7'),
        findsOneWidget,
      );
    });
  });
}
