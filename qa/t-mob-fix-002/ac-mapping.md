# AC → Script/Check Mapping — T-MOB-FIX-002

**Source of truth**: JEB-2 comment `14782` (Tech Lead, APPROVED-WITH-AC-REWRITE), STORY-DESCRIPTION-DELTA at the bottom of that comment.
**Purpose**: deterministic mapping from each Acceptance Criterion to the script(s), test(s), or human check that validate it. QA-POST (`JEB-226`) uses this table as its checklist; ENG (`JEB-227`) uses it as the merge gate.

---

## AC table (LEAD rewrite — supersedes the original 5-AC set)

| AC | Title | Validates | Validation artifact(s) | Strict? | Owner of evidence |
|---|---|---|---|---|---|
| **AC1** | build parity | `S1 ⊆ S2 ∧ S2 == S3 == S4 ∧ no value == key ∧ flutter analyze 0-error` | `qa/t-mob-fix-002/l10n_parity_check.sh --analyze` exits **0** | Yes | QA-POST (CI artifact) |
| **AC2** | visual + presence gate | Six AR-rendering quality bars across two viewports | `.maestro/l10n-ar/_runner.yaml` (executes the 11-item `qa/t-mob-fix-002/ar-visual-checklist.md`) | Yes | QA-POST (Maestro report + screenshots) |
| **AC3** | flutter analyze clean | `flutter analyze lib/` reports 0 issues | `flutter analyze lib/` last-20-lines pasted by ENG in AC-FINAL comment + CI job artifact | Yes | ENG / QA-POST |
| **AC4** | CI gate present | A separate job `l10n-parity` exists, runs the script + the runtime test, fails loud, uploads artifacts on failure | `.github/workflows/mobile-ci.yml` job named `l10n-parity` is green on the ENG PR | Yes | ENG (workflow file) / QA-POST (green check link) |
| **AC5** | 4-set parity | `S2 == S3 == S4 ∧ S1 ⊆ S2` | `qa/t-mob-fix-002/l10n_parity_check.sh` exits **0** (re-runs the same script — AC5 is subsumed by AC1 but kept for traceability) | Yes | QA-POST (CI artifact) |
| **AC6** | l10n-correctness (plurals) | Every restored numeric-placeholder getter has all six AR CLDR forms in `app_ar.arb` + plural unit tests green | `qa/t-mob-fix-002/ar_plurals_check.sh` exits **0** AND `test/l10n/plural_forms_test.dart` green | Yes | QA-POST |
| **AC7** | copy-fidelity / Figma | Per-feature-root attestation from ENG that restored copy matches latest Figma (or "no Figma frame cited") | ENG posts six one-line attestations in the AC-FINAL Jira comment | Yes | ENG attests, UX (`JEB-223` reviewer) arbitrates disputes |
| **AC-FINAL** | process | PR link, SHA, screenshots, repos+branch, Figma deviations, test-output | Closing Jira comment on `JEB-2` per parent template | Yes | ENG |

---

## Script → AC reverse index

| Artifact | AC(s) covered |
|---|---|
| `qa/t-mob-fix-002/l10n_parity_check.sh` (static) | AC1 (a, b, c, d, e), AC5 |
| `qa/t-mob-fix-002/l10n_parity_check.sh --analyze` | AC1 (f), AC3 |
| `qa/t-mob-fix-002/ar_plurals_check.sh` | AC6 (ARB-side) |
| `qa/t-mob-fix-002/ar-visual-checklist.md` (executed via Maestro) | AC2 |
| `.github/workflows/mobile-ci.yml` job `l10n-parity` | AC4 |
| `test/l10n/runtime_parity_test.dart` *(ENG-authored per LEAD §3)* | AC1 (d, e) at runtime; backstop for V2 in checklist |
| `test/l10n/plural_forms_test.dart` *(ENG-authored per LEAD §4)* | AC6 (runtime-side) |
| Per-root Figma attestation lines in AC-FINAL comment | AC7 |

---

## Pass/fail decision rule

A subtask, PR, or QA cycle is **PASS** iff every strict AC above is PASS. There is no "partial credit" mode — LEAD §3 explicit: *"Pass/fail criteria are the conjunction (a)..(f). No partial credit."*

Warn-only signals (do NOT block):
- `qa/t-mob-fix-002/l10n_parity_check.sh` orphan-getter list (S2 \ S1) — non-blocking, but emit `/tmp/orphan_getters.txt` for follow-up cleanup.
- `qa/t-mob-fix-002/ar_plurals_check.sh` numeric-no-plural list — pre-existing non-plural numeric strings (e.g. error messages with a count) stay flagged for QA-POST review but do not block.

---

## Mapping notes / gotchas

- **AC1 vs AC5 redundancy is intentional.** LEAD kept AC5 in the rewrite to preserve traceability with the original ACs in the Story description; both reduce to the same script invocation.
- **AC2 cannot be auto-verified from `l10n_parity_check.sh` alone.** Presence-of-string is necessary; presentation-of-string is what users feel (UX §5 closing line). The Maestro suite is the authoritative gate.
- **AC6 has two parts.** The ARB-side check (`ar_plurals_check.sh`) ensures the six CLDR forms exist in the ARB. The runtime-side test (`plural_forms_test.dart`) ensures the loader picks the right one for `count ∈ {0,1,2,3,11,100,1000}`. Both must be green.
- **AC7 is human attestation.** No script enforces Figma fidelity — UX reviewer (`JEB-223` reviewer assignment per LEAD §6) arbitrates.
- **AC3 vs `--analyze` flag.** `flutter analyze` runs locally via the `--analyze` flag on the parity script for one-shot validation; in CI it lives as a separate `flutter-test` job whose result mirrors the `l10n-parity` job. Both must be green on the ENG PR.

---

## Runbook — ENG (`JEB-227`) local pre-push verification

```bash
cd jeeb-mobile
bash qa/t-mob-fix-002/l10n_parity_check.sh --analyze   # AC1, AC3, AC5
bash qa/t-mob-fix-002/ar_plurals_check.sh              # AC6 (ARB side)
flutter test test/l10n/                                # AC6 runtime + AC1 d/e runtime
maestro test .maestro/l10n-ar/_runner.yaml             # AC2 (locally; CI runs sharded)
```

All four commands MUST exit 0 before opening the PR. Local Maestro flake → retry once; persistent flake → flag QA-POST per skill `playwright-flake-quarantine-protocol` (concepts transfer to Maestro).

## Runbook — QA-POST (`JEB-226`) PR verification

```bash
# 1. Pull ENG PR head
gh pr checkout <PR_NUM>

# 2. Re-run the gate locally (do not rely on CI-only signal)
bash qa/t-mob-fix-002/l10n_parity_check.sh --analyze
bash qa/t-mob-fix-002/ar_plurals_check.sh
flutter test test/l10n/

# 3. Execute Maestro suite at BOTH viewports × BOTH locales
maestro test --device=320x568 .maestro/l10n-ar/_runner.yaml
maestro test --device=360x640 .maestro/l10n-ar/_runner.yaml

# 4. Diff baselines against produced screenshots; attach any FAIL frames
#    with red bounding boxes to the QA-POST Jira comment on JEB-2.

# 5. Verify ENG's six Figma attestations for AC7 are present.

# 6. Post pass/fail per item to JEB-2; on full PASS, transition JEB-226 to Done.
```

QA-POST is BLOCKED until all of AC1–AC7 are PASS. No conditional approvals (LEAD §7).
