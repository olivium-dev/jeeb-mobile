# Settings, notifications, profiles, support, and balance views

> Suite result: **NOT RUN**

> Owner: Mobile QA
> Last verified: Never
> Source / AC: [current router](../../../lib/core/router/app_router.dart), current
> settings/notification/profile/support code, and the JM flows named per row

Every ID below is an individual record under the
[shared record contract](../RECORD-CONTRACT.md). Preconditions are the
[pre-run checklist](../checklists/PRE-RUN.md) plus the Given clause. Execute the
row with the [per-scenario checklist](../checklists/PER-SCENARIO.md); read back
changed preferences/entities, reset isolated data, and apply the
[evidence checklist](../checklists/EVIDENCE.md).

| ID | Priority / gate | Persona / mutation | Given / When / Then | Source / automation | Required variants and evidence |
|---|---|---|---|---|---|
| JMS-OPS-001 | P0 / Regression | Authenticated user / R1 | Given seeded notifications, when inbox opens and an item is read, then badge/read state and target route agree without exposing another account. | jm-057 | Empty/loading/error; pagination; duplicate; role-specific item; receiver-side push split into PUSH suite |
| JMS-OPS-002 | P1 / Regression | Customer / R2 | Given a synthetic profile, when profile/settings fields are viewed or updated, then only allowed fields change and private data stays masked. | jm-035 | Missing typed route data; validation; offline; account switch; EN/AR |
| JMS-OPS-003 | P1 / Regression | Jeeber/customer / R0 | Given a public synthetic Jeeber profile, when reviews lists open, then totals, pagination, empty/error, and identity boundaries are correct. | jm-067, jm-068 | Own vs other profile; deleted reviewer; mixed locale; deep link |
| JMS-OPS-004 | P0 / Regression | Authenticated user / R0 | Given synthetic balance/activity data, when wallet, fee information, activity, and transaction detail open, then display matches server data and offers no electronic customer payment route. | jm-053–056 | Empty/error/offline; pending KYC; deep link; no card/amount-entry checkout; no PII in transaction detail |
| JMS-OPS-005 | P1 / Regression | Jeeber / R0 | Given completed synthetic jobs, when earnings opens, then cash-earned and server-provided platform-fee values reconcile without changing customer COD total. | jm-052 | Zero/large/fraction values; date range; locale; offline; no hard-coded fee assumption |
| JMS-OPS-006 | P0 / Regression | User needing help / R2 | Given a support-eligible state, when a synthetic ticket is created/opened, then one ticket and correct detail route appear without private evidence leakage. | jm-063 | Legacy route redirect; upload failure; dispute/KYC/account-status entry; duplicate submit |
| JMS-OPS-007 | P1 / Smoke | Authenticated user / R1 | Given Settings, when rows and back navigation are exercised, then each canonical target opens once and root/back-stack remain consistent. | Settings tests | Direct deep link; nested back; small screen; Clarity row off/on variants |
| JMS-OPS-008 | P1 / Regression | Customer / R2 | Given saved locations, when add/edit/delete is performed with synthetic addresses, then list/detail converge and precise data is excluded from evidence. | jm-049, jm-050 | Empty; duplicate label; unresolved address; offline; RTL coordinates; delete confirmation |
| JMS-OPS-009 | P1 / Regression | Authenticated user / R2 | Given notification preferences, when one preference changes, then server/local state persists and unrelated Clarity consent does not change. | jm-058 | Denied OS permission; timeout/rollback; account switch; EN/AR; independent toggles |
| JMS-OPS-010 | P0 / RC | Authorized tester / R0 | Given diagnostics access, when viewed/shared, then health is useful but secrets, tokens, exact private endpoints, account IDs, and user data are absent. | Focused tests | Release access control; offline; log export; secret scan; no forbidden host communication |

## Suite checklist

- [ ] Settings analytics consent and notification preferences remain independent.
- [ ] Wallet/earnings screens are treated as display/accounting features, not
      authorization for electronic customer payment.
- [ ] Profile, location, ticket, notification, and diagnostics evidence is sanitized.
- [ ] Legacy support route is tested only as redirect compatibility.
