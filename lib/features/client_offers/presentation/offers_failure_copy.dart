import '../../../core/network/app_failure.dart';
import '../../../core/network/app_failure_mapper.dart';
import '../../../core/widgets/jeeb/app_failure_copy.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/offers_repository.dart';

enum OffersErrorPhase { load, accept }

/// Single shared source of truth for offer-review failure copy (F9). Both the
/// full-screen load error and the inline accept banner route through here, so
/// only the generic fallback diverges by [phase] and by [appFailure]'s kind.
String offersFailureCopy(
  AppLocalizations l10n,
  OffersFailure? failure, {
  required OffersErrorPhase phase,
  AppFailure? appFailure,
}) {
  switch (failure) {
    case OffersFailure.network:
      return failureCopy(
        l10n,
        appFailure ?? networkFailureFromReachability(),
      ).body;
    case OffersFailure.requestNotOpen:
      return l10n.offersErrorRequestNotOpen;
    case OffersFailure.requestExpired:
      return l10n.offersErrorRequestExpired;
    case OffersFailure.offerNotPending:
      return l10n.offersErrorOfferNotPending;
    case OffersFailure.jeeberAtCapacity:
      return l10n.offersErrorJeeberAtCapacity;
    case OffersFailure.jeeberWalletShort:
      return l10n.offersErrorJeeberWalletShort;
    // rateLimited is a TRANSIENT state the cubit handles by staying in loading
    // and auto-retrying, until the retry cap turns it into a real failure.
    case OffersFailure.rateLimited:
    case OffersFailure.unknown:
    case null:
      if (appFailure != null) return failureCopy(l10n, appFailure).body;
      // COPY-05: never "Retry." as body above a Retry button.
      return switch (phase) {
        OffersErrorPhase.load =>
          failureCopy(l10n, const UnknownFailure()).body,
        OffersErrorPhase.accept => l10n.offersErrorGeneric,
      };
  }
}
