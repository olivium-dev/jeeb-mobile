# Jeeb UX / API-error programme — handover summary, 2026-09-07

Full document, with a receipt behind every number: [HANDOVER-2026-09-07.md](HANDOVER-2026-09-07.md)

## State, in five bullets

1. **PR #335 is a green draft blocked by one owner-gated scan.** 29 commits, 1315 files, +86 880 / −9 540 on `ux/api-error-handling-empty-states` (HEAD `b83a6d2f`, 0 behind `main`). Of 10 checks, 9 pass; `Release security scans` fails on rubyzip 2.4.1 / CVE-2026-85396, as it does on every PR in this repo. `--ignore` is forbidden.
2. **Five backend draft PRs are open, green and unmerged** — gateway #577/#578/#579/#580, form-builder #43. Nothing is merged, nothing is deployed, nothing is on a user's phone.
3. **Batch 2 has no independent verification.** Every `verify:*`, `gverify:*`, judge and fact-check agent aborted on the Fable usage limit; `unresolved` means unverified, not failed. What is real: the local gate (11 186 passed / 0 failed, 85.07 % coverage, capture 509/1/0 with no `--update-goldens`), hosted CI, and six lane self-reports.
4. **22 defects are OPEN** (6 High, 9 Medium, 7 Low), 4 are fixed only on unmerged PRs, 13 are closed here. **10 of 14 plans are NOT DONE**; PLAN-P02 V1–V12, P03 Phase B and P12 §7 have never been executed.
5. **PLAN-P12 Change B is staged in the shared index and uncommitted** — 11 paths, +2 / −1308, its device gate (P09 S1.6) captured and PASS. The workflow that staged it is recorded `killed`; nothing will commit it on its own.

## Next ten actions, in order

1. Commit and push the staged P12 Change B — confirm the index still holds exactly those 11 paths first — then re-run the full local gate.
2. Fix **B2-03**: the shared retryability disagreement mis-renders every `JeebFailureBlock` screen, and widen `fault_proxy_scenarios_test.dart`, which is structurally blind to it.
3. Fix **B2-04** (a 429 renders as the empty state — a false all-clear) together with `GatewayProblem.retryAfter`, which ignores the live snake_case `retry_after`.
4. Fix **B2-07**: a feed-only failure erases the availability card, so the jeeber cannot go off duty.
5. Fix **B2-05 + B2-12** with one inset pattern, and ship **B2-01 + B2-02** together.
6. Fix **B2-10**, then audit every loading→empty pair for the same frozen-identifier false green — it hides in the harness itself.
7. Fix **B2-21** so `run_preflight.sh` is not 403'd by Cloudflare; until then every device lane is blocked or hand-rolled.
8. Re-run the device slots that found defects: P08 S08–S12, P05 V1d, P09's five failing rows.
9. Run a device judge over the six batch-2 lanes, and an adversarial verify of gateway `ca7d28c2` and `d906eedd`.
10. Run PLAN-P12 §7 steps 1–8 and PLAN-P06 §5.3 again (503 rule, EN + AR); post the batch-2 PR body drafted at `SP/batch2/pr-text/BODY.md`.

## Owner-gated — a successor may not do these

* File the upstream fastlane and rubyzip PRs (G1) — the only path that unblocks merging anything into `jeeb-mobile:main`.
* Merge #43 → #580 → #579 (#577/#578 independent), then **one** MSI deploy and **one** staging dispatch (OD-3).
* Flip #335 ready, squash-merge keeping the branch (OD-13), then the next-day RC and distribute dispatches (OD-14).
* Acknowledge two contract changes at merge: the form-builder 503 (a shared fleet service) and P01's nested-preference storage shape.
* Supply one Levantine reference sentence (G6), and settle the three off-register AR keys `faeba877` shipped.
* Answer OD-15a–f and order the wallet currency migrations — the only step in the programme that can strand real money.
* Rule on the specification conflicts B2-16, B2-06, B2-09, B2-19, and on X1 (should gateway `OrderListItem` carry the accepted fee?).
* Authorise one throwaway KYC-verified jeeber, or accept P09's six unexercised empty states on the record.
* Perform the owner's own real-flow acceptance — real OTP login on the owner's own phone. It cannot be delegated.
* Never, under any of the above: `--ignore` or any bypass on the security scan, curl substituted for a UI step, a new repo, an AWS key rotation, or a broad `--update-goldens`.
