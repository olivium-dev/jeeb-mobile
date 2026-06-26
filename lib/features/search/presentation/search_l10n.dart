import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/search_repository.dart';

/// Sprint-5 Stream C search localized-copy resolver (the `notifications_l10n`
/// precedent, 40_GUARDRAILS_ARCH §9 l10n protocol). Every string resolves from
/// a dedicated EN/AR ARB getter — no feature-local fallback map.
class SearchL10n {
  SearchL10n(this._l10n);

  factory SearchL10n.of(BuildContext context) =>
      SearchL10n(AppLocalizations.of(context));

  final AppLocalizations _l10n;

  String get title => _l10n.searchTitle;
  String get hint => _l10n.searchHint;
  String get promptTitle => _l10n.searchPromptTitle;
  String get promptBody => _l10n.searchPromptBody;
  String get resultsTitle => _l10n.searchResultsTitle;
  String get noResultsTitle => _l10n.searchNoResultsTitle;
  String get noResultsBody => _l10n.searchNoResultsBody;
  String get unavailableTitle => _l10n.searchUnavailableTitle;
  String get unavailableBody => _l10n.searchUnavailableBody;
  String get networkError => _l10n.searchNetworkError;
  String get loadError => _l10n.searchLoadError;
  String get retry => _l10n.searchRetry;

  /// Maps a typed [SearchFailure] to its error copy.
  String errorCopy(SearchFailure? failure) {
    switch (failure) {
      case SearchFailure.network:
        return networkError;
      case SearchFailure.unauthorized:
      case SearchFailure.unknown:
      case SearchFailure.unavailable:
      case null:
        return loadError;
    }
  }
}
