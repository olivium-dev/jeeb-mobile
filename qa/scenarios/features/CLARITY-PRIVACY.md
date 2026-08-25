# Microsoft Clarity and privacy scenarios

> Suite result: **NOT RUN**
> Project settings and Microsoft-side behavior require authorized administrator evidence.

> Owner: Mobile QA + Privacy reviewer + Clarity administrator
> Last verified: Never
> Source / AC: [Clarity policy](../../../docs/observability/microsoft-clarity.md),
> current controller/consent/observer code, and focused tests named by the suite

Every ID below is an individual record under the
[shared record contract](../RECORD-CONTRACT.md). Preconditions are the
[pre-run checklist](../checklists/PRE-RUN.md) plus the Given clause. Execute the
row with the [per-scenario checklist](../checklists/PER-SCENARIO.md); verify
device and Microsoft-side state where required, restore approved test settings,
and apply the [evidence checklist](../checklists/EVIDENCE.md).

| ID | Priority / gate | Given / When / Then | Automation / evidence |
|---|---|---|---|
| JMS-CLR-001 | P0 / Smoke | Given debug, profile, test, CI, catalog, or disabled release config, when app starts, then Clarity never initializes or captures. | Policy/unit tests; process/network evidence |
| JMS-CLR-002 | P0 / RC | Given release build, when enabled/project/privacy defines are missing, malformed, or false, then capture remains off; all three valid defines are required. | Config policy tests; exact artifact build record |
| JMS-CLR-003 | P0 / RC | Given valid release config, when auth, current-process consent, or attached product context is absent, then SDK wrapper remains unmounted and no pre-gate capture occurs. | Controller/widget tests; bounded network observation |
| JMS-CLR-004 | P0 / RC | Given all four gates open, when consent is granted and a canonical route changes, then capture starts and one new canonical page name is reported. | Physical synthetic run + Microsoft recording evidence |
| JMS-CLR-005 | P0 / RC | Given explicit denial, when app navigates or restarts, then denial persists and no capture starts. | Store/controller tests + device observation |
| JMS-CLR-006 | P0 / Regression | Given unknown, missing, corrupt, or unreadable consent storage, when app starts, then state is unknown/off and user gets a recoverable choice. | Consent-store tests; settings UI evidence |
| JMS-CLR-007 | P0 / RC | Given active capture, when user revokes, then in-memory gate closes immediately, analytics consent becomes false, pause is confirmed, and new interaction is absent. | Controller tests + bounded Microsoft-side absence check |
| JMS-CLR-008 | P0 / RC | Given a granted process or denied user, when the process restarts, then grant resets to unknown/off while denial remains denied. | Device cold restart + settings evidence |
| JMS-CLR-009 | P0 / RC | Given consented foreground capture, when detached/inactive/paused/hidden/resumed lifecycle transitions occur, then background capture pauses and resume re-evaluates every gate. | Lifecycle chain on real device; no duplicate session/page |
| JMS-CLR-010 | P0 / Regression | Given any known, dynamic, malformed, or private route input, when navigation is reported, then only the closed canonical name or unknown is sent; parameters, queries, extras, semantic IDs, and text never leave. | Navigator observer tests + sanitized SDK observation |
| JMS-CLR-011 | P0 / RC | Given synthetic content and Strict project masking, when playback/heatmap is processed, then app root remains masked, no unmask site exists, and no custom user/session ID, tags, events, or user text are sent. | Static privacy test + administrator screenshot + manual playback review |
| JMS-CLR-012 | P0 / RC | Given active or eligible capture, when logout, account deletion, terminal 401, account switch, administrator emergency stop, build kill switch, or unsupported OS occurs, then no cross-account or prohibited capture continues. | Controller/auth tests + two-account physical run + admin/build evidence |

## Mandatory execution matrix

- [ ] Android API 29–36 capture range and Android API 24–28 no-send range.
- [ ] iOS 15–18 capture range and iOS 14 no-send case.
- [ ] English and Arabic RTL with only synthetic screen content.
- [ ] Foreground, inactive, hidden, paused, detached, resume, warm start, cold start.
- [ ] Consent unknown, granted, denied, corrupt, revoke, storage failure.
- [ ] Grant applies ads consent false and analytics consent true.
- [ ] Revocation closes the in-memory gate even when SDK pause or persistent
      denial storage initially fails; visible recovery and bounded retry remain available.
- [ ] SDK or consent-storage failure never blocks app startup, authentication,
      logout, deletion, account status, or other account flows.
- [ ] Authenticated, logged out, terminal 401, deleted, switched account.
- [ ] Static dashboard screens, shell tabs, dynamic chat/order routes, and unknown route.
- [ ] The five internal shell tab surfaces currently remain the single canonical
      shell page; evidence must not claim separate tab heatmaps unless distinct
      canonical names are deliberately implemented later.
- [ ] Heatmap and recording processed on Microsoft side without visible PII.

## Release-owner and administrator approvals

- [ ] Privacy review approves disclosure, retention, Microsoft subprocessor
      treatment, and handling of minors/minor-use accounts.
- [ ] Google Play Data Safety accurately describes masked session recordings
      and interaction analytics.
- [ ] Apple App Privacy accurately describes masked session recordings and
      interaction analytics.
- [ ] Clarity project administrator confirms Strict masking.
- [ ] Clarity project administrator confirms the immediate emergency stop and
      supplies tested evidence of the stop procedure.
- [ ] Synthetic Android and iOS grant/capture/revoke/logout/account-switch
      validation is complete on the exact release candidate.
- [ ] If any approval is missing, the release keeps Clarity disabled; it is not
      represented as a Clarity-enabled GO.

## Evidence safety

- Never capture a real customer/Jeeber session, name, face, document, address,
  precise location, private message, phone, account ID, OTP, or token.
- Dashboard images must show masking and canonical screen names only and must be
  manually reviewed before versioning.
- A local route log proves app behavior only. Microsoft ingestion requires a
  separately processed recording/heatmap or equivalent administrator evidence.
- No project setting may be changed under a documentation-only task.
