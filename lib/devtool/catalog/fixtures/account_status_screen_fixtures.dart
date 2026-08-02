// Shared dev-only fixtures for `AccountStatusScreen` (JM-066, D5).
//
// ONE source of truth for the two dev surfaces that mock this screen:
//
//   * the designer-facing Screen Catalog entry
//     (`lib/devtool/catalog/entries/batch_01_entries.dart`), and
//   * the engineer-facing preview section at the bottom of
//     `lib/features/account_status/presentation/account_status_screen.dart`.
//
// The catalog owned two private fakes (`_FixedAccountStatusRepository`,
// `_FailingAccountStatusRepository`) plus two inline `AccountStatusInfo`
// literals. [AccountStatusScreenFakeRepository],
// [AccountStatusScreenFailingRepository], [accountStatusScreenSuspended] and
// [accountStatusScreenLockedWithReason] ARE those four, moved here value for
// value — nothing changed, so the designer sees exactly what was signed off.
// [AccountStatusScreenPendingRepository] and
// [accountStatusScreenLockedLongReason] are new and preview-only. The catalog
// does not use them, which is the normal shape for this directory: a fixture
// file is the union of what both surfaces need, not the intersection.
//
// Everything here is a LOCAL fake. `AccountStatusScreen` takes a `repository:`
// constructor seam (40_GUARDRAILS_ARCH §5.4), so neither surface reaches
// `_resolveRepository()`'s `sl<AccountStatusRepository>()` / `sl<Dio>()`
// branches and no `DioAccountStatusRepository` is ever built: network-free by
// construction, not merely by the `CatalogNetworkGuard` both hosts install.
//
// One seam is NOT covered by that, and both surfaces inherit it: the screen's
// `account_status_signout_cta` calls `LogoutDeleteConfirmSheet.show(context,
// mode: both)` with no terminator argument, and the sheet self-provides a
// `DioAccountSessionTerminator(resolveGatewayDio(), AuthTokenStore())` when DI
// has nothing registered. Opening the sheet is inert (`_terminator` is `late`,
// so it is not built until a confirm CTA fires); CONFIRMING inside a dev
// surface is what the guard's POST rejection is there to catch. See the preview
// section's prose.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which is not reachable from any shipping
// code path.

import 'dart:async';

import 'package:jeeb_mobile/features/account_status/domain/account_status.dart';
import 'package:jeeb_mobile/features/account_status/domain/account_status_repository.dart';

/// Canned [AccountStatusRepository] — `fetchStatus()` resolves immediately to
/// [info]. No Dio, no GetIt, no network.
///
/// `const`-constructible so the catalog can keep building
/// `const AccountStatusScreen(repository: ...)`.
class AccountStatusScreenFakeRepository implements AccountStatusRepository {
  const AccountStatusScreenFakeRepository(this.info);

  /// What `GET /v1/users/me` resolves to, already mapped to the domain model.
  final AccountStatusInfo info;

  @override
  Future<AccountStatusInfo> fetchStatus() async => info;
}

/// A read that fails with a typed [AccountStatusFailure], which is how the live
/// repository fails — not a null and not a `suspended` default.
///
/// Drives the cubit's `failed` branch. The specific value does NOT pick the
/// copy: `AccountStatusL10n.loadError` is one string for all three failures, so
/// `network`, `unauthorized` and `unknown` render identically. The parameter
/// exists so a fixture can still SAY which failure it means.
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
///
/// `AccountStatusCubit.load()` emits `loading` and only leaves it when the
/// future completes, and the cubit's re-entry guard (`status != initial`) means
/// nothing else will move it — so this is the only way to look at the cold-entry
/// spinner without a real slow connection.
class AccountStatusScreenPendingRepository implements AccountStatusRepository {
  const AccountStatusScreenPendingRepository();

  @override
  Future<AccountStatusInfo> fetchStatus() =>
      Completer<AccountStatusInfo>().future;
}

/// The catalog's `Suspended` state: blocked, with NO server-supplied reason.
///
/// The closest thing this screen has to an empty state — there is no fifth
/// `empty` status (a blocked account always resolves to an [AccountStatusInfo])
/// and `reason` is the only optional field on it. With `reason: null` the body
/// falls back to `AccountStatusL10n.defaultReason`, so this is also the ONLY
/// loaded rendering whose reason line is localized.
const AccountStatusInfo accountStatusScreenSuspended =
    AccountStatusInfo(value: AccountStatusValue.suspended);

/// The server reason the catalog's `Locked — server reason` state carries.
///
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
///
/// Not invented length: `statusReason` is free text written by whoever actioned
/// the block, it is rendered VERBATIM (`serverReason ?? copy.defaultReason`),
/// and the body that renders it is a non-scrolling `Column`. A compliance hold
/// written as a short paragraph — what a human agent actually types — is the
/// ordinary payload that decides whether the two exit CTAs stay on screen.
///
/// English on purpose. Server text is not localized, so in an Arabic build this
/// latin paragraph is laid out inside an RTL `Text` — which is the other thing
/// the matrixed preview of this fixture is for.
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
