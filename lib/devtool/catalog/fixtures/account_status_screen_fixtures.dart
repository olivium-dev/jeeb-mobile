// Shared dev-only fixtures for `AccountStatusScreen` (JM-066, D5).

import 'dart:async';

import 'package:jeeb_mobile/features/account_status/domain/account_status.dart';
import 'package:jeeb_mobile/features/account_status/domain/account_status_repository.dart';

/// Canned [AccountStatusRepository] — `fetchStatus()` resolves immediately to
/// [info]. No Dio, no GetIt, no network.
/// `const`-constructible so the catalog can keep building
class AccountStatusScreenFakeRepository implements AccountStatusRepository {
  const AccountStatusScreenFakeRepository(this.info);

  /// What `GET /v1/users/me` resolves to, already mapped to the domain model.
  final AccountStatusInfo info;

  @override
  Future<AccountStatusInfo> fetchStatus() async => info;
}

/// A read that fails with a typed [AccountStatusFailure], which is how the live
/// repository fails — not a null and not a `suspended` default.
/// Drives the cubit's `failed` branch. The specific value does NOT pick the
class AccountStatusScreenFailingRepository implements AccountStatusRepository {
  const AccountStatusScreenFailingRepository({
    this.failure = AccountStatusFailure.network,
  });

  final AccountStatusFailure failure;

  @override
  Future<AccountStatusInfo> fetchStatus() async =>
      throw AccountStatusRepositoryException(failure);
}

/// A read that never lands, holding the screen on
/// `AccountStatusScreenStatus.loading` for as long as the surface is open.
/// `AccountStatusCubit.load()` emits `loading` and only leaves it when the
class AccountStatusScreenPendingRepository implements AccountStatusRepository {
  const AccountStatusScreenPendingRepository();

  @override
  Future<AccountStatusInfo> fetchStatus() =>
      Completer<AccountStatusInfo>().future;
}

/// The catalog's `Suspended` state: blocked, with NO server-supplied reason.
/// The closest thing this screen has to an empty state — there is no fifth
const AccountStatusInfo accountStatusScreenSuspended =
    AccountStatusInfo(value: AccountStatusValue.suspended);

/// The server reason the catalog's `Locked — server reason` state carries.
/// Named separately so the render test can pin it without re-typing it.
const String accountStatusScreenSecurityHoldReason =
    'Security hold pending identity re-verification.';

/// The catalog's `Locked — server reason` state: the other blocked value, plus
/// free server text that REPLACES the localized reason copy.
const AccountStatusInfo accountStatusScreenLockedWithReason = AccountStatusInfo(
  value: AccountStatusValue.locked,
  reason: accountStatusScreenSecurityHoldReason,
);

/// The longest reason the gateway can plausibly hand this screen.
/// Not invented length: `statusReason` is free text written by whoever actioned
const String accountStatusScreenLongReasonText =
    'Your account was locked on 28 July 2026 after our risk team flagged four '
    'chargeback disputes opened against deliveries you paid for in the same '
    'week. Access stays locked while the disputes are reviewed with the '
    'payment provider, which normally takes five to seven business days. '
    'Contact support with your order references if you believe this was raised '
    'in error.';

/// The layout ceiling: locked, with [accountStatusScreenLongReasonText].
const AccountStatusInfo accountStatusScreenLockedLongReason = AccountStatusInfo(
  value: AccountStatusValue.locked,
  reason: accountStatusScreenLongReasonText,
);

/// Critic A4: the three failure rungs the screen could not draw before —
/// a 403, a 5xx, and a loaded banner whose refresh then failed.
class AccountStatusScreenThrowingRepository
    implements AccountStatusRepository {
  const AccountStatusScreenThrowingRepository(this.failure);

  /// 403 → the exit CTA (terminal); 5xx → Retry.
  static const AccountStatusScreenThrowingRepository forbidden =
      AccountStatusScreenThrowingRepository(AccountStatusFailure.forbidden);

  static const AccountStatusScreenThrowingRepository serverError =
      AccountStatusScreenThrowingRepository(AccountStatusFailure.serverError);

  final AccountStatusFailure failure;

  @override
  Future<AccountStatusInfo> fetchStatus() async =>
      throw AccountStatusRepositoryException(failure);
}

/// A first read that lands, then a refresh that fails: the banner stays and
/// `account_status_refresh_failed_note` appears over it.
class AccountStatusScreenRefreshFailingRepository
    implements AccountStatusRepository {
  AccountStatusScreenRefreshFailingRepository(this.info);

  final AccountStatusInfo info;

  bool _first = true;

  @override
  Future<AccountStatusInfo> fetchStatus() async {
    if (_first) {
      _first = false;
      return info;
    }
    throw const AccountStatusRepositoryException(AccountStatusFailure.network);
  }
}
