import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import 'search_l10n.dart';

/// SearchScreen (Sprint-5 Stream C) — the search compose surface reached from
/// the shell header search affordance (`*_search` → `goNamed('search')`).
///
/// Hosts an autofocused [OmdsSearchBar]; submitting a non-blank query navigates
/// to `/search-results?q=<query>` (the results screen owns the query lifecycle
/// + state machine). A blank submit is a no-op (no dead-end). The body shows a
/// prompt explaining what is searchable — never an empty void.
///
/// Semantics identifiers (EXACT):
///   `search_root`   — screen host container (the header search nav target)
///   `search_input`  — the search field
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final copy = SearchL10n.of(context);
    return Semantics(
      identifier: 'search_root',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        appBar: OMDSAppBar(
          title: copy.title,
          showBackButton: true,
          onBackPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(Spacing.medium),
                child: Semantics(
                  identifier: 'search_input',
                  container: true,
                  child: OmdsSearchBar(
                    hintText: copy.hint,
                    autofocus: true,
                    onSubmitted: (q) => _submit(context, q),
                  ),
                ),
              ),
              Expanded(
                child: OmdsEmptyState(
                  icon: Icons.search_outlined,
                  title: copy.promptTitle,
                  subtitle: copy.promptBody,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Navigates to the results screen for a non-blank query. The query is
  /// forwarded as the `q` query parameter so a results deep-link is shareable
  /// and survives process death.
  void _submit(BuildContext context, String rawQuery) {
    final query = rawQuery.trim();
    if (query.isEmpty) return;
    context.goNamed(
      'search-results',
      queryParameters: <String, String>{'q': query},
    );
  }
}
