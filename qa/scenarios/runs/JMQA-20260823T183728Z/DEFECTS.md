# Defects and gate findings

> Run: JMQA-20260823T183728Z
>
> Evidence source: corrective visible run on physical Samsung Galaxy A33
>
> Release disposition: **NO-GO**

Raw screenshots are private. Evidence references below point to the sanitized
checkpoint numbers in [MANUAL-ACTION-LEDGER.md](MANUAL-ACTION-LEDGER.md).

The visible wave inherited a session created through debug-only Super Login
Plus before an in-place release-flavor update. Physical UI observations remain
recorded, but authentication, selected role, authoritative KYC state, and full
happy-path sign-off are invalid or unproven. Role- and KYC-dependent findings
require clean normal-login reproduction. See
[AUTH-PROVENANCE.md](AUTH-PROVENANCE.md).

## DEF-001 — Delivery detail and chat disagree on live status

| Field | Value |
|---|---|
| Priority | P0 |
| Category | APP_DEFECT / state consistency |
| JMS mapping | JMS-DEL-001, JMS-DEL-003 |
| Evidence | Checkpoints 09, 11, 12 |
| Status | OPEN |

**Expected:** the same assigned delivery has one authoritative status across the
dashboard, active-delivery detail, and chat summary. At-door work must not be
presented as an earlier in-transit/start state.

**Actual:** the dashboard and active-delivery detail showed **At door**. Opening
Chat directly from that detail showed **In transit**, **Offer accepted**, and a
**Start delivery** action.

**Source correlation:** the chat route supplies `onStartActiveDelivery` based on
the viewer being a Jeeber, while the banner is gated by accepted conversation
phase and a winner, not by the delivery's authoritative lifecycle status
(`chat_detail_screen.dart:1765`, `chat_screen.dart:556`). This is a root-cause
candidate, not proof of the backend state.

**Required fix/verification:** resolve one canonical delivery status for the
chat header and action gate; then rerun the same entity on both customer and
Jeeber devices through AtDoor and Done with server read-back.

## DEF-002 — Completed chat still offers Start delivery

| Field | Value |
|---|---|
| Priority | P0 |
| Category | APP_DEFECT / illegal terminal action |
| JMS mapping | JMS-DEL-004 |
| Evidence | Checkpoints 15–16 |
| Status | OPEN |

**Expected:** a terminal Done/Delivered delivery cannot expose an initiation or
forward-transition action.

**Actual:** the completed-delivery detail showed Done and “Delivered
successfully”. Its Chat screen showed Delivered while still displaying **Offer
accepted** and **Start delivery**. The action was deliberately not pressed, so
this run does not claim that the backend would accept it.

**Source correlation:** the Jeeber callback is attached unconditionally by role
and the accepted banner paints Start delivery whenever that callback exists
(`chat_detail_screen.dart:1765`, `offer_accepted_banner.dart:64`).

**Required fix/verification:** suppress initiation/transition controls for all
terminal statuses and add a physical regression covering Done, Cancelled,
Failed, and escalated deliveries. Separately verify server rejection of crafted
terminal transitions.

## DEF-003 — Session shown as KYC-approved can render a rejection route

| Field | Value |
|---|---|
| Priority | P0 |
| Category | APP_DEFECT / state authority |
| JMS mapping | JMS-KYC-004; negative-path coverage related to JMS-KYC-005 |
| Evidence | Checkpoints 19–20 |
| Status | OPEN |

**Expected:** when the canonical KYC route visibly resolves a session to
Approved, a direct or push route must validate authoritative KYC state before
showing a contradictory final rejection. Stale or inapplicable routes must
redirect to the current canonical state.

**Actual:** `jeeb://profile/kyc` showed **You're approved**. Twenty-one seconds
later, without an in-wave account or KYC mutation, `jeeb://kyc/rejected`
displayed **Verification not approved**, a final-decision message, and Appeal
via support. Because the session was Super Login Plus–seeded, this proves a
contradictory route/UI state but not the account's authoritative KYC status.

**Source correlation:** the router constructs `KycRejectedScreen` directly with
no status redirect (`app_router.dart:1691`). That screen fetches status only to
enrich an optional reason and deliberately renders generic final-rejection copy
even when its fallback submission is non-rejected
(`kyc_rejected_screen.dart:47`).

**Required fix/verification:** put an authoritative status gate before terminal
KYC rendering, test every typed/deep/push route against none, pending, approved,
rejected, and resubmit-requested accounts, and prove support access without
showing a false decision. Reproduce from a clean install through normal OTP with
authoritative fixture read-back.

## DEF-004 — Availability screen says offline and online simultaneously

| Field | Value |
|---|---|
| Priority | P1 |
| Category | APP_DEFECT / contradictory recovery copy |
| JMS mapping | Observed risk against JMS-RES-001 and JMS-RES-008; exact fault scenarios remain NOT RUN |
| Evidence | Checkpoints 09, 14, 18, 21 |
| Status | OPEN |

**Expected:** the availability/empty state communicates one consistent network
and availability condition.

**Actual:** the dashboard headline said **You're offline** while the empty-state
body said **you're online** on the same frame.

**Source correlation:** the availability card derives Offline from live state,
while the no-requests body always uses an English localization that says the
Jeeber is online (`availability_card.dart:205`,
`jeeber_no_requests_view.dart:123`, `app_en.arb:5346`).

**Required fix/verification:** make the empty copy state-aware, then run the
controlled cold-offline, reconnect, Wi-Fi/cellular, and auto-offline variants.

## DEF-005 — Done delivery retains Active delivery title

| Field | Value |
|---|---|
| Priority | P2 |
| Category | APP_DEFECT / terminal labeling |
| JMS mapping | JMS-DEL-008 supporting observation |
| Evidence | Checkpoint 15 |
| Status | OPEN |

**Expected:** terminal detail uses a neutral or completed title consistent with
Done and “Delivered successfully”.

**Actual:** the title remained **Active delivery**.

**Source correlation:** `ActiveDeliveryJeeberScreen` always passes
`activeDeliveryTitle` to the top bar for loading, active, and terminal modes
(`active_delivery_jeeber_screen.dart:284`).

## DEF-006 — Physical release UI does not expose usable automation semantics

| Field | Value |
|---|---|
| Priority | P0 release gate |
| Category | APP_DEFECT / testability and accessibility |
| JMS mapping | JMS-XFN-003 |
| Evidence | EVD-009 plus the coordinate-only corrective wave |
| Status | OPEN |

**Expected:** every asserted/interactable element exposes one stable,
screen-scoped identifier so physical automation can use IDs rather than
coordinates or localized text.

**Actual:** Maestro 2.0.5 rejected the otherwise ADB-online serial, and the
bounded native hierarchy exposed only six generic nodes with zero matches for
`shell_tab_dashboard`. The corrective exploratory run therefore required visual
coordinate navigation and cannot serve as repeatable release automation.

**Required fix/verification:** expose Flutter semantics in the exact RC/test
artifact, repair the physical harness attachment, and rerun the ID-only audit.

## GATE-001 — Analytics/consent control is absent in this configuration

| Field | Value |
|---|---|
| Priority | P1 gate |
| Category | CONFIGURATION / FLOW |
| JMS mapping | JMS-CLR-006 |
| Evidence | Checkpoint 05 |
| Status | OPEN / not yet classified as a product defect |

Settings rendered a **Privacy & analytics** heading but no analytics status,
disclosure, or consent control. Source renders the card only when
`ClarityAnalyticsScope.available` is true (`settings_screen.dart:217`). The run
does not establish whether the adapter was intentionally unavailable or failed
to initialize, so JMS-CLR-006 remains blocked.

## GATE-002 — COD-only wording and wallet funding need owner confirmation

| Field | Value |
|---|---|
| Priority | P0 policy review |
| Category | CONTRACT / locked-policy review |
| JMS mapping | JMS-OPS-004, JMS-KYC-003, JMS-DEL-007/012 |
| Evidence | Checkpoints 06, 08, 19 |
| Status | OPEN / no network-policy breach proven |

The notification preference says **Top-ups, refunds, and balance updates**, and
the KYC surface shown as Approved exposes a **Top up** entry point. Internal
Jeeber wallet/fee accounting display is allowed by the scenario contract;
electronic customer
payment, gateway settlement, and money-moving refund paths are not. Static
review found no UPG/electronic-payment client and no related runtime marker in
the bounded log. Therefore this is a release-policy ambiguity to resolve, not a
claim that money moved or a forbidden service was contacted.

## GATE-003 — Authentication provenance is shortcut-seeded

| Field | Value |
|---|---|
| Priority | P0 evidence gate |
| Category | TEST_PROVENANCE |
| JMS mapping | JMS-AUTH-003, JMS-KYC-004, role selection, full happy path |
| Evidence | EVD-018 |
| Status | OPEN / clean rerun required |

The A33 package was first prepared through the debug Dev Tool and Super Login
Plus. Installing the release-flavor APK in place removed that launcher from the
binary but preserved its authenticated session. The visible wave did not reopen
Super Login Plus, yet depended on that session. Authentication, role, KYC, and
end-to-end sign-off are therefore invalid or unproven; physical screen reach and
bounded stability observations remain usable within their stated scope.

## Evidence-only privacy observations

- Delivery history displayed precise coordinate text.
- Earnings displayed a raw entity identifier.
- Chat showed private synthetic message content.

Those observations keep all 21 raw screenshots **PRIVATE-ONLY**. They are not
reproduced in the report or committed to the scenario folder.

## Inconclusive observation

Checkpoint 18 landed on the Jeeber dashboard after an attempted profile/detail
navigation. Because manual coordinates were required and the sequence was not
reproduced, it is not classified as an app defect. It must be rerun using stable
semantic identifiers after DEF-006 is fixed.
