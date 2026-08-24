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
| Android release artifact | Signing, forced-clean AAB build and inspection | HISTORICAL ARTIFACT PASS / UPLOAD HELD | SHA-256 `4586571b76cd6f952bfa037d04f712076bbfe693ae4c2be70f47c534c48bf62b`; predates reconstructed head and must be rebuilt after independent review |
| iOS Maps/signing | Protected Maps key, App ID capabilities, forced-clean archive/export/validation | HISTORICAL ARTIFACT PASS / UPLOAD HELD | SHA-256 `eeebd0e2fa25aca08a78b308546660f2305ec2156c6f589ed75c08c8e6e7ef94`; predates reconstructed head and must be rebuilt after independent review |
| Mobile source regression | Exact source suite, credential/WSS boundary, analyzer, protected-config, and workflow contracts | REMOTE CI COMPLETE / REVIEW PENDING | Source commit `e07d4542`: 7,882 passed, 66 intentionally skipped, 0 failed; PR #276 validation head `c2b907485` passes all eight reported remote checks, including Android/iOS release contracts and the 24m14s coverage workflow |
| Mobile source lineage | Preserve historical audit, freeze coherent revision, reconcile main, obtain exact-head review | RECONSTRUCTED / REMOTE GREEN / REVIEW PENDING | Historical 188-file selection → `e208a4c8`; main `0c26c159` reconciled; `e07d4542` source diff 194 files, +12,392/-4,510; source/CI corrections pushed through `c2b907485`; no merge to main |
| Mobile dev Firebase | Protected ephemeral configuration and CI workflow inputs | CONFIGURED / VALUES NOT EXPOSED | Four named dev Actions secrets installed; names/timestamps only read back; real configs absent; wrapper cleanup passes on success/failure |
| Staging gateway/realtime/voice | Gateway/provider/WSS/edge source and safe deployment | PRS OPEN / NOT LIVE | Infra #26 reviewed/green; least-privilege Cloudflare Worker secret metadata present; gateway bootstrap local; realtime `4959d9e` has 2 P1 CR; OTP `29ff7af` and voice `6509c840` are test-green but CAS-race approval is superseded; binding two-phase rollout and fresh public probes required |
| Twilio secret rotation | Jeeb-scoped restricted credential, consumers, canary, legacy revocation | INPUT READY / LIVE OTP BLOCKED | Exactly one owner-controlled Verified Caller ID was normalized/validated in memory and installed by stdin as the sole protected SMS canary secret; metadata count 1, no value retained, and no SMS sent |
| Scenario report reconciliation | `qa/scenarios/**` only | CURRENT THROUGH 18:37 UTC | Exact-head mobile CI, Cloudflare access-only closure, corrected HTTP/TLS probes, iPhone/S24 reachability, protected SMS canary input, and append-only corrections |
| Android physical runner A33 | A33 only after DEVICE-READY | WAITING | Exact store build, normal-OTP actions, screenshots/logs, cleanup |
| Android physical runner S24 | S24 only after USB authorization | BLOCKED | Receiver-side paired evidence after barrier release |
| iOS physical runner | Reserved iPhone after store delivery | REACHABLE / WAITING FOR TESTFLIGHT | The phone is reachable; no number was read or exposed, no candidate is installed, and no physical scenario action occurred |

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
| STG-LIVE | Gateway, realtime, voice, OTP, edge, coordinator | Engine API version-CAS recovery implemented, tested, and approved across gateway/realtime/OTP/voice; least-privilege Cloudflare access present; edge configuration ready; physical SMS canary recipient ready | Binding two-phase gateway/realtime/edge sequence completes; fresh public probes close OTP, bypass/demo, voice, WSS, Firebase, AASA, and asset links; recovery proof retained | BLOCKED |
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
