# CONFLICT-REVIEW — 13 plans, `ux/api-error-handling-empty-states` follow-ups (2026-09-05)

Reviewer: fresh Fable 5.1 principal, no prior involvement. Inputs read in full: FINAL-REPORT.md, RULINGS.md,
UX-API-AUDIT.md (skimmed for R-rulings only), device-evidence-3/REPORT.md, device-evidence-2/*/REPORT.md (headers),
PLAN-P01…P13. Code facts verified in the worktree `jeeb-mobile-worktrees/ux-api-errors @ ecfd3cc1` (registry
semantics, ratchet bug, `NetworkFailure` ctor, deep-link allow-list, 22 legacy `const NetworkFailure()` sites,
19 tests referencing `errorNetworkBody`). Every resolution below has been written into the affected PLAN files as
`Reconciled:` lines / a closing "Reconciled" section; owner decisions are renumbered OD-0…OD-17 across all plans.

## 1. Conflict table

| # | Plans | File / contract | Conflict | Resolution (edited into the plans) |
|---|---|---|---|---|
| C1 | P02 P03 P05 P06 P07 P08 P11 P12 P13 ↔ P10 | landing branch of PR #335 | Seven plans commit onto `ux/api-error-handling-empty-states`; P10 R4 requires a device re-smoke per head SHA, CI is at the 20-min cap with `cancel-in-progress`, and P10 §10 already says residuals are separate PRs. Moving-target 887-file review. | **Scope freeze**: #335 accepts exactly P12 Change A, P11 (C1 + C2 if OD-16 answered), P10 CI timeout — one batched push, one CI run, one smoke, then `gh pr ready`. Everything else = follow-up PR off post-merge `main` (develop stacked now, `git rebase --onto origin/main ux/api-error-handling-empty-states <branch>` after the squash). P01-mobile never on #335 (deploy order). OD-0. |
| C2 | P06 P07 P08 P09 | fault-injection tooling | Four proxies: `plans/p06-proxy.py` (8089, flag file), `tool/fault_gateway.py` (8089, global mode), `tool/fault_proxy/fault_proxy.py` (8089, rules), mitmdump addon (18080, re-homes `/gateway`). Two override-URL conventions (`http://127.0.0.1:8089` vs `…:8089/gateway`). | ONE repo tool = P08 D1. P07-F8 dropped, p06-proxy retired, mitmdump = interim only. Shared convention: listen 8089, `adb reverse tcp:8089 tcp:8089`, override `http://127.0.0.1:8089/gateway`, rules anchored `^/gateway/…`, `respond.drop` for TCP reset, no 401/403 outside P08 S06–S08. P08 D1–D6 move to wave 0 because P06/P07/P09 consume it. |
| C3 | P13 ↔ P06 P07 P08 P09 (+22 lib sites, 19 tests) | `NetworkFailure(offline:false)` copy contract | P13 makes `offline:false` render "Can't reach Jeeb"; P06 tests/`_classify` use `const NetworkFailure()` expecting `errorNetworkBody`; P09 §1.3/S2.3 and P08 risk note say `drop`/refused → "No connection"; P07-F6 AR guard rejects Latin — P13's AR body contains "Wi-Fi"; 22 legacy `Failure.network => const NetworkFailure()` sites in `lib/` are offline-blind and would say "Can't reach Jeeb" while the device is offline. | P13 gains step 3b: exported `networkFailureFromReachability()` + sweep of the 22 sites + a new ratchet; P13 lands FIRST in wave 2. P06 uses the helper and `NetworkFailure(offline:true)` fixtures. P07-F6 allowlist += `Wi-Fi`. P09/P08 expectations conditioned on whether P13 is on the build. RULINGS R6 refined: only `NetworkFailure(offline:true)` and `TimeoutFailure` blame connectivity (record in ADR-0004). |
| C4 | P02 M3 ↔ P02 D1/D3, P10 §10 F4 | mobile `_reference` parser | P02 widens the nested-data fallback while its own D1/D3 declare `ref` the single source of truth and P10 F4 wants the fallback retired. | P02 M3 dropped; parser unchanged; P10 F4 reworded to point at P02. |
| C5 | P02 M7 | captured post-deploy fixture | Mobile commit would depend on the owner-gated gateway deploy. | Split: commit 1 hand-authored fixture from `plans/live/karim-v1-notifications.json`; commit 2 captured fixture after the combined deploy. |
| C6 | P09 D-P09-1 ↔ P12 §6 ↔ RULINGS R2 | ChatTab mount/delete; catalog never-delete | Same owner question asked twice with different framings; P12-B deletes a catalog entry R2 forbids; P09 S1.6 needs the catalog ChatTab that P12-B deletes. | One question OD-9 (P12 wording, recommended YES); P09 S1.6 runs before P12-B; R2 override only on explicit YES, recorded in the PR body. |
| C7 | P04-A ↔ P02 V1, P09 S3.2/S5.0/S8.2, P12 §7.6 | live request `defb1f07` + offer `8bbea040` | P04 cancels them (deadline 2026-09-06 11:21 UTC); P02/P09 rely on them existing; P12 relies on expiry. | P04-A is the first device action; P02/P09 create fresh **ledgered** requests as their primary path; P09 S3.2 expects 4 rows; P12 §7.6 checks the ledger. |
| C8 | P05 WI-5 ↔ P12 §2 grammar | empty-block action id | P05 introduces `devtool_wallet_funding_picker_refresh_cta`; P12 ratifies `<screen>_empty_retry_cta`. | Renamed to `devtool_wallet_funding_picker_empty_retry_cta` (3 places in P05). |
| C9 | P05 P03 ↔ `secret_redactor_test` | `audited_interaction_identifiers.dart` | Registry holds literal ids and the inventory scans all of `lib/`; P05 (10 ids) and P03 (`compose_description_error`) omit the registry step; P06/P12 include it. | Steps added to P05 (WI-3b) and P03. Registry edit order P12-A → P06 → P05 → P03. |
| C10 | P02 P03 P05 P07 P12 P13 | `lib/l10n/app_en.arb`, `app_ar.arb`, hand-authored `app_localizations.dart` | Six plans add/delete keys in the same three hand-merged files. | Serialized wave-2 order P13 → P05 → P06 → P07 → P02 → P03 → P12-B; parity scripts after each rebase. |
| C11 | P10 lane 0B / §10 F2 ↔ P12 A6, P05 §0 | ratchet floors; stale claim | Lane 0B says "floors never raised" — P12 A6 raises the coverage-ratchet floor 0→26 (a repair of the vacuous `"'\$id'"` match); P10 F2 repeats the stale `onboarding_funding_screen.dart:349` claim P05 disproved. | Lane 0B told to PASS the repair; F2 rewritten to P05's measured residuals. |
| C12 | P02 P04 P06 P08 P10 | `device-evidence-4/REPORT.md` | Five plans write the same root report; ledger location unspecified. | Per-plan subdir `device-evidence-4/<key>/REPORT.md` (P07 → `p07-ar/`, P10 → `p10-smoke/`); one shared `device-evidence-4/CREATED.jsonl` with `JEEB_DEVICE_EVIDENCE_DIR=$SCRATCH/device-evidence-4`. |
| C13 | all device plans | one phone RZCT505K7WF | 12 device runs, each toggling URL/radios/locale/session/build. | Serial device queue (§3), every run restores state; order fixed. |
| C14 | P01 P02 P03 | gateway MSI/staging deploys | Three owner-gated deploys requested separately; P01 branches with `switch` in the stale checkout while P02 uses a worktree. | Three independent gateway PRs (worktrees), ONE combined MSI deploy + ONE staging dispatch after all three merge (OD-3). |
| C15 | P11 ↔ P13 | `jeeb_snack.dart` / `jeeb_snack_test.dart` / `app_failure_copy.dart` | Both touch the snack test file. | P11 on #335 first; P13 rebases over it. |
| C16 | P05 WI-1 ↔ P12 A2 | `jeeber_no_requests_view.dart` | Same file, different lines. | P12-A first (on #335), P05 rebases. |
| C17 | P07 ↔ P08 S17 ↔ P09 S2.7/S6.5 | Arabic on device | Three plans run AR scenarios; P07 C1–C8 duplicate P08 S01–S14 kinds. | P07 = AR authority (AR only, path-scoped rules); P08 S17 dropped; P09 keeps two AR spot checks. |
| C18 | P08 ↔ P07 P09 P11 P13 headers | device OS version | P08 measured Android 16 / SDK 36; others cite 14 from older reports. | Each REPORT.md records the actual `getprop` value on line 1. |
| C19 | P01 §7A ↔ P09 §2 | demo account `d1000000-…-0002` | P09 measured `/v1/users/me` → 502 for that account. | P01 prefers Karim `106078a3…` or the fresh devtool client. |
| C20 | P01 §5 mobile ↔ P01 §3(5) | landing branch vs deploy order | "Same branch as #335 while draft" contradicts "gateway deployed before the mobile flip is built for any device". | Mobile flip only on `fix/dm-onboarding-route` off post-merge main after the combined deploy is proven. |

Checked and found **not** in conflict: PR #330 invariants (P08/P09 only observe the 401 lane; P13/P11/P05/P06 stay
out of `auth_interceptor.dart`; P10 lane 0A reviews #335's additive edits); `implements`-widening (P13 optional ctor
param, P02 enum members with 3 exhaustive switches, P06 optional cubit params, P03 no interface change); Flutter
3.44.2 pin; no new repos; deploys prepare-only; comments ≤ 2 lines in every code snippet; identifier grammar
(P06 `jeeber_home_greeting_error/_retry_cta`, P03 `compose_description_error`, P05 after C8).

## 2. Shared-file ownership map (who edits what, in landing order)

| File / area | Plans (landing order) | Rule |
|---|---|---|
| `lib/l10n/app_en.arb`, `app_ar.arb`, `app_localizations.dart` | P13 → P05 → P06(none) → P07 → P02 → P03 → P12-B | hand-merge, parity scripts each time (C10) |
| `lib/core/observability/session_trace/audited_interaction_identifiers.dart` | P12-A (#335) → P06 → P05 → P03 → P12-B | exact-value, sorted (C9) |
| `lib/core/network/app_failure.dart`, `app_failure_mapper.dart`, `network_reachability_signals.dart` | P13 only | core; P11/P06 read only |
| `lib/core/widgets/jeeb/jeeb_snack.dart` | P11 (#335) | P13 reads |
| `lib/core/widgets/jeeb/app_failure_copy.dart`, `jeeb_failure_block.dart` | P13 | — |
| `test/core/widgets/jeeb/jeeb_snack_test.dart` | P11 → P13 | C15 |
| `test/guardrails/*` | P12-A (coverage ratchet) → P05 (four floors → 0) → P13 (new offline-blind ratchet) | never raise banned-pattern floors |
| `lib/features/jeeber_home/presentation/widgets/jeeber_no_requests_view.dart` | P12-A → P05 | C16 |
| `lib/features/jeeber_home/presentation/widgets/jeeber_feed_tab_view.dart` | P05 | — |
| `lib/features/jeeber_home/presentation/jeeber_home_screen.dart`, `widgets/jeeber_home_greeting.dart`, `lib/core/session/greeting_profile_cubit.dart`, `shell/tabs/{dashboard,home}_tab.dart` | P06 | — |
| `lib/features/earnings/presentation/earnings_dashboard_screen.dart` | P12-A | — |
| `lib/features/notifications/**` | P02-mobile | — |
| `lib/features/location/**`, `prohibited_acknowledgment/**` | P03-mobile | — |
| `lib/features/jeeber_onboarding/**` | P01-mobile (after deploy) | — |
| `lib/features/registration/presentation/otp_verification_screen.dart` | P07 | — |
| `lib/devtool/catalog/entries/batch_04` / `batch_06` / `batch_11`, `fixtures/*` | P13 / P03 / P12-B; P02 fixtures | append-only except P12-B (OD-9) |
| `lib/devtool/users/*`, `lib/internal_devtool/*`, `lib/core/observability/.../obs_overlay_export_button.dart` | P05 | — |
| `lib/features/shell/tabs/chat_tab.dart` + conversations stack | P12-B (delete) | after P09 S1.6, OD-9 |
| `lib/core/dev_flags.dart` | P11 | — |
| `.github/workflows/ci-flutter-stage.yml` | P10 | `ci-android-stage.yml` → P04-B (different file) |
| `tool/fault_proxy/**`, `tool/test_fault_proxy.sh`, `test/core/network/fault_proxy_scenarios_test.dart` | P08 | consumed by P06/P07/P09 |
| `tool/device_validation_cleanup.sh`, `tool/test_device_validation_cleanup.sh`, `docs/device-validation.md` | P04-B | consumed by every run-4 device plan |
| `docs/adr/0004-app-failure-model.md` | P10 (+ R6 refinement from P13) | — |
| gateway `Onboarding/**`, `JeeberOnboardingBffController.cs`, `Program.cs` (~1720), `appsettings*.json`, `gwdbx-flag-registry.txt` | P01 | worktree `p01-onboarding` |
| gateway `JeebNotificationsInboxController.cs`, `NotificationDeepLinkResolver.cs`, FM1 fixtures | P02 | worktree `notif-target-ref` |
| gateway `RequestCreateValidation.cs`, `V1/JeebRequestsController.cs`, `RequestsController.cs`, `ProhibitedItems/Scanner/*` | P03 | worktree `p03-validation` |
| `scratchpad/device-evidence-4/CREATED.jsonl` | shared ledger, every device run | P04 rule |

## 3. Execution waves

**Wave 0 — now, in parallel, no owner input needed**
- P04 Part A on the phone (withdraw `8bbea040`, cancel `defb1f07`, restore Karim) — deadline 2026-09-06 11:21 UTC; first device action.
- PR #335 batch (single push, in this commit order): P12 Change A → P11 (C1; C2 only if OD-16 arrived) → P10 §2 CI timeout. Then `gh pr checks --watch`.
- Gateway branches in three worktrees off fresh `origin/main`: P01, P02-G, P03-G (defaults: `kyc.submit.self`, Lebanon bbox fail-open, min length 5). Open PRs; merges owner-gated.
- Tooling branches (independent of the l10n order): P08 D1–D6 (`ux/p08-fault-proxy`), P04 Part B (`chore/device-validation-leave-no-state` off main).
- Mobile follow-ups may start stacked on #335 but do NOT push to it: P13 first (core), then P05, P06, P07, P02-M, P03-M.

**Wave 1 — needs OD-12/OD-13 (P10)**
- P10 §7.1 smoke on the batched head SHA → `device-evidence-4/p10-smoke/`; P11 device proof (A/B/C) right after on the same build; lane reviews; ADR-0004 (with the R6 refinement); `gh pr ready`; owner squash-merges.

**Wave 2 — after the #335 squash, serialized mobile PRs against `main` (l10n/registry order)**
P13 → P05 → P06 → P07 → P02-mobile (commit 1) → P03-mobile (Phase A device any time) → P12-B (only after OD-9 = YES and P09 S1.6 captured). P08/P04-B merge whenever green.

**Wave 3 — serial device queue (one phone; each run restores URL/radios/locale/session)**
1. P08 S00–S16 (EN kinds, proxy). 2. P07 AR run (proxy, AR authority). 3. P09 S1–S8 (proxy + EmptyJeeber + ledger; S1.6 before P12-B). 4. P06 §5.1–5.3. 5. P13 U/O/A. 6. P05 V1–V5. 7. P12-A §7. 8. P03 Phase A. Each writes `device-evidence-4/<key>/REPORT.md`, ends with `sweep` + `audit`.

**Wave 4 — needs OD-1/2/3 (owner merges P01/P02-G/P03-G and runs ONE MSI deploy + ONE staging dispatch)**
P01 §7A curl proof → P02 wire proof + captured-fixture commit 2 + V1–V12 device → P03 Phase B → P01 mobile flip (`fix/dm-onboarding-route`) + §7B device (only after staging also has the route).

**Wave 5 — needs OD-14/15** — P10 §7.2 RC/distribute preparation for the merge SHA; `epic/wallet-guard-fix` re-baseline.

Serialization summary: everything touching `lib/l10n/**` or the identifier registry is strictly ordered (C9/C10); the
device is strictly serial (C13); gateway PRs are parallel but deploy once (C14). No circular dependency remains
(P11 → P10 CI fix → push is linear; P13 precedes every plan whose expectations it changes).

## 4. Consolidated owner decisions (exact questions)

| OD | Plan | Question | Default if silent |
|---|---|---|---|
| OD-0 | review | Confirm the PR #335 scope freeze: only P12 Change A, P11 and the CI-timeout commit land on #335; all other work ships as follow-up PRs off post-merge `main` — yes/no? | yes |
| OD-1 | P01 | Confirm route `POST/GET /v1/jeebers/me/onboarding` under capability `kyc.submit.self` (alternative `profile.write.self`)? | as planned |
| OD-2 | P01 | Confirm launch coverage = Lebanon bbox 33.05–34.70 N / 35.10–36.65 E in `appsettings.Production.json`, fail-open when unconfigured (alternative fail-closed)? | as planned |
| OD-3 | P01/P02/P03 | Approve ONE combined gateway deploy order: merge P01 + P02 + P03 gateway PRs → one MSI deploy → one staging dispatch → then the mobile flips (P01-mobile, P02 commit 2, P03 Phase B); and run those owner-gated deploys. | — (blocks wave 4) |
| OD-4 | P02 | Inbox tap on an `offer_accepted` row: keep `/chat/{requestId}` (today's mobile contract) or switch to `/jeeber/deliveries/{requestId}/active` to match the push profile? | keep chat-detail |
| OD-5 | P03 | Approve `MinDescriptionLength = 5` (server + mobile, whitespace-collapsed) and the code-only keyword expansion of the live 14-item lexicon (no republish, no new items)? If not 5, give the number. | 5 / yes |
| OD-6 | P04 | Approve the OpenMode-minted owner-token API path (`DELETE /v1/offers/{id}` then `DELETE /v1/requests/{id}`, MSI host allowlist only) as the cleanup fallback and as the mechanism of `tool/device_validation_cleanup.sh sweep`? If no, Part A runs through the real app only and Part B ships ledger + audit (report-only). | — (Part A proceeds via the real app regardless) |
| OD-7 | P07 | Arabic system/loading copy register = MSA ("جارٍ تحميل طلباتك" / "جارٍ التحقق من حسابك") so F4 converts the two Levantine headlines — or "Levantine", in which case F4 is dropped and a WP-9 ticket converts the MSA siblings? Never a mix. | MSA |
| OD-8 | P08 (+P06/P07/P09) | Confirm the proxy-only fault mechanism (Mac-local `tool/fault_proxy/fault_proxy.py` over `adb reverse`, selected via the existing Dev Tool Server URL override; no in-app injector, no gateway toggle, no ephemeral env)? | yes |
| OD-9 | P12 (+P09) | Delete `ChatTab` and its private conversations stack (unmounted since PR #32, re-renders `/v1/requests`) — YES/NO? NO = only P12 Change A ships; a 6th shell tab is a separate nav-blueprint plan on `GET /v1/conversations`. Secondary (accept by default): empty-block action id grammar is `<screen>_empty_retry_cta`. | recommended YES |
| OD-10 | P09 | Allow seeding the throwaway jeeber's KYC via `curl POST /v1/kyc/submit` if the real camera flow blocks — yes/no? | real UI first |
| OD-11 | P09 | Leave the throwaway account, its offer and test chat message on the dev gateway (documented ids) or clean up via CMS suspend? | leave, document |
| OD-12 | P10 | Raise `.github/workflows/ci-flutter-stage.yml:55` `timeout-minutes` 20→35 in this PR (sharding deferred to a follow-up that also edits required contexts) — yes/no? | — (blocks wave 1) |
| OD-13 | P10 | Merge method for #335: squash + keep branch (recommended) or merge commit? | squash |
| OD-14 | P10 | Dispatch the Android Dev Tool RC/distribute and iOS RC/distribute workflows for the merge SHA, and on which day (sets `26MMDD01`/`26MMDD02`)? | — |
| OD-15 | P10 | Re-baseline `epic/wallet-guard-fix` as a fresh branch off post-merge `main` instead of merging 130 commits into it — yes/no? | yes |
| OD-16 | P11 | Approve the dev-affordance-gated compile-time define `JEEB_DEV_SNACK_ACTION_MS` (inert in store/staging builds) so the proof build can run a 30 s snack — yes/no? If no, the proof relies on the Diag `reason="reconnect"` alone. | proceed with C1 only |
| OD-17 | P13 | Copy for `NetworkFailure(offline:false)`: YES = "Can't reach Jeeb" / "Jeeb couldn't be reached. If you're on Wi-Fi, check it has internet access, then try again." (+AR); NO = the neutral "Jeeb couldn't be reached right now. Try again in a moment." (+AR). | YES wording |

P05 and P06 need no owner decision.

## 5. Verdict

The thirteen plans are individually sound and evidence-backed, but as written they would collide in four places
that no single author could see: seven of them push onto a PR whose own readiness plan needs a frozen head SHA
(C1); four of them build their own fault proxy on the same port with two URL conventions (C2); P13 silently
changes the copy contract that P06, P07, P08 and P09 assert against — and leaves 22 legacy `const NetworkFailure()`
sites that would then blame the wrong thing (C3); and P04's mandatory cleanup of `defb1f07` removes the live data
three other device runs were counting on (C7). None of these is a reason to drop a plan. With the scope freeze on
#335 (P12-A + P11 + CI fix, one push), one shared fault proxy, P13 first in the serialized l10n/registry order,
fresh ledgered requests for every device run, per-plan evidence dirs, and a single combined gateway deploy for
P01/P02/P03, the set executes cleanly in five waves; the only hard owner gates are OD-12/13 (merge #335), OD-3
(the combined gateway deploy) and OD-9 (ChatTab). PR #330 invariants, the `implements` trap and every standing
owner rule survive intact in all thirteen plans after reconciliation.
