# Push, deep-link, and lifecycle scenarios

> Suite result: **NOT RUN**
> Native delivery requires separately authorized test transport and receiver-side evidence.

> Owner: Mobile QA + native-platform QA
> Last verified: Never
> Source / AC: [current router](../../../lib/core/router/app_router.dart), current
> notification deep-link map and transport code, and affected feature scenarios

Every ID below is an individual record under the
[shared record contract](../RECORD-CONTRACT.md). Preconditions are the
[pre-run checklist](../checklists/PRE-RUN.md) plus the Given clause. Execute the
row with the [per-scenario checklist](../checklists/PER-SCENARIO.md); prove the
receiver and final back stack, clean test token/inbox state, and apply the
[evidence checklist](../checklists/EVIDENCE.md).

| ID | Priority / gate | Given / When / Then | Required proof |
|---|---|---|---|
| JMS-PUSH-001 | P1 / Regression | Given notification permission is not determined, granted, denied, or revoked, when app requests/recovers, then UI and OS state agree without blocking core use. | OS permission screen + app preference read-back |
| JMS-PUSH-002 | P0 / RC | Given login, token refresh, logout, and account switch, when device-token lifecycle runs, then token is associated only with the current synthetic account and removed/rotated safely. | Backend registration read-back; no raw token in evidence |
| JMS-PUSH-003 | P0 / RC | Given app foreground with a target screen open, when matching chat/order push arrives, then duplicate system/banner noise is suppressed and content updates once. | Unique nonce at receiver + open-screen root |
| JMS-PUSH-004 | P0 / RC | Given app backgrounded, when a valid push arrives and is tapped, then exact canonical target opens once with correct back stack. | OS notification + target + back destination |
| JMS-PUSH-005 | P0 / RC | Given app terminated, when push is tapped before auth is ready, then intent is safely held, authentication/status gates run, and authorized target continues once. | Cold start timeline; no private flash; final target |
| JMS-PUSH-006 | P0 / Regression | Given offer, request, chat, delivery, KYC, rating, dispute, support, and wallet payload categories, when each is opened, then typed route mapping reaches only its allowed canonical target. | Category matrix + route evidence |
| JMS-PUSH-007 | P0 / RC | Given wrong account/capability, unapproved KYC, suspended status, expired/cancelled entity, or unauthorized ID, when link opens, then correct gate/fallback appears with no data leakage. | Negative route evidence + zero protected content |
| JMS-PUSH-008 | P0 / RC | Given duplicate, out-of-order, stale, malformed, unknown, or injected payload, when processed, then badge/content remain idempotent and unsafe routes are rejected. | Delivery count, badge count, error classification |
| JMS-PUSH-009 | P1 / Regression | Given notification inbox/preferences, when read state, pagination, preference change, and OS denial interact, then server/local states converge and Clarity consent is unchanged. | Preference + inbox read-back |
| JMS-PUSH-010 | P0 / RC | Given two devices/accounts, when producer action emits a push with a unique nonce, then the intended receiver—not sender logs alone—proves arrival, tap, target, and no duplicate. | Producer action + receiver OS/app evidence + timestamp correlation |

## Delivery matrix checklist

- [ ] Foreground app, target closed.
- [ ] Foreground app, same chat/order target open.
- [ ] Background app.
- [ ] Terminated app.
- [ ] Logged out and later authenticated.
- [ ] Wrong account/capability and KYC-gated account.
- [ ] English and Arabic payload/display.
- [ ] Permission granted, denied, and revoked in OS settings.
- [ ] Duplicate and out-of-order delivery.
- [ ] Android and iOS supported devices.

Do not claim native push from a seeded inbox or mock dispatch alone.

HTTPS domain ownership is a separate OS/store contract. Execute
[JMS-LINK-001](JMS-LINK-001-OS-APP-UNIVERSAL-LINKS.md); in-app push routing or
a custom-scheme link cannot substitute for Android App Link or iOS Universal
Link verification.
