# Parallel-agent ownership and shared-memory ledger

## Coordination rule

Agents work in disjoint write scopes. One coordinator owns classification and
this run record; service/mobile agents publish sanitized facts and test results
but cannot award a JMS PASS. Read-only reviewers may inspect any scope. No agent
may revert another agent's changes or expose provider/signing material.

## Current workstreams

| Workstream | Exclusive ownership | Snapshot state | Shared-memory output |
|---|---|---|---|
| Release coordinator | Cross-workstream sequencing and GO/NO-GO | IN PROGRESS / NO-GO | Reconciles artifact, staging, store, device, and scenario evidence |
| Mobile identity/Firebase | Android/iOS identity, protected Firebase injection, release contract | COMPLETE | `com.olivium.jeeb`; `jeeb-5a293`; canonical app-registration IDs |
| Android release artifact | Signing, forced-clean AAB build and inspection | CURRENT ARTIFACT PASS / UPLOAD HELD | SHA-256 `4586571b76cd6f952bfa037d04f712076bbfe693ae4c2be70f47c534c48bf62b`; refreshed Firebase/Maps and zero Super Login/Dev Tool binary surface |
| iOS Maps/signing | Protected Maps key, App ID capabilities, forced-clean archive/export/validation | CURRENT ARTIFACT PASS / UPLOAD HELD | SHA-256 `eeebd0e2fa25aca08a78b308546660f2305ec2156c6f589ed75c08c8e6e7ef94`; branded launch screen, strict signing/entitlements/config/forbidden-surface inspection and Apple validation green |
| Mobile source regression | Exact source suite and realtime compose boundary | COMPLETE | 7,868 passed, 66 intentionally skipped, 0 failed; empty/`new` compose IDs cause no realtime request |
| Mobile source lineage | Classify the shared dirty tree, freeze an immutable revision, independent release review | AUDITED / RECONSTRUCTION REQUIRED | At `a8810345`: 60 staged + 92 unstaged tracked, 19 collisions = 133 unique changed paths, plus 245 untracked; current index is incoherent and must not be committed; reconstruct scoped PRs in clean worktrees |
| Staging gateway/realtime/voice | Gateway/provider/WSS/edge source and approved deployment | PRS OPEN / NOT LIVE | Infra #26, gateway #523, and OTP #27 head `29ff7af` are approved/CI-green; realtime #14 has one isolated writer on three P1/one P2; voice #27 has one isolated writer on the proven full-Spec rollback P1 |
| Twilio secret rotation | Jeeb-scoped restricted credential, consumers, canary, legacy revocation | IN PROGRESS / LIVE OTP BLOCKED | Protected `JEEB_*` installation fact only; never credential values |
| Scenario report reconciliation | `qa/scenarios/**` only | CURRENT THROUGH 15:23 UTC | Exact scenario queue, source-current artifact hashes, source-lineage/Firebase-key hardening and disposition, exact-head PR reviews/remediation state, evidence rules, blockers, and append-only corrections |
| Android physical runner A33 | A33 only after DEVICE-READY | WAITING | Exact store build, normal-OTP actions, screenshots/logs, cleanup |
| Android physical runner S24 | S24 only after USB authorization | BLOCKED | Receiver-side paired evidence after barrier release |
| iOS physical runner | Reserved iPhone only after it is online | BLOCKED | TestFlight, APNs, Universal Link, VoiceOver/device evidence |

## Durable shared memory

| Record | Write rule | Purpose |
|---|---|---|
| [REPORT.md](REPORT.md) | Coordinator replaces the current snapshot after reconciliation | Human-readable status, exact artifacts, run queue, and verdict rubric |
| [TEST-LOG.md](TEST-LOG.md) | Append only; corrections point to the superseded observation | Chronological evidence without rewriting history |
| [DATA.json](DATA.json) | Historical objects remain; new facts append as superseding observations | Machine-readable provenance and current-state selection |
| [BLOCKERS.md](BLOCKERS.md) | Coordinator closes/supersedes only with cited evidence | One live stop list with required closure |
| [CHECKLIST.md](CHECKLIST.md) | Checked only from retained evidence for this exact build/deploy | Barrier and execution control |
| Per-scenario copied record | One scenario runner, then coordinator review | Exact Given/When/Then, device, evidence, result, and cleanup |

Chat messages and agent summaries are transport, not evidence. A fact becomes
authoritative only after it is reconciled into these records without secrets.

## Synchronization barriers

| Barrier | Participants | Entry condition | Release condition | Current state |
|---|---|---|---|---|
| STG-LIVE | Gateway, realtime, voice, OTP, edge, coordinator | Immutable candidates and protected configuration ready | Fresh public probes close OTP, bypass/demo, voice, WSS, Firebase, AASA, and asset links; rollback proof retained | BLOCKED |
| STORE-DELIVERY | Android, iOS, coordinator | STG-LIVE green and exact artifact hashes frozen | Play/TestFlight processing complete and store installs match recorded build provenance | NOT STARTED |
| DEVICE-READY | A33, S24, iPhone runners | Store delivery complete; keepers paused; device baselines recorded | A33/S24 authorized, iPhone online, clean installs and permissions recorded | BLOCKED |
| PERSONA-READY | Customer/Jeeber runners, fixture owner | DEVICE-READY green | Both normal-OTP sessions and authoritative role/KYC/before-state agree | NOT STARTED |
| PAIRED-ACTION | Customer runner, Jeeber runner, server observer | PERSONA-READY green and shared nonce assigned | Sender, receiver, and server acknowledge each transition before next mutation | NOT STARTED |
| CLEANUP-REVIEW | All runners, privacy reviewer, coordinator | Scenario wave stopped or completed | Synthetic graph reset, final read-back green, evidence redacted/scanned, exact IDs classified | NOT STARTED |

If a participant misses a barrier, peers wait; they do not create substitute
local state. After timeout or unknown result, the server observer reconciles
state before any runner retries. This prevents duplicate offers, messages,
delivery transitions, OTP consumption, receipts, and ratings.

## Conflict-resolution order

1. Locked workspace policy.
2. Store-delivered artifact identity and hash.
3. Fresh public staging probe and authoritative server read-back.
4. Receiver-side physical evidence.
5. Source/unit/contract evidence.
6. Historical diagnostics.

A lower layer cannot override a higher layer. In particular, green source tests
cannot override failing live staging, and an earlier Super Login Plus session
cannot establish normal-auth, role, KYC, or functional release evidence.
