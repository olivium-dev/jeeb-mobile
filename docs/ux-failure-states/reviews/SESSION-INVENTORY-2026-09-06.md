# Session inventory — repositories, PRs, branches (2026-09-05/06, UX/API-error programme)
# CORRECTED 2026-09-06 after 16 independent reviews (docs/ux-failure-states/reviews/INVENTORY-REVIEW-2026-09-06.md)

> **Historical snapshot at 050051d6.** The later review commit is f9eaf63d. The local review-fix wave updates code, plans and CI; use its handoff/gate receipt for current status, not the historical clean/CI/patch claims below.

## Written to (commits pushed)
- olivium-dev/jeeb-mobile — https://github.com/olivium-dev/jeeb-mobile
  - branch: ux/api-error-handling-empty-states (merge-base origin/main ab610933; HEAD 050051d6; 13 ahead / 0 behind; worktree clean)
  - 4 code commits (db83ba7a, a48444ba, 7a0c386b, ecfd3cc1) are the only ones touching lib/ and test/; 9 docs-only commits
  - worktree: /Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile-worktrees/ux-api-errors
  - PR #335 (draft, MERGEABLE but BLOCKED): https://github.com/olivium-dev/jeeb-mobile/pull/335
    - PASS: Flutter stage/Analyze, Flutter CI + coverage (79%) [10539/0, 84.64%], verify, L10n parity gate
    - FAIL: Release security scans (rubyzip 2.4.1, CVE-2026-85396); Flutter stage/Test repeatedly cancelled at the 20-min cap → CI ready red (OD-12 raise-to-35 approved, NOT yet committed); Android/iOS stages skipped
    - body stale (says 4 commits); OD-0 widen not recorded on the PR; 6/13 commits and 3/5 comments lack the session URL

## Cloned read-only (scratchpad), nothing pushed
- fastlane/fastlane — https://github.com/fastlane/fastlane
  - local branch fastlane-core/allow-rubyzip-3 (base master 280c8e887, master unmoved) → fastlane.patch (git am -k; 3 files +4/−4; single rubyzip call site; spec 8/0 on rubyzip 2.3.2/2.4.1/3.4.0/3.6.0) — FOR THE OWNER TO FILE after stripping the Claude-Session/Co-Authored-By trailers and confirming the author email
- rubyzip/rubyzip — https://github.com/rubyzip/rubyzip
  - local branch backport/2.4.2-cve-2026-85396 (base branch 2.4 @ 6c4b7a9 = v2.4.1, NOT main; unmoved) → rubyzip-2.4.2.patch (git am --3way; entry.rb hunk byte-identical to 17edfbf; 326/0 tests; mutation-proven) — FOR THE OWNER TO FILE, same trailer stripping
- olivium-dev/rahmah-gateway — master @ 1cc9596 (Rahma pattern reference; P01 v3 §0 needs the citation fixes listed in the review)
- olivium-dev/rahmah-fe — master @ 03890f1 (renderer dispatches on componentID, not componentName)
- olivium-dev/ofc-form-builder — main @ 7c2bc3b (1.0.5 on pub.fds-4.site; branch PROF-592-salehly-widgets @ 216f36f is the last published 1.0.6-beta.1; wrapper/provider ARE configurable → reuse path exists)
- olivium-dev/rahmah-admin-panel — main @ 873f4bb (zero preference-API usage; no admin precedent for an onboarding-answers view)

## Referenced only (read on GitHub / live hosts, no checkout changed)
- olivium-dev/jeeb-gateway — origin/main 6679f6e; branch epic/wallet-guard-fix (dfa9159d, 5 ahead / 97 behind, no PR ever opened; subject of PLAN-P15; its wallet OpenAPI slice is a 465-byte placeholder — do not replay it back)
- olivium-dev/form-builder-service — origin/main 801ef01 = the SHA live on MSI :10070 (native systemd jeeb-form-builder.service, WorkingDirectory=/home/ec2-user/iter5-services/form-builder-service; generated_jeeb_jeeber_v1.json is in NO git repo); vocabulary gate already red on main, workflow disabled
- olivium-dev/jeeb-mobile — PR #330 (token refresh, merged 0be517e1, invariants intact on the branch), PR #274 (Firebase, merged 357cd655; its config regime was later reversed by PR #276, doctor retargeted by #332 — hook still runs and passes)
- rubysec/ruby-advisory-db — gems/rubyzip/CVE-2026-85396.yml (patched_versions [">= 3.4.0"], no open PR) = the ONLY database our bundle-audit gate reads; GHSA-47m2-wp7j-p9vc is `unreviewed` (no package/range; Dependabot ignores it)

## Planned branches (named in the plans, NOT created yet — verified absent on both remotes 2026-09-06)
- jeeb-mobile: fix/dm-onboarding-route (P01 v3, off post-merge main, only after the gateway route is live)
- jeeb-gateway: fix/notifications-inbox-target-ref (P02-G, wave 0 worktree off origin/main 6679f6ee); fix/p03-create-request-validation (P03-G, wave 0 worktree off origin/main 6679f6ee); feat/form-submissions-preferences (P01 v3); wallet train wgf2/g0-gate … wgf2/g6-defaults (P15; stacking order must be stated)
- jeeb-mobile (P15): wgf2/m1-guard-ui
- form-builder-service: feat/jeeb-onboarding-template (P01 v3; fix D-FB4 target dir and the stale line refs first)
- P02/P03 MOBILE work has NO branch: under OD-0 widen it rides PR #335 (the stacked names in P02 §5 / P03 §5 are voided)

## Links
- Decision site (artifact, v4): https://claude.ai/code/artifact/f06f55d4-e977-4455-9b0a-4061ea2089fd (P01 card + OD-1 options still show the v1 design; 13 plan-card paths wrong)
- Session: https://claude.ai/code/session_01VydEU5hq3ihQ5j6ooPFaEq
