# PLAN P10 — PR #335 readiness: draft → ready-for-review → merge → phone rollout

Pending point: `P10-pr-readiness`. Planning only; no repo file was changed while writing this.
Repo: `olivium-dev/jeeb-mobile`. Branch `ux/api-error-handling-empty-states` @ `ecfd3cc1`
(4 commits on `origin/main@ab610933`, 887 files, +63985/−8256).
Worktree: `/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile-worktrees/ux-api-errors`.
PR: https://github.com/olivium-dev/jeeb-mobile/pull/335 (draft, `mergeable: MERGEABLE`, `mergeStateStatus: BLOCKED`).

---

## 0. Verified current state (2026-09-05, all probed live)

| # | Fact | Evidence |
|---|---|---|
| S1 | PR #335 is `isDraft: true`, `mergeStateStatus: BLOCKED`, `reviewDecision: ""`, no reviewers requested, no labels. | `gh pr view 335 --json …` |
| S2 | Branch protection on `main`: **required contexts** = `verify`, `CI ready`, `Flutter CI + coverage (79%)`, `L10n parity gate (T-MOB-FIX-002)`, `Release security scans`; `strict: true` (branch must be up to date with main); `required_approving_review_count: 0`; `enforce_admins: true`; no rulesets. | `gh api repos/olivium-dev/jeeb-mobile/branches/main/protection` |
| S3 | On head `ecfd3cc1`: 4 of 5 required contexts SUCCESS. **`CI ready` = FAILURE** because `Flutter stage / Test` was **CANCELLED** at 20m15s — step "Run tests" ran 11:04:30→11:23:39 (19m09s) and hit the job timeout. | run `33962190208`, job `101296140677` steps via `gh api repos/…/actions/jobs/101296140677` |
| S4 | The timeout is `timeout-minutes: 20` at `.github/workflows/ci-flutter-stage.yml:55` (job `test`). The same job on `main@ab610933` took **16m24s** (run `33885157674`, 14:42:57→14:59:21); on this branch it took **19m29s** at `7a0c386b` (passed, run `33957309480`) and was cancelled at `a48444ba` (run `33949836941`) and `ecfd3cc1`. Suite grew 8257 → 10539 tests (FINAL-REPORT §4). The parallel `flutter-ci.yml` job (`timeout-minutes: 40`, with `--coverage`) passed in 34m13s. | workflow files in worktree; `gh run view <id> --json jobs` |
| S5 | `ci.yml:9-11` has `concurrency: group: ci-${{ github.ref }}, cancel-in-progress: true` → any push to the branch cancels the in-flight CI run. | `.github/workflows/ci.yml` |
| S6 | Branch is **0 behind / 4 ahead** of `origin/main` (merge-base = `ab610933`), worktree clean (`git status --short` empty). | `git rev-list --left-right --count origin/main...HEAD` → `0 4` |
| S7 | Other open PRs: **#328** `codex/jeeb-firebase-contract-mobile-20260903` (ready, 41 files) overlaps #335 on **2 files**: `.github/workflows/flutter-ci.yml`, `lib/app/app.dart`. **#268** (3 files) overlaps on 0. | `gh pr view 328/268 --json files` ∩ `git diff --name-only origin/main...HEAD` |
| S8 | `origin/epic/wallet-guard-fix` is **130 behind / 1 ahead** of main; its 35 changed files overlap #335 on **22 files** (list in §6). | `git rev-list --left-right --count origin/main...origin/epic/wallet-guard-fix` |
| S9 | PR #330 token-refresh file `lib/core/network/auth_interceptor.dart` **is modified** by #335 (+29/−3): adds `BearerAuthInterceptor.storeUnavailableFlag` (NET-02), `TokenRefreshInterceptor.recoveringFlag` (NET-17), an early `handler.next(err)` when the store was unreadable, `_inCooldown` getter, and `AuthLossReason` on `_logout`. All additive; `sessionBearerFlag` gate, `auth/refresh` exclusion, cooldown and replay paths are untouched. Needs a focused reviewer (§5 lane 0A). | `git diff origin/main...HEAD -- lib/core/network/auth_interceptor.dart` |
| S10 | Repo allows squash, merge-commit and rebase merges; `delete_branch_on_merge: false`. Recent history mixes squash (#332–#334) and merge commits (#330, #331). | `gh api repos/olivium-dev/jeeb-mobile` |
| S11 | Live dev gateway `https://msi.olivium.space/gateway/health/ready` → 200 (aggregate `Degraded`, roster includes `refresh-role-continuity`); `GET /v1/notifications` unauthenticated → `401 application/problem+json` (RFC 7807, `traceId` present). | `curl` 2026-09-05 |
| S12 | Last shipped internal builds: Android Dev Tool `1.0.0+26090403 @ ab610933` (RC run `33885209915`, distribute `33886660870`); TestFlight `1.0.0+26090402 @ 665aa939` (RC `33880239741`, distribute `33881995845`). Next build numbers must be > these. | `gh run list --workflow trusted-*/distribute-*` |
| S13 | Phone build of this branch already exists: `build/app/outputs/flutter-apk/app-dev-debug.apk` in the worktree (last built for run 3 at `ecfd3cc1`). Worktree needs 2 gitignored inputs copied from the main clone (`android/app/google-services.json`, `android/app/src/dev/google-services.json`, project `jeeb-5a293`) and `-PMAPS_API_KEY=…` as a Gradle property (`android/local.properties` is rewritten by `flutter build`). | `device-evidence-2/build/REPORT.md`, `device-evidence-3/REPORT.md` "Build note" |
| S14 | l10n is hand-authored (`docs/adr/0001-hand-authored-l10n-layer.md`); `lib/l10n/app_localizations.dart` is not generated → merge conflicts there are resolved by hand and validated by `qa/t-mob-fix-002/l10n_parity_check.sh --analyze`. ARB grew by ~447 EN / ~437 AR keys on this branch. | `git show origin/main:lib/l10n/app_en.arb \| grep -c` vs head |
| S15 | Gateway `origin/main@6679f6e` (#576, 2026-09-04): `JeebNotificationsInboxController.cs:60` serves `v1/notifications`; `Row.Ref` is filled only for offer rows via `_offerRequestIndex.ResolveRequestId` (lines 180-213), null otherwise → OWNER-CONFIRM (b) D1 stands; mobile parser reads `json['ref']` first (`lib/features/notifications/data/dio_notifications_repository.dart:77`). Not a P10 blocker; recorded for §6. | `git -C jeeb-gateway show origin/main:…` |

**Root cause of the red PR**: not a failing test — a CI **timeout margin**. The `test` job has a fixed 20-minute cap (`ci-flutter-stage.yml:55`) and this branch's suite takes 19m09s–20m+ on `ubuntu-24.04`, so `CI ready` (a required context) fails nondeterministically (1 pass, 2 cancels out of 3 runs).

---

## 1. Definition of "ready-for-review" and "mergeable"

Ready-for-review (RFR) = all of:
- R1 all 5 required contexts SUCCESS on the head SHA, with ≥ 5 minutes of headroom in the `Flutter stage / Test` job;
- R2 branch is 0 behind `origin/main` (strict protection);
- R3 PR body = `scratchpad/pr-body.md` (already applied, 6017 bytes) + a "Reviewer map" comment (§5) + the ADR/migration note committed (§6);
- R4 the head SHA has a real-device smoke receipt (§7.1) — run 3 covers `ecfd3cc1`; any new commit on the branch needs a re-smoke;
- R5 owner decisions in §9 answered (or explicitly deferred as post-merge follow-ups).

Mergeable = RFR + the lane reviews in §5 posted with no unresolved "BLOCK" item + merge method chosen (§8).

---

## 2. Fix the CI timeout (one of the required-check blockers)

**File**: `.github/workflows/ci-flutter-stage.yml` (branch worktree).
**APPLIED 2026-09-06 in the local review-fix wave:** test-job `timeout-minutes` is now 35 (OD-12). A green CI run on the resulting pushed head is still required; the independent rubyzip security gate remains blocked.
Rationale: main takes 16m24s, this branch 19m09s–19m29s; `flutter-ci.yml` already grants the same suite 40 min. 35 keeps the cap below Flutter CI's and gives ~15 min headroom. Do NOT add `--concurrency`/sharding in this PR (sharding is follow-up F1 in §10 — it changes the required-context names and therefore branch protection, which is owner-gated).

Commit message (comment ≤ 2 lines rule applies to code only; this is a commit):
```
ci(flutter-stage): raise test job timeout 20→35 min — suite grew 8257→10539 tests, main takes 16m24s, this branch 19m09s+ and was cancelled twice at the 20-min cap (runs 33949836941, 33962190208)
```
Steps:
1. `cd /Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile-worktrees/ux-api-errors && git fetch origin && git status --short` (must be empty, 0 behind).
2. Edit line 55 as above. `git add .github/workflows/ci-flutter-stage.yml && git commit`.
3. SUPERSEDED by OD-0 `widen`: the scope freeze is void. Mobile follow-ups land as grouped commits on #335; the integration owner pushes one validated batch and lets its checks finish, because another push cancels in-flight CI. Post-deploy-only evidence still waits for the separately authorized deployment.
4. `gh pr checks 335 --watch --required` — wait for all 5 required contexts. Expected: `Flutter stage / Test` ≈ 19–21 min, `CI ready` SUCCESS.
5. Record the "Run tests" step duration from `gh api repos/olivium-dev/jeeb-mobile/actions/jobs/<test-job-id> --jq '.steps[] | select(.name=="Run tests")'` into the PR "Reviewer map" comment (§5).

Because the PR is same-repo, the `pull_request` event runs the workflow file **from the PR head**, so the raised timeout applies to this very run.

---

## 3. Merge-from-main cadence (strict protection)

Policy for the life of the PR:
- C1 **Before every push** and **before marking ready** and **before merging**: `git fetch origin && git rev-list --left-right --count origin/main...HEAD`. If left > 0 → `git merge --no-ff origin/main` (merge, not rebase: the 4 SHAs `db83ba7a/a48444ba/7a0c386b/ecfd3cc1` are cited by the evidence trail and the PR comments).
- C2 After any merge-from-main, run the **full local gate** (§4) before pushing — never rely on CI alone for l10n conflicts (S14).
- C3 Known conflict hot-spots (collision surfaces from `analysis/RULINGS.md` R2), resolve in this order:
  1. `lib/l10n/app_en.arb`, `app_ar.arb`, `app_localizations.dart` — keep both sides' keys; then `bash qa/t-mob-fix-002/l10n_parity_check.sh --analyze` and `bash qa/t-mob-fix-002/ar_plurals_check.sh` must print 0 strict failures.
  2. `lib/core/di/injection_container.dart`, `lib/core/router/app_router.dart`, `lib/app/app.dart` (OfflineCubit provider + `OfflineBannerHost` in `MaterialApp.builder` must survive).
  3. `lib/devtool/catalog/entries/**` — never delete an entry (R2); catalog floor test `test/previews/preview_structure_test.dart` fails if a preview is lost.
  4. `.github/workflows/flutter-ci.yml` / `ci-flutter-stage.yml` — keep the design-token step + `fetch-depth: 0` + the §2 timeout.
- C4 **PR #328** (ready, not draft) touches `flutter-ci.yml` and `lib/app/app.dart`. If #328 merges first, expect a 2-file conflict; resolution = union (its Firebase-identity guard + our design-token step / OfflineCubit provider). If #335 merges first, tell #328's author the same two files moved (§6 note).
- C5 Cadence: check C1 at least once per working day while the PR is open, and always within the hour before merge (strict mode rejects an out-of-date branch at the merge button).

---

## 4. Local gate (run after every commit on the branch; all must pass)

From the worktree, Flutter 3.44.2 / Dart 3.10.2 (`.fvmrc`):
```
git add -A                                   # R6: untracked .dart files break the receipts test
dart analyze --fatal-infos .                 # not `flutter analyze`
bash tool/check_firebase_core_pin.sh
bash tool/check_design_tokens.sh             # DESIGN_TOKENS_BASE=origin/main
flutter test --exclude-tags capture --coverage   # expect 10539+ pass / 0 fail; time it
bash qa/t-mob-fix-002/l10n_parity_check.sh --analyze
bash qa/t-mob-fix-002/ar_plurals_check.sh
```
Coverage floor 79% (`flutter-ci.yml:64`); branch is at 84.65%. Never `--update-goldens` on `catalog_capture`.

---

## 5. Review split for the 887-file diff (by lane)

Reviews are lane-scoped diffs of the same head SHA: `git diff origin/main...HEAD -- <globs>` (or `gh pr diff 335 | filterdiff`). Each lane reviewer posts ONE PR comment titled `Lane review <id> — PASS|BLOCK` with file:line findings. A `BLOCK` must be fixed on the branch (new commit → repeat §2 step 4, §3 C1, §7.1 smoke). Lane ownership mirrors the programme WPs (`analysis/UX-API-AUDIT.md` §"WP-0A…WP-9", `analysis/RULINGS.md` R5/R7).

| Lane | Globs (repo-relative) | Files (approx) | Reviewer checklist (in addition to R6 non-negotiables) |
|---|---|---|---|
| **0A network/session** | `lib/core/network/**`, `lib/core/session/**`, `lib/app/**`, `lib/core/di/**`, `lib/features/offline_mode/**`, `test/core/network/**`, `test/app/**` | ~55 | **PR #330 invariants** on `auth_interceptor.dart` (S9): `sessionBearerFlag` gate intact; terminal logout only on 401/403 reactive path; dedicated retry Dio; 20s cooldown; FormData never replayed; new NET-02 early-return happens **before** the refresh path and never clears tokens. `AppFailureInterceptor` is last in `MockGatewayClient.createDio`; `sendTimeout: 30s`; `RateLimitInterceptor` per-path-prefix. |
| **0B kit/copy/gates** | `lib/core/widgets/jeeb/**`, `lib/core/theme/**`, `lib/core/state/**`, `lib/l10n/**`, `test/core/widgets/**`, `test/previews/**`, `test/guardrails/**`, `test/l10n/**`, `test/tools/**`, `tool/**`, `.github/workflows/**` | ~50 (+3 ARB) | `JeebFailureBlock`/`.compact`, `showJeebErrorSnack` (`persist: false`, `kJeebSnackDuration`/`kJeebSnackActionDuration`), `OfflineBannerHost` reversed column + regression test; ratchet floors never raised for banned patterns, preview floor never lowered (Reconciled C11: P12 Change A sets `failure_identifier_coverage_ratchet_test._kFloor` 0→26 — that is a REPAIR of a vacuous `"'\$id'"` literal match, not a raise of a banned-pattern floor; PASS it); every new ARB key has EN+AR+`@description`+accessor; plural sets in `plural_forms_test.dart`. §2 timeout change. |
| **1 chat** | `lib/features/chat/**`, `lib/features/shell/tabs/chat_tab.dart`, `lib/features/deep_link_targets/**chat**`, `test/features/chat/**` | ~45 | Firestore transport untouched (one `.snapshots()` per thread); `fetchAccepted` throws instead of `[]`; error branch before empty. |
| **2 jeeber home/feed** | `lib/features/{jeeber_home,jeeber_request_feed,jeeber_pending_offers,jeeber_active_deliveries,jeeber_request_detail}/**`, `lib/features/shell/tabs/dashboard_tab.dart`, `shell_screen.dart`, `tab_visibility.dart`, `widgets/jeeber_tab_empty_state.dart`, `lib/core/router/**`, matching `test/**` | ~60 | F2/F3 fix: dashboard gates on failed load (never "Become a Jeeber" during an outage); feed repo rethrows; `refresh()` never flips to loading. |
| **3 client home/orders** | `lib/features/{home_client,client_offers,order_history,delivery_man_profile,no_offer_timeout}/**`, `shell/tabs/{home_tab,orders_tab}.dart`, matching `test/**` | ~70 | F1 fix (`order_history_loading` on first load + retry); F9 `CancelledRequestSignals`; 409/410 suffix mapping on offers. |
| **4 request funnel** | `lib/features/{request_summary,request_type,tier_selection,location,voice_request,transcription,prohibited_acknowledgment}/**`, matching `test/**` | ~75 | Idempotency-Key preserved on resubmit; prohibited 409 → ack sheet; location/search failures typed. |
| **5 offers/wallet/earnings** | `lib/features/{offers,wallet,earnings,settlement,goods_cost,jeeber_onboarding_funding}/**`, `shell/tabs/earnings_tab.dart`, matching `test/**` | ~85 | **Wallet epic overlap (S8)** — note every changed public signature in `dio_wallet_repository.dart`, `offer_submission_repository.dart`, `offers_repository.dart` for §6; no `implements` widening (R3). |
| **6 delivery execution** | `lib/features/{active_delivery_jeeber,otp_handover,background_gps,live_tracking,delivery_status,delivery_receipt,cancellation,cancel_request,rating,order_summary,masked_call,client_unreachable,mixed_direction}/**`, `deep_link_targets/delivery_detail_screen.dart`, matching `test/**` | ~95 | Door handover `{verified:false}` is NOT delivered; receipt 422 is not success; rating failure surfaces; SSE live position untouched. |
| **7 trust/support/notifications/profile** | `lib/features/{escalate,dispute_status,support,case_evidence,reviews,customer_profile,notifications,prohibited_item_report,rate_app,photo_attachment}/**`, `lib/core/notifications/**`, matching `test/**` | ~90 | F4 (no placeholders while loading/retry), F7 (per-user notification scope), F8 (`notifications_cannot_open` snack-and-stay); parser reads `ref` (S15). |
| **8a identity / 8b account** | `lib/features/{registration,auth,biometric_login,biometric_auth,password_security,profile_name,language}/**`, `lib/core/locale/**` / `lib/features/{settings,account_status,notification_prefs,kyc,kyc_rejected,offer_kyc_gate,jeeber_onboarding}/**`, `shell/tabs/profile_tab.dart`, `lib/core/onboarding/**`, `lib/core/session/jeeber_kyc_status_gate.dart`, matching `test/**` | ~120 | UX-05 DM-onboarding fail-safe contract (404/405/501 resolve + `Diag.event('dm_onboarding_submit_route_absent')`, 409 `out_of_coverage` typed) — confirm path constant is the one in OWNER-CONFIRM (a); account deletion no longer always "done"; OTP 429 countdown. |
| **9 devtool catalog** | `lib/devtool/**`, `test/devtool/**`, `test/release/**` | ~75 | No repository interface signature changed without its catalog implementor updated (R3); `devtool_import_closure_test.dart` change is scope-only; `catalog_smoke_test.dart` renders all states untagged. |

Cross-cutting items every lane checks: identifier grammar `<screen>_loading|_empty|_error` + `<screen>_retry_cta` with `container: true`; tests assert by `find.bySemanticsIdentifier` in EN+AR; no `e.toString()` in user copy; comments ≤ 2 lines; only Network/Timeout blame connectivity.

Reviewer-map comment (post on the PR once §2 is green) must contain: the lane table above with reviewer names, the head SHA, the "Run tests" duration, and the link to run 3 evidence (`device-evidence-3/REPORT.md`).

---

## 6. Migration notes for other branches (commit as a repo doc + PR comment)

Create `docs/adr/0004-app-failure-model.md` on the branch (next free ADR number after 0003; ≤ 1 page) with:
1. **Decision**: one `AppFailure` sealed model (`lib/core/network/app_failure.dart`), one mapping point `AppFailure.of(Object)` / `AppFailureInterceptor` (`app_failure_mapper.dart`), one RFC 7807 parser `GatewayProblem` (`gateway_problem.dart`), one presentation kit (`lib/core/widgets/jeeb/jeeb_failure_block.dart`, `jeeb_snack.dart`, `jeeb_refresh_failed_note.dart`, `jeeb_state_host.dart`), one copy resolver `app_failure_copy.dart`.
2. **Rules for any branch rebased onto this** (verbatim from RULINGS R3/R6): catch `AppFailure` subtypes, never `DioException`; repositories throw, never `return const []` on failure; cubit `status {initial,loading,loaded,failed}` + typed error; `refresh()` never flips to loading; error branch before empty; identifier triple; no new `*_l10n.dart` resolvers; ARB keys EN+AR+accessor; ratchet tests in `test/guardrails/**` fail on any new `showOmdsErrorSnackbar` / raw `ScaffoldMessenger.showSnackBar` under `lib/features/**` / bare `OmdsPullToRefresh` / `OmdsErrorState`/`OmdsLoadingState`; `tool/check_design_tokens.sh` is diff-scoped in CI.
3. **`implements` trap**: repository/gateway interfaces are implemented under `lib/devtool/catalog/**`; grep implementors before changing a signature (R3).
4. **Branch-specific notes**:
   - `epic/wallet-guard-fix` (130 behind main, 22 overlapping files): `lib/features/client_offers/{data/dio_offers_repository.dart,domain/offers_repository.dart,presentation/client_offers_screen.dart,presentation/widgets/offer_accept_sheet.dart}`, `lib/features/notifications/{domain/notifications_repository.dart,presentation/notifications_l10n.dart,presentation/notifications_list_screen.dart}`, `lib/features/offers/{application/offer_submission_cubit.dart,data/dio_offer_submission_repository.dart,domain/offer_submission_repository.dart,presentation/offer_composer_l10n.dart,presentation/offer_submission_screen.dart}`, `lib/features/wallet/data/dio_wallet_repository.dart`, `lib/l10n/{app_en.arb,app_ar.arb,app_localizations.dart}`, and 6 tests (`test/features/client_offers/offers_failure_copy_test.dart`, `test/features/notifications/notifications_list_screen_test.dart`, `test/features/offers/dio_offer_submission_repository_test.dart`, `test/features/offers/offer_composer_error_l10n_test.dart`, `test/notification_deep_link_test.dart`, `test/offer_form_cubit_test.dart`). Recommendation: **re-baseline the epic as a new branch off post-merge main** (memory already says re-baseline; do not attempt a 130-commit merge); re-apply the fee-guard exposure logic on top of `OfferSubmissionCubit`'s `AppFailure` error path and map wallet `409 …/errors/insufficient_balance` through `GatewayProblem.reasonCode`, not a new enum.
   - **PR #328**: after #335 lands, `git merge origin/main`; expect conflicts only in `.github/workflows/flutter-ci.yml` (keep both the Firebase step and the design-token step; keep `fetch-depth: 0`) and `lib/app/app.dart` (keep `OfflineCubit` provider + `OfflineBannerHost`).
   - **PR #268**: no overlap; merge main normally.
   - Any branch adding a screen: ship `<screen>_loading|_empty|_error|_retry_cta` identifiers + EN/AR tests, a catalog entry + fixture under `lib/devtool/catalog/fixtures/`, and a preview (preview floor 247+ in `test/previews/preview_structure_test.dart`).
5. **Owner-confirm items carried over** (not blockers for this PR): (a) DM-onboarding submit route constant; (b) gateway D1 — `/v1/notifications` rows carry `ref` only for offer rows (S15); (c) create-request min-length validation; (d) test request `defb1f07-…` auto-expires 2026-09-06 11:21 UTC.

Also paste items 2–4 as a PR comment titled `Migration notes for other branches` so they are visible without checking out.

---

## 7. Rollout / rollback on a phone build

### 7.1 Pre-merge smoke on the real device (required for every new head SHA)
Device SM-A336B `RZCT505K7WF`, alias `app.jeeb.mobile.dev`, never uninstall, never "Clear Local Data".
1. Preserve a rollback APK first: from the **main clone** `/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile` at `origin/main` build once (same command as step 3) and copy to `$SCRATCH/rollback/app-dev-debug-ab610933.apk`. (If the worktree APK from run 3 is still at `ecfd3cc1`, also keep it as `app-dev-debug-ecfd3cc1.apk`.)
2. In the worktree: `cp ../../jeeb-mobile/android/app/google-services.json android/app/ && cp ../../jeeb-mobile/android/app/src/dev/google-services.json android/app/src/dev/` — verify `grep project_id android/app/google-services.json` prints `jeeb-5a293`.
3. `flutter build apk --debug --flavor dev -t lib/main.dart -Pjeeb.devtool=true -PMAPS_API_KEY=<key from jeeb-mobile/android/local.properties> --dart-define=JEEB_DEVTOOL_ENABLED=true` → `build/app/outputs/flutter-apk/app-dev-debug.apk` (~190 MB). Record `git rev-parse HEAD` next to it.
4. `adb -s RZCT505K7WF install -r build/app/outputs/flutter-apk/app-dev-debug.apk` → `Success`. Unlock, cold-start **twice** (first boot can lose the secure-storage race).
5. Confirm session survived (client `devtool_client_1788592148874` or jeeber `Karim TestJeeber` via Dev Tool → Super Login Plus) and `dev.base_url_override` = `https://msi.olivium.space/gateway`.
6. Smoke (6 checks, uiautomator dump per step into `$SCRATCH/device-evidence-4/`): Dev Tool → Server URL → `http://10.255.255.1:9` → Apply & Restart; (i) Requests/order history shows `order_history_loading` then `order_history_error` + `order_history_retry_cta` (never `_empty`); (ii) jeeber Deliver tab shows error/retry, not "Become a Jeeber"; (iii) Profile shows `customer_profile_loading` with no placeholder name/avatar, then error; (iv) `offline_banner` node present with `content-desc`; restore the MSI URL → Apply & Restart; (v) banner and `order_history_refresh_failed_snack` clear without a tap; (vi) live list loads real rows. PASS = 6/6; attach the dir path to the PR.
7. Leave the phone on the branch build (it is the candidate); rollback = §7.3.

### 7.2 Post-merge internal distribution (PREPARE ONLY — owner dispatches)
All three workflows are `workflow_dispatch` on protected `main` and fail-closed on non-main refs. After the merge SHA `M` exists and its required contexts are green (iOS RC checks `Flutter CI + coverage (79%)`, `L10n parity gate (T-MOB-FIX-002)`, `Release security scans` on `M`; Android RC does not):
```
# Android Dev Tool internal (Play internal track)
gh workflow run trusted-android-internal-devtool-rc.yml -f reviewed_sha=<M> -f build_name=1.0.0 -f build_number=26MMDD01
gh workflow run distribute-android-internal-devtool.yml -f source_run_id=<RC run id> -f reviewed_sha=<M> -f build_name=1.0.0 -f build_number=26MMDD01
# iOS (TestFlight internal)
gh workflow run trusted-mobile-rc.yml -f reviewed_sha=<M> -f build_name=1.0.0 -f build_number=26MMDD02 -f platform=ios
gh workflow run distribute-mobile-internal.yml -f source_run_id=<RC run id> -f reviewed_sha=<M> -f build_name=1.0.0 -f build_number=26MMDD02
```
Build numbers are date-coded `YYMMDDNN`, must exceed `26090403` (Android) and `26090402` (iOS), distinct NN per store on the same day. Write the exact commands with the real `M` into the PR's final comment; do not run them (owner-gated).

### 7.3 Rollback
- **Device lane** (immediate): `adb -s RZCT505K7WF install -r $SCRATCH/rollback/app-dev-debug-ab610933.apk` (in-place downgrade of a debug build keeps the session; never uninstall). If Android refuses the downgrade (`INSTALL_FAILED_VERSION_DOWNGRADE`), use `adb install -r -d`.
- **Store lane** (forward-only): Play/TestFlight reject reused build numbers, so rollback = redeploy a known-good build forward: commit a new change on a branch that undoes `<M>` (or the squash commit) → PR → merge → new RC with the next build number via §7.2. The prior retained artifacts (`26090403`, `26090402`) stay installed on testers' devices until then.
- There is **no server-side flag** for this change (pure client-side error model); the kill switch is the build. State this in the PR.

---

## 8. Marking ready and merging

1. Preconditions: §2 green with ≥ 5 min headroom; §3 C1 = `0 N`; §5 all lanes `PASS`; §6 ADR committed; §7.1 receipt for the head SHA.
2. `gh pr ready 335` (converts draft → ready). Request review from the owner (`.github/CODEOWNERS` = `* @oudaykhaled`): `gh pr edit 335 --add-reviewer oudaykhaled` (self-owned repo; `required_approving_review_count` is 0, so the owner merges after lane reviews).
3. Merge method (owner decision D2, §9): recommended **squash** to match #332–#334 convention, with the 4 branch SHAs listed in the squash body, and **keep the branch** (`delete_branch_on_merge` is already false) so the evidence SHAs stay reachable. If the owner prefers a merge commit (as #330/#331), use `gh pr merge 335 --merge`.
4. Within the hour before merging: re-run §3 C1; if main moved, merge main, re-run §4, wait for CI, re-smoke (§7.1) only if any Dart file changed in the merge.
5. After merge: capture `M`, run the §7.2 preparation, post the final PR comment (commands, rollback APK path, follow-ups §10).

---

## 9. Owner decisions (exact questions)

> Answered since this historical questionnaire: OD-12 = 35 minutes, OD-13 = squash and keep branch, OD-14 = both stores the first day after merge. OD-15 is superseded by the wallet-independence rule and P15 train. Do not ask these old questions again; deployment, merge and upstream filing still require their designated owner actions.

- **D1** Approve raising `ci-flutter-stage.yml` test job `timeout-minutes` 20 → 35 (one-line CI change on the PR) instead of sharding the suite now? (yes/no)
- **D2** Merge method: squash + keep branch (recommended) or merge commit? (squash/merge)
- **D3** Dispatch the internal RC + distribute workflows for the merge SHA on Play internal and TestFlight (§7.2)? (yes/no; if yes, which day → sets `26MMDDNN`)
- **D4** Re-baseline `epic/wallet-guard-fix` as a fresh branch off post-merge main (recommended) rather than merging 130 commits into it? (yes/no)
- Carried, non-blocking: OWNER-CONFIRM (a) DM-onboarding path constant, (b) gateway D1 target ids, (c) create-request validation, (e) ratchet residuals.

---

## 10. Follow-ups (landing amended by OD-0 widen)

> F2/F3/F4 mobile work rides #335 in validated batches, not separate stacked PRs. Gateway changes remain separate; captured post-deploy evidence waits for its deployment. P01's route flip remains post-deploy/post-merge under v3, and sharding/branch-protection changes remain owner-gated.
- F1 Shard the `Flutter stage / Test` job (`flutter test --total-shards 2 --shard-index N` matrix) and re-point branch protection at the aggregated `CI ready` only — reduces wall time to ~10 min; needs owner to edit required contexts.
- F2 = **P05** (guardrail residuals). Reconciled: the `onboarding_funding_screen.dart:349` claim is stale — that rung already reads `fundingWalletLoadingHeadline` on the branch; the one remaining title-as-headline hit is `jeeber_feed_tab_view.dart:480`, plus 3 `showOmdsErrorSnackbar` and 4 lib-wide `Omds*State` sites (P05 §0).
- F3 = **P07** (AR on device), **P08** (4xx/5xx/429/RFC 7807 via the shared fault proxy), **P09** (never-exercised surfaces), **P11** (F6 reconnect isolation), **P13** (unreachable-host copy), **P06** (greeting after failed read).
- F4 = **P02** (gateway emits request-id `ref` + mobile-grammar `deepLink`; mobile kind mapper learns `chat`/`delivery`/`availability`/`request.*`). Reconciled (C4): the mobile `_reference` parser keeps reading `ref` first and is neither widened nor dropped in P02; retiring the 13-key fallback is a later cleanup. Gateway P01 (onboarding route) and P03 (create-request validation) ride the same combined owner deploy (C14).

---

## 11. Risks
- Raising the timeout hides further suite growth; F1 is the real fix.
- `cancel-in-progress: true` — a stray push mid-run reads as a failure; batch pushes.
- Merge-from-main conflicts in hand-authored `app_localizations.dart` can silently drop an accessor → only the parity script catches it; never resolve ARB conflicts by taking one side.
- Reviewer fatigue on 887 files: lanes are mandatory; a single "LGTM" on the whole PR is not acceptable evidence.
- Debug-build downgrade on the phone may need `-d`; store rollback is forward-only.
- `auth_interceptor.dart` edit touches PR #330 territory; if lane 0A finds any change to the refresh path semantics, it is a BLOCK.

## Reconciled (2026-09-05 conflict review — see plans/CONFLICT-REVIEW.md)

- SUPERSEDED by OD-0 `widen`: mobile follow-ups ride #335 in validated batches, with the l10n/identifier serialization retained. The earlier three-commit restriction and stacked-branch requirement are void. Deployment-dependent work and device proof remain gated; the security audit is not bypassed.
- Reconciled (C12): §7.1 smoke evidence goes to `scratchpad/device-evidence-4/p10-smoke/` (the root REPORT.md is not shared).
- Reconciled (C14): §6 item 5 carried items map to P01 (a), P02 (b), P03 (c), P04 (d), P05 (e); the three gateway PRs get
  ONE combined MSI deploy + ONE staging dispatch (OD-3) — do not ask the owner for three.
- Owner decisions renumbered: OD-12 (D1 timeout 20→35), OD-13 (D2 merge method), OD-14 (D3 dispatch RC/distribute),
  OD-15 (D4 re-baseline `epic/wallet-guard-fix`).
