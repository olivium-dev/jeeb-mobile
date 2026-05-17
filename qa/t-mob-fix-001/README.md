# QA-PRE scaffold — T-MOB-FIX-001

Authored by Principal QA — Flutter (Jira subtask **JEB-137**, parent Story
**JEB-1**). This directory holds the CI assertions the ENG agent (JEB-139)
must pass before opening a PR, and QA-POST (JEB-138) re-runs after merge.

This is a **build-fix** Story, so there is no Maestro / Patrol / `integration_test`
suite — the deliverable is bash scripts that prove (a) the build is green and
(b) the placeholder discipline pinned by PO / UX / LEAD holds.

## Files

| File | Purpose |
|---|---|
| `build-green.sh` | AC1 + AC2 gate. Runs `flutter pub get`, `flutter analyze --no-fatal-infos`, `flutter build apk --debug --no-pub`, and (on a macOS runner) `flutter build ios --debug --no-codesign --no-pub`. Writes logs to `_artifacts/` for the AC-FINAL Jira screenshot. |
| `placeholder-discipline.sh` | UX rules #1–#10 (Jira comment 14746) + LEAD template (Jira comment 14747) gate. Walks the 11 Type-A files and asserts the OMDS placeholder pattern; walks the 11 Type-B files and asserts they were NOT widget-ified; checks the 4 allowlisted files still exist. |
| `placeholder-discipline-allow.txt` | The 4 files LEAD explicitly excluded from refactor (`request_summary_screen.dart`, `offer_submission_screen.dart`, `jeeber_request_unavailable_screen.dart`, `onboarding_screen.dart`). They have real working logic or are re-export shims. |
| `_artifacts/` | Created at runtime. Pub/analyze/build logs. Last 20 lines of `build-apk.log` and `build-ios.log` are saved for the AC-FINAL Jira comment. |

## How ENG runs it locally before opening the PR

```bash
cd <repo-root>
chmod +x jeeb-code/jeeb-mobile/qa/t-mob-fix-001/*.sh
./jeeb-code/jeeb-mobile/qa/t-mob-fix-001/build-green.sh \
  && ./jeeb-code/jeeb-mobile/qa/t-mob-fix-001/placeholder-discipline.sh
```

Both scripts must exit `0`. Any non-zero exit is a PR blocker — fix the
underlying issue, do NOT relax the assertion.

## Mapping to the parent Story's ACs

| AC | What it says | Where it's checked |
|---|---|---|
| **AC1** | `flutter build apk --debug` shows 0 Class A errors. | `build-green.sh` steps `[AC1.a]`–`[AC1.d]` |
| **AC2** | No NEW analyzer warnings. | `build-green.sh` step `[AC1.b + AC2]` — captures `analyze-summary.txt` so the reviewer can diff against the pre-FIX baseline manually. (Hard baseline is not pinned because Class B / Class C noise is still in the tree until FIX-002 / FIX-003 land.) |
| **AC3** | Renamed feature directories match canonical names. | Covered indirectly: any rename that drifts from canonical breaks an import in `app.dart` / `app_router.dart`, which AC1 catches. Reviewer also eyeballs the diff per LEAD §4. |
| **AC4** | Every truly-missing file has a placeholder + follow-up ticket. | Placeholder shape: `placeholder-discipline.sh` rules A/B/C. Follow-up tickets: ENG opens 5 of them per LEAD §3 (`T-MOB-BIOMETRIC-001`, `T-MOB-LOCATION-001`, `T-MOB-KYC-001`, `T-MOB-RATING-001`, `T-MOB-TRANSCRIPTION-001`) as subtasks of JEB-1414. QA-POST verifies all five exist in Jira. |
| **AC5** | Each placeholder logs `placeholder.<feature>.opened`. | `placeholder-discipline.sh` rule F. LEAD overrode the wording to `debugPrint('[placeholder] $_featureId opened')` because `debugPrint` is already the de-facto logger in `jeeb-mobile` and adding `package:logger` is scope creep. |
| **AC-FINAL** | Jira comment with commit SHA, log screenshot, repos touched, Figma deviations, test command output. | ENG posts using `build-green.sh` artifacts: `_artifacts/build-apk-last20.log` is the screenshot, `_artifacts/analyze-summary.txt` is the analyzer line. Repos touched = `jeeb-mobile` only. Figma deviations = none (build-fix Story). |

## What to do on failure

| Failing script | Common causes | Fix |
|---|---|---|
| `build-green.sh` exits 1 (`pub get`) | new dep mismatch, lockfile drift | Re-resolve; if a transitive bumped, pin in `pubspec.yaml`. |
| exits 2 (`analyze`) | a restored stub has a type error, missing import, or analyzer warning treated as fatal | Fix the type/import. Do NOT add `// ignore_for_file:` to silence; LEAD comment 14747 §1 template doesn't need any ignores. |
| exits 3 (`build apk`) | Class A imports still broken, OR a Type-A file was widget-ified incorrectly | Diff against the LEAD template (comment 14747 §1) line-by-line. |
| exits 4 (`build ios`) | macOS-only path; pod install failure | Run `cd ios && pod install` then retry. Linux CI skips this step. |
| `placeholder-discipline.sh` Rule A FAIL | missing `import 'package:omds/omds.dart';` | Add the import. Do NOT import the OMDS source file directly. |
| Rule B FAIL | file uses `Placeholder()` or raw `Scaffold(body: Text(...))` | Replace body with `OmdsEmptyStatePage(...)` per LEAD template. |
| Rule D FAIL | file calls `AppLocalizations.of(context)` | Strip the l10n call; use English literals. L10n recovery is FIX-002, not this Story. |
| Rule E FAIL | no `Semantics` AND no `OmdsEmptyStatePage` | Use the OMDS page; it inherits semantics from the Text children. |
| Rule F FAIL | `debugPrint` is in `build()` not `initState()` | Move it. Build re-runs on every rebuild and burns the alert budget (UX rule #6). |
| Rule G FAIL | file is `StatelessWidget` | LEAD §1 overrode the PO snippet: must be `StatefulWidget` because `initState()` is the AC5 firing site. |
| Rule H FAIL | `OmdsEmptyStatePage(buttonText: ..., onButtonTap: ...)` | Drop both args — there's nowhere meaningful to navigate (UX rule #5). |
| Rule I FAIL | `CircularProgressIndicator` on the placeholder | Strip it — placeholders are terminal states, not loading states (UX rule #3). |
| Rule J FAIL | `Color: Colors.grey` etc. | OMDS handles color from theme; remove the override (UX rule #8). |
| Rule K FAIL | snackbar/dialog on route entry | The page is the message; modals are noise (UX rule #4). |
| Type-B FAIL (`widget-ified`) | engineer added `OmdsEmptyStatePage` to a domain entity / cubit / repo | Revert to the sanity-build no-op shape. LEAD §2: domain entities have no `build()` and must not. |

## Out of scope for this scaffold

- L10n / ARB / Arabic — that's T-MOB-FIX-002 with its own QA pack.
- DI signatures (`injection_container.dart`) — that's T-MOB-FIX-003.
- Per-feature behavioural tests for the 5 follow-up tickets (`T-MOB-BIOMETRIC-001` etc.) — those tickets each get their own QA-PRE when they're scheduled.
- Visual regression / golden tests — none of the 11 placeholders are user-facing surfaces that need pixel-pinning; OMDS itself is golden-tested in `omds-flutter`.
