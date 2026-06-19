import '../domain/account_status.dart';
import '../domain/account_status_repository.dart';

/// Inert fallback [AccountStatusRepository] used ONLY when GetIt is not
/// configured (bare router-resolution widget tests / cold deep-link without the
/// DI batch) — mirrors `EmptyNotificationsRepository`. It is NOT the production
/// path: production resolves the LIVE `DioAccountStatusRepository` from
/// `sl<AccountStatusRepository>()`.
///
/// Returns a [AccountStatusValue.suspended] snapshot with no reason: by gate
/// contract this screen is only ever shown for a blocked account, and the
/// `suspended` seam (`jeeb.seam.session=suspended`) is the only blocked seed in
/// the harness today, so suspended is the least-surprising default (R-F). The
/// screen renders the localized per-state copy when [AccountStatusInfo.reason]
/// is null.
class StubAccountStatusRepository implements AccountStatusRepository {
  const StubAccountStatusRepository();

  @override
  Future<AccountStatusInfo> fetchStatus() async =>
      const AccountStatusInfo(value: AccountStatusValue.suspended);
}
