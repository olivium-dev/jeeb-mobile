/// PURE Dart domain model for `account-status` (JM-066, D5). No Flutter / Dio /
/// GetIt imports (40_GUARDRAILS_ARCH §1).
///
/// The account `status` surfaced by `GET /users/me` (U1 — 42_GUARDRAILS_MOCK
/// W-1 FLOOR) is the D5 enum `active | pending | suspended | locked | deleted`.
/// The router's [AccountStatusGate] forces `/account-status` only for the two
/// *blocked* states (`suspended`, `locked`); this screen renders WHICH of the
/// two it is so the banner + reason copy match (the AC's "status banner +
/// reason"). Any non-blocked / unknown wire value degrades to [suspended] —
/// the screen is, by gate contract, only ever shown for a blocked account, so a
/// missing/garbled status must still render a coherent blocked body (R-F).
enum AccountStatusValue {
  /// Account temporarily suspended (e.g. policy review). Reachable again after
  /// support resolves it — the support CTA is the primary action.
  suspended,

  /// Account locked (e.g. security hold). Same exits as [suspended]; the copy
  /// distinguishes the reason.
  locked;

  /// Maps the D5 `status` wire string to a blocked-state value. Only the two
  /// blocked states are modelled here; everything else (active/pending/deleted/
  /// null/garbage) collapses to [suspended] because the screen is only ever
  /// rendered behind the blocked-account gate (R-F — never crash on an
  /// unexpected status, render a coherent blocked body).
  static AccountStatusValue fromWire(String? status) {
    switch (status?.trim().toLowerCase()) {
      case 'locked':
        return AccountStatusValue.locked;
      case 'suspended':
        return AccountStatusValue.suspended;
      default:
        return AccountStatusValue.suspended;
    }
  }
}

/// The resolved account-status snapshot the screen renders. Carries the blocked
/// state + an optional server-supplied human reason (D5/D76 — surfaced verbatim
/// when present; the screen falls back to localized per-state copy when null).
class AccountStatusInfo {
  const AccountStatusInfo({required this.value, this.reason});

  final AccountStatusValue value;

  /// Optional free-text reason from the backend (`statusReason` / `reason`),
  /// e.g. "Multiple chargeback disputes". Null → use localized per-state copy.
  final String? reason;
}
