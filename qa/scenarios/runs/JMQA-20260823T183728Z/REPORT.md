# Jeeb Mobile physical Android QA report

> Run: JMQA-20260823T183728Z
>
> Execution window: 2026-08-23 18:37:28–19:10:57 UTC
>
> Physical visible wave: 2026-08-23 19:03:48–19:10:57 UTC
>
> Status: EXECUTION AND EVIDENCE REVIEW COMPLETE
>
> Verdict: **NO-GO**

## Executive summary

The Jeeb app was visibly exercised on a **physical Samsung Galaxy A33**. The
corrective wave captured 21 checkpoints across 17 screen/state surfaces,
including delivery history and details, active and completed chats, profile,
settings, notification preferences and inbox, language, earnings, customer and
Jeeber request surfaces, and approved/rejected KYC states.

The direct answer to the reachability question is therefore:

- **Delivery:** reached on this physical device — Active, Completed, and
  Cancelled lists plus one active and one completed detail.
- **Chat:** reached on this physical device — one current-delivery chat and one
  completed-delivery chat. No message was sent.
- **KYC:** status surfaces reached on this physical device — Approved via the
  canonical KYC URI and final Rejected via a crafted direct URI. The KYC form,
  upload, submission, review, and resubmission paths were not executed.

> **Authentication provenance correction:** this was not a normally
> authenticated release session. The package was first prepared through the
> debug-only **Super Login Plus** path, and the resulting session survived an
> in-place update to the release-flavor APK. Super Login Plus was not reopened
> during the visible wave, but that wave depended on its session. Authentication,
> selected-role, KYC-state, and full happy-path sign-off are therefore invalid or
> unproven. See [AUTH-PROVENANCE.md](AUTH-PROVENANCE.md).

The run found two exact scenario failures: delivery/chat lifecycle state
divergence and missing physical automation semantics. It also found two further
P0 product defects—an illegal Start-delivery affordance on a terminal delivery
and a KYC terminal route that contradicts the visibly Approved KYC surface. Those
two exact JMS scenarios remain BLOCKED because the required transition rejection
and authoritative server-state change/read-back were deliberately not executed.
Contradictory online/offline copy and a completed screen still titled Active
delivery were also confirmed. Delivery-, role-, and KYC-dependent findings must
be reproduced after a clean normal login before release closure.

No complete happy-path JMS scenario earns PASS under the scenario evidence
contract: paired-device/server proof and safe mutation fixtures were not
available. Final exact-ID accounting is **0 PASS, 2 FAIL, 9 BLOCKED, and 83 NOT
RUN**. Screen reach is reported separately and is not inflated into a PASS.

## What physically happened

The run had two phases:

1. **Automated attachment diagnostic.** Maestro 2.0.5 rejected the ADB-online
   physical serial, and the native hierarchy did not expose the expected Flutter
   semantic IDs. This phase stopped with zero UI actions.
2. **Corrective visible exploratory wave.** The A33 was then driven manually on
   screen using bounded navigation taps. The app visibly changed through the 21
   retained checkpoints. Known mutating/destructive actions were never pressed.

The complete sanitized sequence is in
[MANUAL-ACTION-LEDGER.md](MANUAL-ACTION-LEDGER.md). Raw screenshots are private
because they contain synthetic names, coordinates, message content, or entity
identifiers.

## Physical screen coverage

| Area | Reached states/surfaces | What was deliberately not done |
|---|---|---|
| Shell | All five additive tabs: My Requests, Deliveries, Requests, Earnings, Profile | No availability toggle, request creation, or shell-state reset |
| Delivery history | Active, Completed, Cancelled | No re-broadcast, cancellation, tracking, or new delivery |
| Delivery detail | One At-door item; one Done item | No proof, note, OTP, completion, Maps, COD acknowledgment, rating, or receipt action |
| Chat | Chat from the At-door item; chat from the Done item | No typing, attachment, send, receiver assertion, or push assertion |
| Profile/settings | Profile, Settings, notification preferences, Language | No field, toggle, locale, consent, logout, or delete mutation |
| Operations | Earnings and notification inbox | No export, wallet action, notification read, or target navigation |
| KYC | Approved canonical status; crafted final-rejection route | No onboarding, media, submission, polling, appeal, or provider action |

## Final exact scenario results

| Scenario | Final result | Decisive evidence or blocker |
|---|---|---|
| JMS-DEL-001 | **FAIL** | The same current delivery was At door in dashboard/detail and In transit in Chat. DEF-001. |
| JMS-DEL-004 | BLOCKED | DEF-002 proves an illegal terminal UI affordance, but the exact scenario requires executing and verifying transition rejection; no action was invoked. |
| JMS-KYC-004 | BLOCKED | The Super Login Plus–seeded session invalidates authoritative KYC-state sign-off; controlled server state change, foreground/cold-start refresh, and read-back were also not executed. DEF-003 is retained as a UI/source finding pending clean-login reproduction. |
| JMS-XFN-003 | **FAIL** | Stable physical semantic IDs were not available; repeatable automation required by the scenario was impossible. DEF-006. |
| JMS-AUTH-003 | BLOCKED | The stored session came from Super Login Plus, not normal phone/OTP authentication; no clean-login cold start or server-authoritative read-back occurred. |
| JMS-DEL-002 | BLOCKED | Chat rendered, but no harmless nonce was sent and no receiver-side proof exists. |
| JMS-OPS-001 | BLOCKED | Inbox rendered, but no item/read/badge/target-route assertion occurred. |
| JMS-OPS-002 | BLOCKED | Profile/settings rendered, but exact view/update, masking, and read-back variants were incomplete. |
| JMS-OPS-007 | BLOCKED | Several settings targets rendered, but every canonical row/back-stack variant was not exercised. |
| JMS-CLR-006 | BLOCKED | The Privacy & analytics heading rendered without an analytics/consent control in this configuration. GATE-001. |
| JMS-XFN-001 | BLOCKED | Language rendered, but English↔Arabic switch, relaunch, persistence, and reachability were not executed. |

Every other JMS ID remains NOT RUN. The suite source files remain unchanged at
NOT RUN; observed outcomes live only in this run folder.

## Ranked product and gate findings

| ID | Priority | Finding | Release impact |
|---|---|---|---|
| DEF-001 | P0 | At-door delivery appears as In transit with Start delivery in Chat. | Lifecycle and actor views cannot be trusted to agree. |
| DEF-002 | P0 | A terminal Delivered chat exposes Start delivery. | User is offered an illegal/out-of-order action; backend behavior remains untested. |
| DEF-003 | P0 | A session shown as Approved can render final KYC rejection through a crafted deep link. | The observed terminal identity UI is route-driven; authoritative account state was not proven. |
| DEF-006 | P0 gate | Release-flavor UI lacks usable physical automation semantics. | Repeatable ID-only physical regression and accessibility audit are blocked. |
| GATE-003 | P0 evidence gate | The visible wave used a Super Login Plus–seeded session preserved across an in-place release update. | Authentication, role, KYC, and full happy-path sign-off are invalid or unproven. |
| GATE-002 | P0 policy review | Top-up/refund wording and a Top up KYC entry point are visible. | Must be reconciled with COD-only policy; no gateway call or money movement was observed. |
| DEF-004 | P1 | One dashboard frame says both offline and online. | Connectivity/availability recovery instructions are contradictory. |
| GATE-001 | P1 gate | Analytics heading has no consent/control surface in this configuration. | Clarity privacy scenario cannot be completed or classified. |
| DEF-005 | P2 | Done delivery is titled Active delivery. | Terminal state is mislabeled. |

Detailed reproduction, expected/actual behavior, source correlation, and fix
verification are in [DEFECTS.md](DEFECTS.md).

## COD-only guardrail result

The active-delivery detail explicitly instructed the Jeeber to collect cash on
delivery, and Earnings said the cash is paid directly rather than through Jeeb.
Those observations align with direct COD.

The run did **not** exercise a card, bank, checkout, settlement, refund, wallet,
or Top up action. Static artifact/source review found no electronic-payment or
refund client and no forbidden destination. The visible strings “Top-ups,
refunds, and balance updates” and “Top up” remain a policy-review item: internal
Jeeber fee/accounting display can be legitimate, but it must not become an
electronic customer-payment, gateway-settlement, or fake-refund path. This
report does not claim such a network path was contacted.

## Clarity and privacy

- The installed Settings screen displayed a Privacy & analytics heading but no
  visible analytics disclosure, status, or consent control.
- Source renders the analytics card only when the Clarity scope reports itself
  available. This run cannot distinguish intentional unavailability from an
  initialization/configuration failure.
- No Clarity consent was changed, no dashboard session was correlated, and no
  processed delivery/chat/KYC heatmap is claimed.
- All 21 screenshots are PRIVATE-ONLY. They include synthetic identity text,
  precise delivery coordinates, raw entity references, or chat content.
- The retained text-log scan found zero JWT-like strings, authorization headers,
  email-like strings, forbidden-host strings, and payment-gateway markers.

## Runtime and evidence integrity

| Check | Result |
|---|---|
| Physical device | Samsung SM-A336B, Android 16/API 36, authorized |
| App process | PID `5444` remained stable; no app restart during visible wave |
| Visible checkpoints | 21, spanning 17 screen/state surfaces |
| Fatal/ANR/Flutter/unhandled scan | 0 / 0 / 0 / 0 |
| Package crash/ANR exit records | 0 / 0 |
| Final observed PSS/RSS/Swap PSS | 239,283 / 286,251 / 36,295 KB; one sample, not a leak verdict |
| Raw log lines | 162 |
| Screenshot manifest entries | 21 SHA-256 records |
| Cleanup | No product state changed; final screen returned to safe Requests dashboard |

Material raw-artifact hashes:

- bounded visible log: `9b75afa408f266489b24aeab3624811385f810bbd1bd4b4170c5495661380a7a`
- package exit record: `9fed892a6b11b70413d77bee74e0d10dd7ad81c4931d2324aba7ae7ecb5cfe1e`
- final memory snapshot: `b96094784ae8cb179a56806945a87ed2c30c57c187b8f42917864c830edc32e9`

The sanitized counts, memory observation, privacy scan, hashes, and retention
record are collected in [LOG-SUMMARY.md](LOG-SUMMARY.md).

## Build identity

| Field | Observed |
|---|---|
| Package | `app.jeeb.mobile.clarityqa` |
| Version | `1.0.0-clarityqa`, code 1 |
| APK SHA-256 | `9e4f63ca4e78db06508fbf24302144312f7afb8d9abd24d8a272a8dc5345a938` |
| APK size | 79,016,148 bytes |
| Signer | Android debug certificate |
| Source context | Dirty worktree at `a88103459cb9c74df41b82a2675bd255a0b132fb`; exact clean commit not proven |
| Authentication provenance | Debug Super Login Plus session preserved into the release-flavor update; invalid for authentication, role, and KYC sign-off |
| Release eligibility | No — functional QA only; debug signing and unproven clean provenance |

## Device matrix

| Lane | State | Outcome |
|---|---|---|
| Physical A33 | Authorized and app foreground | Corrective visible run completed |
| Physical Samsung-2 | Connected but USB debugging unauthorized | BLOCKED until prompt is accepted on the phone |
| API-35 emulator | Could not boot because host storage was nearly full | BLOCKED until several GiB are safely freed |
| iOS | No target available | NOT RUN |

## Multi-agent execution and shared memory

Parallel agents worked on independent, read-only slices while one runner had
exclusive ownership of the A33:

| Slice | Responsibility | Outcome |
|---|---|---|
| Physical runner/coordinator | Exclusive device control, visible checkpoints, logs, safe final state | Completed |
| Guardrail/security review | COD-only, forbidden-host, environment, and mutation boundary | R0 navigation cleared; policy ambiguity retained |
| Scenario analyst | Map physical screenshots to JMS contracts and rank defects | Completed; coordinator corrected one visual tab-count misread after direct image review |
| Prior-evidence analyst | Separate prior APK evidence and identify historical conflicts | Completed; supporting context only |
| Coordinator review | Reinspect decisive screenshots/source, sanitize evidence, own final classifications | Completed; authentication provenance corrected and independently re-reviewed: APPROVE |

Shared memory was not an informal chat transcript. The coordinator-owned files
[RUN-STATE.md](RUN-STATE.md), [RESULTS.jsonl](RESULTS.jsonl),
[BLOCKERS.md](BLOCKERS.md), [LESSONS.md](LESSONS.md),
[EVIDENCE-INDEX.md](EVIDENCE-INDEX.md), and [TEST-DATA.md](TEST-DATA.md) formed
the synchronization record. Agents did not edit the working tree or control the
same device concurrently.

## Remaining blockers and next wave

1. With explicit approval, clear only the isolated Clarity QA package data,
   install the exact clean RC, and authenticate normally through phone/OTP with
   reserved customer and Jeeber fixtures. Super Login Plus must not appear
   anywhere in the new evidence chain.
2. Fix DEF-001/002 first and add terminal/status action gates driven by the same
   authoritative delivery state.
3. Add an authoritative KYC state gate to every direct/push terminal route and
   rerun none/pending/approved/rejected/resubmit states.
4. Provide stable release-test semantics and repair physical harness attachment;
   coordinate navigation cannot be a release regression strategy.
5. Accept USB debugging on the second Samsung to enable parallel customer and
   Jeeber roles.
6. Freeze isolated synthetic accounts/deliveries/chat/KYC fixtures and cleanup
   ownership before any R2/R3 write.
7. Supply an exact clean, immutable RC artifact; the debug-signed clarityqa build
   cannot receive release sign-off.
8. Resolve Clarity availability/consent and COD top-up/refund wording before the
   privacy and policy gates are rerun.
9. Free sufficient host space and restore the API-35 emulator lane.

## Final verdict

**NO-GO.** Physical Android testing did happen and it reached delivery, chat,
and KYC surfaces, but the session was seeded through Super Login Plus before the
release-flavor update. The run remained non-mutating and crash/ANR clean, and its
physical reach evidence remains useful. Normal authentication, role correctness,
authoritative KYC state, full happy paths, paired-device message and delivery
proof, KYC submission, COD completion, push, Clarity correlation, and the
release-candidate matrix remain invalid or unproven.
