# EXECUTION PLAN — 13 plans after the 18 owner decisions (2026-09-06, 07:10 UTC)

Reviewer: fresh Fable 5.1 principal. Inputs read in full: `CONFLICT-REVIEW.md` (C1–C20, waves 0–5, OD-0…OD-17),
`OWNER-DECISION-OPTIONS.md`, `PLAN-P01…P13.md`, and the recorded decisions in
`jeeb-mobile-worktrees/ux-api-errors/docs/ux-failure-states/DECISIONS.md`. Plan only — no repo file changed, no commit.
Wording in this file is forward-only-policy safe (no prior-state git verbs), so it can be committed under `docs/` later.

## 0b. Full-work continuation (2026-09-06, after the review-fix handoff)

The user subsequently instructed Codex to resume the **full work**, superseding §0a's restriction to the nine review regressions. Local continuation starts from `c5603c38` on the existing #335 branch. P12-A, P11, P08, P13, P06, P05, P07, P02 mobile and P03 mobile are being implemented with isolated file ownership and serialized localization/identifier handoffs; P04-B is tooling-only. The 35-minute CI limit and earlier nine regression fixes are preserved, not counted as new work.

See [the full continuation report](../reviews/FULL-WORK-RESUME-2026-09-06.md) for measured status. No device run is implied by source changes, fixtures or proxy tests. P09 S1.6 still gates P12-B deletion. Formal gateway/builder branches and integration require a fresh source check; offline preparation now exists in isolated cached snapshots (gateway `6679f6e`, builder `801ef01`) under workspace `full-resume-local/`. Those are not freshly verified remote heads. Deployment, migration, release, merge and upstream filing gates remain intact. No audit bypass.

Current root-session restrictions prevent GitHub access and Flutter's local test-server bind. Independently assigned lanes report only checks their tools actually executed; a root runner-start failure is not a test pass. Whole-program runtime/coverage, current CI and device acceptance remain pending. Changes must not be pushed or marked ready on the strength of historical checks.

## 0a. Prior execution amendment (2026-09-06 review-fix wave)

This section supersedes the historical 07:10 snapshot below and any conflicting old batch instructions. The latest stopped Claude workflow is the review-fix wave against PR335-REVIEW-050051d6 plus INVENTORY-REVIEW-2026-09-06, not a fresh execution of all P01–P13 work. Resume design → implementation → scoped verification → integration gate → factual handoff.

- Starting code head is `f9eaf63d`; the nine reviewed mobile regressions are the current implementation scope.
- OD-12's stage-test timeout is changed locally to 35 minutes; the resulting head still needs a green CI run. The existing coverage-job cap is unchanged.
- P01 v3 is the current, corrected onboarding plan, not parked pending v2 approval. Prepare its gateway/form-builder changes separately; deployment and the mobile route flip remain gated. The review adds owner choices about template versioning and the pre-existing vocabulary gate.
- P15 records the owner's wallet-independence ruling and replaces the binary rebaseline/mergemain question. Its dependency train is G0 → G1 → G2 → G3 → G4 → G5 → G6; no migration/deploy is authorized by this amendment.
- Proposed shared-file order is P01 gateway first, then P15 G0. The second lander reconciles Program/config/registry/OpenAPI and reruns all affected gates; a changed owner order must be recorded in both plans.
- N1 is withdrawn: no audit ignore, allowlist, or gate bypass. The security blocker remains until a verified upstream release/dependency/advisory path clears it; upstream filing is owner-gated.
- No claims below about live request states, deadlines, current CI or worktree cleanliness should be reused without fresh verification. The existing device queue is a plan, not evidence of a run.
- OD-0 `widen` puts P02/P03 mobile work on #335; their similarly named target-ref/validation branches belong to jeeb-gateway. P01's post-deploy flip remains separate.

## 0. Historical snapshot (verified live, 07:06–07:10 UTC; superseded by §0a)

| # | Fact | Consequence for this plan |
|---|---|---|
| L1 | PR #335 head is **`e212f8d3`** (6 commits: the 4 code commits + `e1b1c993` "programme report, rulings, reconciled plans" + `e212f8d3` "record the 18 owner decisions"); `main` still `ab610933`; branch 0 behind / 6 ahead; worktree clean. P12-A / P11 / CI-timeout are NOT committed yet (markers absent). | Wave 0 starts from `e212f8d3`, not `ecfd3cc1`. CI is in flight on this head (started 07:06 UTC); the batch-0 push will cancel it — intended. |
| L2 | Required context **`verify` = FAIL** on `e212f8d3`: `tool/check_fail_closed_deployment.py` rejects `docs/ux-failure-states/plans/PLAN-P10-pr-readiness.md:171` ("Git prior-state selection" — the §7.3 store-lane sentence spells out the git verb for reverting a merge). Green on `main` (last run 2026-09-04). | New wave-0 item **N2**: reword that one sentence in the committed copy (docs-only, no owner input). Every later docs commit must avoid the checker's verbs. |
| L3 | Required context **`Release security scans` = FAIL**: `bundle-audit` flags `rubyzip 2.4.1` (CVE-2026-85396, High, advisory DB updated 2026-09-05 10:10 −0400). `Gemfile` pins `fastlane 2.238.0`; fastlane 2.238.0 AND latest 2.239.0 both require `rubyzip >= 2.0.0, < 3.0.0`; fix needs `>= 3.4.0` (latest 3.6.0). **No bump path exists.** `main`'s last green run predates the advisory → every PR to `main` goes red on its next run. | New owner item **N1** (release-gate change): approve `bundle-audit check --update --ignore CVE-2026-85396` with a dated comment and a removal condition (first fastlane admitting rubyzip ≥ 3.4.0). Does not block wave 0; blocks wave 1's `gh pr ready`/merge. |
| L4 | `defb1f07` is still `pending`, `jeeberId null`, offer `8bbea040` `submitted`; `offerDeadlineAt 2026-09-06T11:21:56Z` — **4 h 11 min from now**. | P04 Part A is the first device action, today, before 11:21 UTC. |
| L5 | `ci-flutter-stage.yml:55` still `timeout-minutes: 20`; `flutter-ci.yml:16` `timeout-minutes: 40` (measured 34m13s at `ecfd3cc1`). | OD-12 raises only the stage job. The `Flutter CI + coverage (79%)` job is the real critical path with ~6 min headroom — see §3 OD-0 and owner item N3. |
| L6 | No `device-evidence-4/` dir yet; no gateway worktrees for P02/P03; no P01 v2 draft anywhere in the scratchpad. `epic/wallet-guard-fix`: mobile `c4e343fe` 130 behind / 1 ahead (35 files); gateway `dfa9159d` 97 behind / 5 ahead (90 files). | Wave 0 creates the evidence dir + ledger and the two gateway worktrees. OD-15 explanation in §4 uses these numbers. |
| L7 | AR register census (`app_ar.arb`, 2,586 keys): 36 `*LoadingHeadline` keys — 34 MSA ("جارٍ …"/"نتحقّق …"), 2 Levantine ("عم نجيب طلباتك", "عم نتحقق من حسابك"); 83 keys contain "جارٍ", 159 contain "تعذّر"; P07 measured 505 failure-family keys, all MSA. | Sizes the OD-7 WP-9 ticket (§3). |

## 1. Per-plan status (decisions applied)

Landing rule under **OD-0 = widen**: the C1 scope freeze is VOID; every mobile follow-up lands as commits on
`ux/api-error-handling-empty-states` (PR #335) in **three batched pushes** (§2.1). "Batch n" below = which push
carries it. Gateway work stays in independent worktrees off fresh `origin/main` (C14) and merges/deploys owner-gated
(OD-3). Device slots are the serial queue in §2.4. Evidence dirs per C12 (`$SCRATCH/device-evidence-4/<key>/`).

| Plan | Decision(s) applied | What changed vs the reconciled plan | Landing branch / batch | Gateway branch / worktree | Device slot | Status |
|---|---|---|---|---|---|---|
| **P01** dm-onboarding route | OD-1 form builder → gateway → user preferences; OD-2 nobbox; OD-3 combined | Current plan is corrected P01 v3; no v2 confirmation remains. Prepare gateway and builder separately; deploy/route flip still gated. | `fix/dm-onboarding-route` after deploy, off post-merge main | `feat/form-submissions-preferences`; builder `feat/jeeb-onboarding-template` | after route + template deployment | **ready to prepare; execution gated** |
| **P02** notifications target id | OD-4 **chat** (inbox `offer_accepted` → `/chat/{ref}`); OD-3 combined; OD-0 widen | Gateway G0–G4 unchanged. Mobile M1–M2, M4–M8 (M3 stays dropped, C4) become commits on #335: **commit 1** (hand-authored fixture, no deploy dependency) rides batch 1 at position 5 of the l10n chain; **commit 2** (captured post-deploy fixture) rides batch 3 only if the combined deploy lands before batch 2's `gh pr ready`, else it is the first post-merge follow-up PR. V1–V12 wait for wave 4. V1 creates a fresh ledgered request (C7). | #335: batch 1 (c1), batch 3 or post-merge PR (c2) | `fix/notifications-inbox-target-ref` in `jeeb-gateway-worktrees/notif-target-ref` (create in wave 0) | 13 (wave 4) | **ready** |
| **P03** create-request validation | OD-5 **five** (MinDescriptionLength 5 + code-only lexicon expansion); OD-3 combined; OD-0 widen | Gateway G1–G6 unchanged. Mobile M1–M6 (+ C9 registry line `compose_description_error`) become one commit on #335 at position 6 of the l10n chain (batch 1). Phase A device check any time after batch 1 is on the phone; Phase B after the combined deploy; Phase B(4) request is ledgered + swept (P04 rule). | #335: batch 1 | `fix/p03-create-request-validation` in `jeeb-gateway-worktrees/p03-validation` (create in wave 0) | 11 (Phase A), 13 (Phase B) | **ready** |
| **P04** stray request + leave-no-state | OD-6 **api** (minted-token sweep is the mechanism); OD-0 widen | Part A unchanged and FIRST (deadline 11:21 UTC today): withdraw `8bbea040` → cancel `defb1f07` through the real app, API fallback allowed by OD-6. Part B (`tool/device_validation_cleanup.sh` sweep/audit/record + stub test + `docs/device-validation.md` + `ci-android-stage.yml` line + Guardrail-Agent memory) no longer needs its own branch off `main`: it rides #335 in batch 1 (no `lib/` files, no l10n). Wave-3 runs use it from the checkout before it merges. Today's Part-A ledger lines are hand-written in the tool's JSON-line shape and replayed by the first `sweep` (B7). | #335: batch 1 (Part B) | — | 0 (Part A, now) | **ready** |
| **P05** guardrail floors → 0 | none needed; OD-0 widen; C8 grammar (P12) | WI-1…WI-8 unchanged (incl. WI-3b registry, C8 id `devtool_wallet_funding_picker_empty_retry_cta`). Lands as one commit on #335 at position 2 of the l10n chain (after P13, over P12-A's `jeeber_no_requests_view.dart:162` and registry renames). WI-8 step 5 (`--dart-define=JEEB_DEVTOOL_ENABLED=true …` devtool suite) is mandatory in the integrator gate: main-green ≠ RC-green. | #335: batch 1 | — | 9 (V1–V5) | **ready** |
| **P06** greeting after failed read | none needed; OD-8 proxy; OD-0 widen | Steps 1–8 unchanged; `_classify` uses P13's `networkFailureFromReachability()` (C3), fixtures `NetworkFailure(offline:true)`. Lands at position 3 of the l10n chain (registry after P05). §5.3 uses the shared P08 proxy (`plans/p06-proxy.py` is retired — delete it from the scratchpad once P08 D1 exists). | #335: batch 1 | — | 7 (§5.1–5.3) | **ready** |
| **P07** Arabic failure states | OD-7 **Levantine**; OD-8 proxy; OD-0 widen | **F4 DROPPED**: `orderHistoryLoadingHeadline` / `jeeberTabsLoadingHeadline` keep their Levantine values; row B2's expected C-value is the CURRENT string "عم نجيب طلباتك". A **WP-9 ticket** ("AR system copy → Levantine") converts the MSA siblings instead (size in §3). F1, F2, F3, F5, F6 (allowlist incl. `Wi-Fi`), F7 optional ship as one commit at position 4 of the l10n chain. F8 stays dropped (C2). The AR device run validates the current mixed register and says so in `p07-ar/REPORT.md`. New AR keys added by P05/P13/P02/P03 in this wave are MSA-authored per their plans and are appended to the WP-9 list. | #335: batch 1 | — | 5 (AR run) | **ready** (F4 dropped) |
| **P08** non-timeout outage scenarios | OD-8 **proxy** (Mac-local `tool/fault_proxy/fault_proxy.py` over `adb reverse`, Dev Tool override); OD-0 widen | D1–D6 unchanged (S00–S16; S17 dropped, C17). No longer a separate `ux/p08-fault-proxy` PR: the tooling commit rides #335 in batch 1 (no l10n, no `lib/`), and P06/P07/P09 consume it from the checkout from wave 0 on. The wave-3 build carries P13, so the C3 conditional is settled: a dead `adb reverse` / `drop` renders "Can't reach Jeeb" (`errorUnreachableBody`), never "No connection". S06 (logout) last; then Super Login Plus re-entry. P11's `snack_shown`/`snack_closed` lines are available for S16 (P11 is on batch 0). | #335: batch 1 (tooling) | — | 4 (S00–S16) | **ready** |
| **P09** never-exercised surfaces | OD-9 **delete** (S1.6 must be captured BEFORE P12-B); OD-10 **uionly**; OD-11 **leave**; OD-8 proxy; OD-0 widen | §2.1 step 3's curl fallback is REMOVED: the EmptyJeeber KYC goes through the camera wizard only; if it blocks, S3.4, S4.1–S4.3, S5.0–S5.2, S5.4 and the S5.F deep-link fallback are reported **NOT EXERCISED** (S4.4 / S5.3 Karim controls still run). Throwaway account, offer, chat message stay on dev with ids in `accounts.md` (OD-11); the P04 sweep withdraws the offer. S1.6 (catalog ChatTab states) runs in slot 6 on the batch-1 build, i.e. before batch 2 deletes ChatTab. Interim mitmdump replaced by the P08 tool (port 8089, `/gateway` override). | (device only; defect fixes → batch 2) | — | 6 (S1–S8) | **ready** (S4/S5 conditional) |
| **P10** PR readiness | OD-12 **raise35**; OD-13 **squash + keep branch**; OD-14 **nextday**; OD-15 **wallet independence, P15**; OD-0 widen | §2 timeout commit rides batch 0 (applies to its own run). C1 scope freeze VOID → R4 re-smoke happens on **three** head SHAs (batch 0/1/2 heads), not one. §5 lane reviews become delta reviews per batch + a final pass on the batch-2 head. §6 ADR-0004 (with the C3 R6 refinement) + reviewer map + migration notes ride batch 2. §7.2 RC/distribute preparation for the merge SHA `M`, day-after-merge date codes `26MMDD01` (Android) / `26MMDD02` (iOS), both > `26090403` / `26090402`. **D4 is superseded by the P15 dependency train**. Two new red contexts (L2/L3) are added to §1's readiness definition. | #335: batch 0 (CI), batch 2 (ADR/docs) | — | 1, 3, 12 (smokes) | **ready** (D4 → P15) |
| **P11** snack reconnect proof | OD-16 **define** (`JEEB_DEV_SNACK_ACTION_MS`, dev-affordance-gated); OD-0 widen | C1 + C2 both ship, one commit, second in batch 0 (after P12-A, before the CI timeout). Device runs A/B/C (+ optional D) on the batch-0 head right after the P10 smoke; phone left on the default build (run C). | #335: batch 0 | — | 2 (A/B/C/D) | **ready** |
| **P12** naming + ChatTab | OD-9 **delete** (R2 overridden once, recorded in the PR body); grammar `<screen>_empty_retry_cta` accepted; OD-0 widen | Change A unchanged, FIRST commit of batch 0 (A6 sets the repaired ratchet floor 0→26; lane 0B passes it as a repair). Change B (10 deletions + B2–B6, l10n dead keys) no longer needs `chore/delete-chat-tab`: it is the **first commit of batch 2**, LAST in the l10n order, gated on P09 S1.6 captured. §7 device check split: §7.1–7.6 in slot 10 on the batch-1 build; §7.7 (five tabs, catalog without ChatTab) folded into the batch-2 re-smoke (slot 12). | #335: batch 0 (A), batch 2 (B) | — | 10 (A), 12 (B) | **ready** |
| **P13** unreachable-host copy | OD-17 **wifi** wording; OD-0 widen | Steps 1–11 unchanged incl. 3b (exported `networkFailureFromReachability()`, 22-site sweep, new offline-blind ratchet) and the 19-test-file blast radius. **First commit of the batch-1 l10n chain**; rebases over P11's new `F6 · the close cause is observable` group in `jeeb_snack_test.dart` (C15). Device scenarios U/O/A in slot 8. | #335: batch 1 (position 1) | — | 8 (U/O/A) | **ready** |

Totals: **13 ready to prepare, 0 parked pending the old OD-1/OD-15 questions, 0 dropped.** Dropped sub-items: P07-F4, P07-F8, P02-M3, P08-S17, the C1 scope
freeze (void). Superseded sub-item: P10-D4 (replaced by P15).

## 2. Waves

### 2.1 Batching model under OD-0 widen (derived from C9/C10 + the CI hazard)

- **Hazard.** `ci.yml` has `concurrency: ci-${{ github.ref }}` + `cancel-in-progress: true`: every push cancels the
  in-flight run. `Flutter stage / Test` runs 19–21 min (cap 20 today, 35 after batch 0); `Flutter CI + coverage`
  runs ~34 min (cap 40). R4 needs a real-device smoke per head SHA. So the number of pushes IS the cost.
- **Serialization** (unchanged from C9/C10, now expressed as commit order on one branch): registry
  `audited_interaction_identifiers.dart` = P12-A → P06 → P05 → P03 → P12-B; l10n triple
  (`app_en.arb`, `app_ar.arb`, hand-authored `app_localizations.dart`) = P13 → P05 → P06(none) → P07 → P02 → P03 → P12-B;
  `jeeb_snack_test.dart` = P11 → P13; `jeeber_no_requests_view.dart` = P12-A → P05.
- **Rule.** Lanes develop in their own worktrees branched from the branch head and NEVER push. One **integrator**
  applies lanes onto `ux/api-error-handling-empty-states` in the fixed order (rebase/cherry-pick each lane onto the
  accumulated head, hand-merge the l10n triple + registry, run `qa/t-mob-fix-002/l10n_parity_check.sh --analyze` +
  `ar_plurals_check.sh` after EACH application), runs the full P10 §4 local gate once, then makes **one push per
  batch**. A lane that is red at integration time is dropped from the batch, never pushed red.
- **Three batches, three CI cycles, three smokes** (instead of 9–10 of each):

| Batch | Commits, in order | Gate before push | What it unblocks |
|---|---|---|---|
| **0** (today) | 1 P12-A · 2 P11 C1+C2 · 3 P10 §2 timeout 20→35 · 4 N2 docs reword (`PLAN-P10-pr-readiness.md:171`) · (N1 withdrawn; no audit bypass) | P10 §4 local gate (~25 min) | `verify` green; stage cap 35 applies to this run; P10 §7.1 smoke + P11 proof (wave 1); batch-1 lanes rebase onto this head |
| **1** | 6 P08 D1–D6 · 7 P04-B · 8 **P13** · 9 **P05** · 10 **P06** · 11 **P07** · 12 **P02-M c1** · 13 **P03-M** | local gate + P05 WI-8 step 5 devtool-define suite + `bash tool/test_fault_proxy.sh` + `bash tool/test_device_validation_cleanup.sh` | the wave-3 device queue runs on ONE build (this head) |
| **2** | 14 **P12-B** (after S1.6 captured) · 15 wave-3 defect fixes, if any (P08 §8 / P09 §8 pattern, one commit each) · 16 ADR-0004 + reviewer map + migration notes + refreshed `docs/ux-failure-states/plans/*` copies | local gate | final re-smoke → lane reviews final pass → `gh pr ready` → owner squash |
| **3** (conditional) | 17 P02-M c2 (captured post-deploy fixture) | local gate | only if the combined deploy (OD-3) lands before batch 2's `gh pr ready`; otherwise this is the first post-merge PR |

**What the 35-minute cap (OD-12) means per batch.** Batch 0's run executes the workflow from the PR head, so the
raise applies to itself: stage test ≈ 19–21 min → ~14 min headroom. Batch 1 adds ≈ 160–200 tests (P13 sweeps 19 test
files + new groups, P08 D4 contract test, P05/P06/P07/P02/P03 groups) → ≈ 21–23 min, ≥ 12 min headroom. Batch 2
removes four ChatTab test files → flat. The cap that OD-12 does NOT touch is `flutter-ci.yml:16` (40 min, measured
34m13s): batch 1's growth puts it at ≈ 36 min → owner item **N3** (pre-approve 40→50 so it can ride batch 1 if batch 0's
`Flutter CI + coverage` wall time is ≥ 36 min). Wall clock per batch ≈ 35–40 min to all-green + ≈ 35 min build + smoke.

### 2.2 Wave 0 — now, in parallel, no further owner input

Every lane below is executable with the decisions in hand. File fences are the CONFLICT-REVIEW §2 rows; a lane
touches nothing outside its fence. Worktrees: mobile lanes branch from `e212f8d3` in
`jeeb-mobile-worktrees/<lane>`; gateway lanes from fresh `origin/main` (`git -C jeeb-gateway fetch origin` first —
the local checkout is 515 commits stale, never branch from it).

**First actions, in this order of urgency:**

1. **Lane D — P04 Part A on the phone (start immediately; done before 11:21 UTC).** A1 preflight → A2 withdraw
   `8bbea040` via `pending_offer_0_withdraw_cta` as Karim → A3 cancel `defb1f07` via `waiting_cancel_cta` →
   `cancel_request_confirm_cta` as `devtool_client_1788592148874` → A4 gateway verification → A5 restore Karim/URL.
   API fallback (`DELETE /v1/offers/{id}` then `DELETE /v1/requests/{id}`, MSI allowlist) is sanctioned by OD-6.
   Create `$SCRATCH/device-evidence-4/` + `CREATED.jsonl` (hand-written lines for the request, the offer, both
   minted sessions) + `p04/REPORT.md` with the mandatory "Residual state" section. Fence: no repo file.
2. **Lanes A/B/C — batch 0 code, three disjoint fences, parallel, then integrated in order A → B → C:**
   - **Lane A (P12 Change A):** `lib/features/earnings/presentation/earnings_dashboard_screen.dart:265`;
     `lib/features/jeeber_home/presentation/widgets/jeeber_no_requests_view.dart:162` only;
     `lib/core/observability/session_trace/audited_interaction_identifiers.dart` lines 225 + 293 (renames only);
     `test/features/earnings/earnings_dashboard_states_test.dart`; `test/features/jeeber_home/jeeber_home_failure_identifiers_test.dart`;
     `test/guardrails/failure_identifier_coverage_ratchet_test.dart` (A6, floor → 26); `docs/build-out/41_GUARDRAILS_TESTING.md`.
   - **Lane B (P11 C1 + C2):** `lib/core/dev_flags.dart`; `lib/core/widgets/jeeb/jeeb_snack.dart`;
     `test/core/widgets/jeeb/jeeb_snack_test.dart`; `test/core/dev_flags_test.dart`.
   - **Lane C (CI + red contexts):** `.github/workflows/ci-flutter-stage.yml:55` (20→35);
     `docs/ux-failure-states/plans/PLAN-P10-pr-readiness.md:171` (N2: replace the git verb phrase with "a revert
     commit on a branch → PR → merge → new RC"; re-run `python3 tool/check_fail_closed_deployment.py` locally until
     it prints nothing); `release-security.yml` is not changed: N1 is withdrawn (§0a).
   - **Integrator:** apply A → B → C onto `ux/api-error-handling-empty-states`, `git add -A`, P10 §4 gate, ONE push,
     then `gh pr checks 335 --watch`. Target: push by ≈ 09:30 UTC, all-green ≈ 10:10 UTC.
3. **Lanes G2 / G3 — gateway PRs (parallel, independent files, open as ready PRs; merges owner-gated):**
   - **G2 (P02-G):** `git -C jeeb-gateway worktree add ../jeeb-gateway-worktrees/notif-target-ref -b fix/notifications-inbox-target-ref origin/main`.
     Fence: `src/JeebGateway/Controllers/JeebNotificationsInboxController.cs`, `src/JeebGateway/Notifications/NotificationDeepLinkResolver.cs`,
     `tests/JeebGateway.IntegrationTests/Fixtures/FM1/*` (captured fixtures stripped of `_dispatch`, `_idempotency_fingerprint`,
     `senderProfilePicture`, `nickname`, `media_links`) + `README.md`, `JeebNotificationsProjectionTests.cs`,
     `JeebNotificationsDeepLinkResolutionTests.cs`, `NotificationDeepLinkResolverTests.cs`. OD-4: `offer_accepted → jeeb://chat/{id}`.
   - **G3 (P03-G):** `git -C jeeb-gateway worktree add ../jeeb-gateway-worktrees/p03-validation -b fix/p03-create-request-validation origin/main`.
     Fence: `src/JeebGateway/Requests/RequestCreateValidation.cs` (`MinDescriptionLength = 5`, `Max = 500`),
     `Controllers/V1/JeebRequestsController.cs`, `Controllers/RequestsController.cs`, `ProhibitedItems/Scanner/{IProhibitedItemSynonymRegistry,InMemorySynonymRegistry,ProhibitedItemScanner}.cs`,
     tests per P03 G6 (`OwnerServiceFakes.cs`, `ProhibitedItemScannerUnitTests.cs`, `Requests/RequestCreateValidationTests.cs`,
     `V1CreateDescriptionLengthTests.cs`, `V1CreateModerationGateTests.cs`). `RequestVoiceController.cs` untouched.
   - **P01 preparation is no longer parked:** use the corrected v3 gateway and form-builder branch specifications. This review-fix wave does not create those branches or execute their deployment.
4. **Lanes T8 / T4 — tooling for batch 1 (parallel, no l10n, no `lib/`):**
   - **T8 (P08 D1–D6):** `tool/fault_proxy/fault_proxy.py`, `tool/fault_proxy/scenarios/S00…S16.json`, `tool/fault_proxy/bodies/*`,
     `tool/fault_proxy/test_fault_proxy.py`, `tool/test_fault_proxy.sh`, `test/core/network/fault_proxy_scenarios_test.dart`,
     `tool/fault_proxy/device/{dump.sh,run_preflight.sh,run_teardown.sh}`, `tool/fault_proxy/README.md`. Conventions:
     listen `127.0.0.1:8089`, `adb reverse tcp:8089 tcp:8089`, override `http://127.0.0.1:8089/gateway`, rules anchored
     `^/gateway/…`, `respond.drop` for RST, no 401/403 rules outside S06–S08. Ready for device use as soon as D1 passes
     `tool/test_fault_proxy.sh` — before it is pushed.
   - **T4 (P04-B):** `tool/device_validation_cleanup.sh` (`record`/`sweep`/`audit`, host allowlist `{msi.olivium.space, 192.168.2.39}`,
     hard-refuse `jeeb.fds-1.com`), `tool/test_device_validation_cleanup.sh` (7 stub cases), `docs/device-validation.md`,
     `README.md` (one cross-link line), `.github/workflows/ci-android-stage.yml` (one `run:` line at 103–106),
     `.claude/agent-memory/Guardrail-Agent/device-validation-leaves-no-state.md` + `MEMORY.md` index line.
     First real use: `sweep` + `audit de520a28-… 106078a3-…` against today's Part-A ledger → must report clean.
5. **Lanes M13 / M05 / M06 / M07 / M02 / M03 — batch-1 mobile code (start now, parallel; integrated in that order after batch 0 is on the branch):**
   - **M13 (P13):** `lib/core/network/{app_failure,app_failure_mapper,network_reachability_signals}.dart`,
     `lib/core/widgets/jeeb/{app_failure_copy,jeeb_failure_block}.dart`, `lib/devtool/catalog/fixtures/client_home_screen_fixtures.dart`,
     `lib/devtool/catalog/entries/batch_04_entries.dart` (append), the 22 legacy `const NetworkFailure()` sites listed in P13 3b,
     `test/guardrails/no_offline_blind_network_failure_test.dart` (new ratchet), l10n triple (`errorUnreachableTitle/Body`, OD-17 wording),
     tests per P13 §5 (19 files re-read). Rebase over lane B's `jeeb_snack_test.dart` group.
   - **M05 (P05):** `lib/devtool/users/{scenario_users_page,fund_jeeber_wallet_picker_page}.dart`, `lib/devtool/gateway/dev_gateway_failure.dart` (new),
     `lib/core/observability/session_trace/presentation/widgets/obs_overlay_export_button.dart`, `lib/internal_devtool/internal_release_blocked_app.dart`,
     `lib/features/jeeber_home/presentation/widgets/{jeeber_feed_tab_view,jeeber_no_requests_view(137–142)}.dart`,
     `test/guardrails/{no_omds_error_snackbar,no_omds_state_widgets,no_title_key_as_headline,no_bare_pull_to_refresh}_test.dart` (floors → 0),
     registry (10 ids, WI-3b), l10n triple (3 keys + `scenarioUsersRetry` deletion), tests per WI-2/4/5/6.
   - **M06 (P06):** `lib/core/session/greeting_profile_cubit.dart`, `lib/features/jeeber_home/presentation/{jeeber_home_screen.dart,widgets/jeeber_home_greeting.dart}`,
     `lib/features/shell/tabs/{dashboard_tab,home_tab}.dart`, registry (2 ids), tests §4.1–4.4. No ARB change.
   - **M07 (P07 F1/F2/F3/F5/F6, F7 optional):** `lib/l10n/app_ar.arb` (2 values), `lib/features/registration/presentation/otp_verification_screen.dart:588–589`,
     `test/core/widgets/jeeb/jeeb_failure_rtl_test.dart` (new), `test/l10n/ar_failure_copy_guard_test.dart` (new, allowlist incl. `Wi-Fi`),
     `test/otp_verification_screen_test.dart`, optional `test/tools/catalog_capture_test.dart` (`CATALOG_LOCALE`). F4 NOT applied.
   - **M02 (P02-M commit 1):** `lib/features/notifications/**` (M1, M2, M4, M5), l10n triple (2 keys), `lib/devtool/catalog/fixtures/notifications_list_screen_fixtures.dart` (append),
     tests M7 with the hand-authored fixture from `plans/live/karim-v1-notifications.json`.
   - **M03 (P03-M):** `lib/features/location/{domain/compose_description_rules.dart (new), presentation/client_location_screen.dart}`,
     `lib/features/prohibited_acknowledgment/data/prohibited_acknowledgment_repository_impl.dart`, registry (`compose_description_error`),
     l10n triple (3 keys), `lib/devtool/catalog/{fixtures/client_location_screen_fixtures.dart, entries/batch_06_entries.dart}` (append), tests M6.

Cross-lane invariants for every lane: PR #330 files (`auth_interceptor.dart` and the refresh chain) untouched; no
`implements` signature widening (R3); comments ≤ 2 lines; `git add -A` before `flutter test`; never `--update-goldens`;
Flutter 3.44.2; no new repos.

### 2.3 Later waves and their gates

| Wave | Content | Gate (who) |
|---|---|---|
| **1** | On the batch-0 head: P10 §7.1 six-check smoke (retain the `ab610933` debug APK from the main clone first) → P11 runs A/B/C (+D) with the 30 s proof build, phone left on the default build; lane reviews 0A/0B first pass on the batch-0 diff. | batch-0 CI: `verify`, `CI ready`, `Flutter CI + coverage`, `L10n parity` green (`Release security scans` stays red until the verified upstream fix path clears it; N1 is withdrawn). No owner action. |
| **2** | Integrator applies T8, T4, M13→M05→M06→M07→M02→M03 (N1 withdrawn; no audit bypass) → batch-1 push → CI → P10 §7.1 re-smoke on the batch-1 head (slot 3). | all batch-1 lanes green in the local gate; wave-1 smoke PASS. No owner action. |
| **3** | Serial device queue slots 4–11 on the batch-1 build (§2.4); every run records to `CREATED.jsonl`, ends with `sweep` + `audit`, writes `<key>/REPORT.md` with the actual Android version on line 1 (C18). Defects → one fix commit each, staged for batch 2. | wave-2 re-smoke PASS; P08 proxy transparent (S00). OD-10: no curl for KYC. |
| **3b** | P12-B (after S1.6 captured) + defect fixes + ADR-0004/reviewer map/migration notes → batch-2 push → CI → re-smoke (slot 12, incl. P12 §7.7) → lane reviews final pass (all 11 lanes, delta + head) → `gh pr ready 335` → **owner squash-merges, keeps the branch (OD-13)**. | all 5 required contexts green on the batch-2 head — this needs the security dependency/advisory fix shipped, not an audit bypass; every lane review PASS; `gh pr ready` is ours, the merge is the owner's. |
| **4** | Owner merges P02-G + P03-G → **ONE MSI deploy + ONE staging dispatch (OD-3, owner-executed)** → P02 wire proof (`jq '.items[] \| {type, ref, deepLink, ts}'`) + commit 2 (batch 3 or post-merge PR) + V1–V12 (slot 13) → P03 Phase B (slot 13). P01 §7A/§7B run only after the separately authorized route/template deployment. | owner: two gateway merges + one deploy pair. P01 gateway + builder join if their corrected PRs are merged in time; otherwise they require a separate owner deployment window. |
| **5** | Day after the merge (OD-14): owner dispatches Android RC + distribute (`26MMDD01`) and iOS RC + distribute (`26MMDD02`) for the merge SHA `M`; exact commands with the real `M` posted in the PR's final comment by us (P10 §7.2). `epic/wallet-guard-fix`: prepare the P15 train under the wallet-independence ruling; deploys remain gated. | owner: 4 workflow dispatches; OD-15 decision. |

**Parked under the old OD questions:** nothing; P01 v3 and P15 supersede them. Operational execution still follows §0a's gates.

### 2.4 Serial device queue (one phone RZCT505K7WF; each run restores URL/radios/locale/session; `install -r` only)

| Slot | Run | Build | Evidence dir |
|---|---|---|---|
| 0 | **P04 Part A** — today, before 11:21 UTC | current phone build (`ecfd3cc1`) | `p04/` + shared `CREATED.jsonl` |
| 1 | P10 §7.1 smoke (6 checks) | batch-0 head | `p10-smoke/` |
| 2 | P11 runs A/B (30 s build), C (default build), D optional | batch-0 head + `JEEB_DEV_SNACK_ACTION_MS=30000` variant | `snack-reconnect/` |
| 3 | P10 §7.1 re-smoke | batch-1 head | `p10-smoke/` |
| 4 | P08 S00–S16 (S06 last, then Super Login Plus re-entry) | batch-1 head | `p08/<Sxx>/` + `p08/REPORT.md` |
| 5 | P07 AR run A1–E1 (AR authority; C rows path-scoped; B2 expects the Levantine string) | batch-1 head | `p07-ar/` |
| 6 | P09 S1–S8 incl. **S1.6 catalog ChatTab** (before P12-B); S3.4/S4/S5 only if the camera KYC wizard succeeds (OD-10) | batch-1 head | `p09/<surface>/` + `p09/JUDGE-RUN4.md` |
| 7 | P06 §5.1–5.3 (proxy rule `users-me-503`) | batch-1 head | `p06/` |
| 8 | P13 scenarios U / O / A | batch-1 head | `p13/` |
| 9 | P05 V1–V5 (RC-lane build with `JEEB_DEVTOOL_ENABLED` + `JEEB_OBS_OVERLAY`) | batch-1 head | `p05/` |
| 10 | P12-A §7.1–7.6 | batch-1 head | `p12/` |
| 11 | P03 Phase A | batch-1 head | `p03/` |
| 12 | P10 §7.1 re-smoke + P12 §7.7 (five tabs, catalog without ChatTab) | batch-2 head | `p10-smoke/`, `p12/` |
| 13 | after the combined deploy: P02 V1–V12, P03 Phase B | batch-2/3 head | `p02/`, `p03/` |

## 3. Consequences the owner should know

**OD-0 widen — three pushes, one ~1,000-file review, three smokes.** Every push to `ux/api-error-handling-empty-states`
cancels the in-flight CI (`cancel-in-progress`), so an unbatched widen would cost 9–10 CI cycles of 35–40 min and, by
rule R4, 9–10 device re-smokes. Batching to three pushes (§2.1) caps that at three cycles and three smokes (≈ 1 h 15 min
each), but every red lane at integration time delays the whole batch, and the review is no longer 887 files at one
frozen SHA: batch 1 adds P13's 22-site sweep + 19 touched test files and six feature commits, so lane reviewers must
review per-batch deltas (`git diff <prev-head>...<head> -- <globs>`) and sign the final head. The squash commit will cite
≈ 20 branch SHAs; the evidence trail therefore spans three head SHAs instead of one. Not decision-driven but on the
same head: `verify` and `Release security scans` are red today (§0 L2/L3) — the docs reword is in batch 0, the
rubyzip advisory needs the upstream fix path (N1 withdrawn) and blocks the merge of every PR to `main`, not only #335.

**OD-2 nobbox — no coverage boundary is enforced anywhere in production.** With `JeeberOnboarding:Coverage:Boundaries`
empty in every appsettings (Production included) and `FailOpenWhenUnconfigured = true`, any home base — Nicosia, Haifa,
Damascus, anywhere — is accepted with `coverage.checked = false, zone_key = null`; no 409 `out_of_coverage` is ever
produced until someone adds a boundary to `appsettings.Production.json` (or the env override) and redeploys, and the
§7A Nicosia curl loses its 409 proof (it becomes "201 with `coverage.checked=false`"). What survives as a mechanism, if
the P01 v3 coverage mechanism ships: the `ZoneBoundary`-typed options section + resolver, the 409 problem type
`https://jeeb.dev/errors/out_of_coverage`, the two gwdbx registry rows, and mobile's `out_of_coverage` discriminator
(tested but dead on live). P01 v3 retains this dormant mechanism; it takes effect only after its separately authorized deployment.

**OD-7 Levantine — F4 dropped; WP-9 converts the MSA side, which is almost all of it.** The two Levantine headlines stay
(`orderHistoryLoadingHeadline` "عم نجيب طلباتك", `jeeberTabsLoadingHeadline` "عم نتحقق من حسابك"). The conversion ticket
covers, at minimum, the other 34 `*LoadingHeadline` keys (all "جارٍ …"/"نتحقّق …"), and to honour "never a mix" for
system copy it extends to the whole failure family P07 measured at 505 keys (83 keys contain "جارٍ", 159 contain "تعذّر",
of 2,586 AR keys) — roughly 500–600 strings needing a native Levantine rewrite, not a mechanical edit; the P07 F6 guard
checks digits/Latin residue, not register, so it cannot enforce the outcome. Until WP-9 lands the app stays mixed, the
AR device run (slot 5) records that as the current state, and the AR keys added in this wave (P05 ×3, P13 ×2, P02 ×2,
P03 ×3) are authored MSA like their siblings and go on the WP-9 list — unless you give a one-sentence Levantine
reference so lanes can author them in register now.

**OD-10 uionly — four empty surfaces may end NOT EXERCISED.** The EmptyJeeber's KYC must go through the camera wizard
(`kyc_tos_accept` → three camera captures → `kyc_submit_cta`), with the known live KYC blockers (ReferralCode, ToS
version seeding, ID-shape, AutoApprove path) as the risk. If it blocks, P09 reports S3.4 (`jeeber_pending_offers_empty_state`),
S4.1–S4.3 (`wallet_activity_empty` + its error/retry), S5.0–S5.2 and S5.4 (`reviews_empty`, inline profile empty,
reviews error) and the S5.F deep-link fallback as NOT EXERCISED — no curl `POST /v1/kyc/submit`, no scripted KYC — and
`JUDGE-RUN4.md` lists them as gaps; the Karim controls (S4.4, S5.3) and everything else in P09 still run. `earnings_empty`
is still proven by P12 §7 on the run-2 devtool jeeber, so it is not lost.

## 4. Owner still owes

1. **OD-1 answered:** P01 v3 is the plan of record. The owner still controls deployment, live-template versioning, and treatment of the pre-existing builder vocabulary gate.
2. **OD-15 answered by the wallet-independence ruling; P15 is current.** Historical explanation: *Which one is used now:* what testers and the dev gateway run is
   `main` — Android Play internal `1.0.0+26090403` @ `ab610933`, TestFlight `1.0.0+26090402` @ `665aa939`, MSI gateway
   `origin/main 6679f6ee`. `epic/wallet-guard-fix` (mobile `c4e343fe` of 2026-08-24, gateway `dfa9159d`) is merged nowhere
   and deployed nowhere; it is 130 commits behind mobile `main` (35 files) and 97 behind gateway `main` (90 files).
   *Is there a breaking change:* the re-baseline itself changes nothing users run — it is a branch operation; the epic's
   behaviour (fee-guard exposure aggregation, commission debit, currency fix, W0–W7) reaches production only when the
   rebuilt branch merges and its runtime flip is executed per `FLIP-READINESS.md`, identically under either option.
   The risk sits in the other option: merging 130 + 97 commits INTO the epic collides on 22 mobile files (hand-authored
   l10n triple, wallet/offers repositories) and 90 gateway files that `main` has independently reworked since 2026-08-31,
   resolved by hand with no test that pins the guard's intent. Recommendation unchanged: re-baseline as a fresh branch
   off post-merge `main` and re-apply W0–W7 on `OfferSubmissionCubit`'s `AppFailure` path, mapping wallet 409
   `insufficient_balance` through `GatewayProblem.reasonCode`. That earlier choice is superseded by P15's constrained train.
3. **N1 withdrawn:** no security-scan ignore or allowlist. The owner files the verified upstream kit; the release gate remains enforced until the dependency/advisory path is genuinely fixed.
4. **N3 (conditional):** pre-approve raising `.github/workflows/flutter-ci.yml:16` `timeout-minutes` 40→50 (same rationale
   as OD-12) so it can ride batch 1 if batch 0's `Flutter CI + coverage` wall time is ≥ 36 min.
5. **Levantine reference (small):** one example sentence in the register you want for system copy, so WP-9 can be scoped
   and this wave's new AR keys can be authored in register rather than added to the backlog.
6. **Owner-executed steps, in order:** (a) merge gateway PRs P02-G and P03-G when green; (b) run ONE MSI deploy + ONE
   staging dispatch (`jeeb-staging-deploy.yml`, `deployment_mode=normal`) for the merged gateway `main` (OD-3) — P01 gateway + builder
   join only if their corrected PRs are merged before this; (c) after `gh pr ready 335` and the final lane reviews: squash-merge #335, keep
   the branch (OD-13); (d) the day after the merge: dispatch `trusted-android-internal-devtool-rc.yml` +
   `distribute-android-internal-devtool.yml` (`26MMDD01`) and `trusted-mobile-rc.yml` (`platform=ios`) +
   `distribute-mobile-internal.yml` (`26MMDD02`) for the merge SHA (OD-14) — exact commands will be in the PR's final comment.
