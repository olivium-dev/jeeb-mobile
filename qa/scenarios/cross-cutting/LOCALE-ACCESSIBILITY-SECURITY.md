# Locale, accessibility, security, and performance scenarios

> Suite result: **NOT RUN**

> Owner: Mobile QA + Security/Accessibility specialists where named
> Last verified: Never
> Source / AC: [semantic-ID guardrail](../../../docs/build-out/41_GUARDRAILS_TESTING.md),
> current l10n/accessibility/security code, workspace locked policies, and
> affected feature scenarios

Every ID below is an individual record under the
[shared record contract](../RECORD-CONTRACT.md). Preconditions are the
[pre-run checklist](../checklists/PRE-RUN.md) plus the scenario clause. Execute
the row with the [per-scenario checklist](../checklists/PER-SCENARIO.md); restore
device/app settings, clean isolated data, and apply the
[evidence checklist](../checklists/EVIDENCE.md).

| ID | Priority / gate | Scenario | Required outcome |
|---|---|---|---|
| JMS-XFN-001 | P0 / Regression | Switch English ↔ Arabic and relaunch | Selection persists; language screen and every shell target stay reachable |
| JMS-XFN-002 | P0 / Regression | RTL full-screen review with LTR islands | Layout mirrors correctly while phone, OTP, amount, ID, URL, timestamp, and coordinates remain readable |
| JMS-XFN-003 | P0 / Smoke | Semantic identifier audit | Every interactive/asserted element exports one stable screen-scoped ID; automation uses no coordinates or localized text |
| JMS-XFN-004 | P0 / RC | TalkBack customer request → offer → receipt | Complete critical customer path with correct focus, roles, labels, errors, live regions, and no trap |
| JMS-XFN-005 | P0 / RC | TalkBack Jeeber KYC → offer → delivery | Complete critical Jeeber path; upload/status/countdown controls are understandable and operable |
| JMS-XFN-006 | P0 / RC | VoiceOver customer and Jeeber critical paths | Same observable outcomes and privacy constraints as Android accessibility run |
| JMS-XFN-007 | P1 / Regression | 200% text, compact/large/tablet/landscape, keyboard | No clipped CTA, hidden error, overlap, unreachable footer, or state loss |
| JMS-XFN-008 | P1 / Regression | Contrast, touch targets, reduced motion, focus order | Minimum platform target size, sufficient contrast, logical order, and non-motion alternative pass |
| JMS-XFN-009 | P0 / RC | Release hardening and configuration scan | Dev seams/super-login/route pins are inert; no secrets; HTTPS policy holds; no communication with forbidden host |
| JMS-XFN-010 | P0 / RC | Cross-account object authorization | Customer/Jeeber B cannot open or mutate A’s request, offer, delivery, chat, KYC, dispute, or support object |
| JMS-XFN-011 | P0 / RC | KYC/chat/dispute attachment abuse | Invalid type, size, path, metadata, and interrupted upload are rejected; temp files are cleaned; no executable content opens |
| JMS-XFN-012 | P1 / RC | Startup, scroll, memory, battery, storage, upgrade | Agreed budgets pass on flagship and mid-range devices; no crash/ANR/resource leak; exact RC artifact is measured |

## Accessibility checklist

- [ ] 44×44 pt minimum iOS target and 48×48 dp minimum Android target.
- [ ] Screen title/root announced once.
- [ ] Focus order follows visual/task order in LTR and RTL.
- [ ] Fields have persistent localized label, role, state, error, and required status.
- [ ] Countdown/status updates use a non-spammy live-region strategy.
- [ ] Icons and color-only states have text/semantic equivalents.
- [ ] Keyboard never hides focused input or primary recovery action.
- [ ] Dynamic text and screen readers can finish the full COD journey.

## Security and privacy checklist

- [ ] Only synthetic adult data is used.
- [ ] Tokens, OTPs, device tokens, route parameters, and private text are absent from logs and evidence.
- [ ] Object IDs are authorization-tested across accounts using aliases, never copied real IDs.
- [ ] Release ignores every development-only seam.
- [ ] No electronic payment, gateway settlement, or money-moving refund path appears.
- [ ] No environment request reaches the forbidden host named in workspace policy.
