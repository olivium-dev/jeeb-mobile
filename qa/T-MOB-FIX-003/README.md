# QA-PRE scaffold — T-MOB-FIX-003

Authored by Principal QA — Flutter (Jira subtask **JEB-231**, parent Story
**JEB-3** "Fix configureDependencies signature mismatch in injection_container.dart").

This is a **build-fix** Story under LEAD-pinned **Path B** (hand-written
GetIt, no codegen). The QA deliverable is **CI assertions**, not a Maestro
or `integration_test` suite — there is no new user-facing behaviour. The
shape mirrors `qa/t-mob-fix-001/` (Class A build-fix).

## Files

| File | Purpose |
|---|---|
| `build-green.sh` | Build-fix gate: `flutter pub get` → `dart analyze` (scoped) → `flutter build apk --debug --no-pub` → `flutter test test/core/di/injection_container_test.dart`. Writes logs to `_artifacts/` for the AC-FINAL Jira comment. |
| `di-signature-check.sh` | grep-based signature consistency check. Verifies (R1) one declaration, (R2) both required named params in the declaration, (R3) every call site under `lib/` passes both named args, (R4) no positional-style invocations, (R5) `SharedPreferences` + `CrashReporter` singletons register before `Dio` lazy singleton. |
| `ac-mapping.md` | (existing, from QA-PRE pre-fix work) AC → evidence map for JEB-232 (QA-POST). |
| `pre-fix-analyze.log` | (existing) Baseline 73-error analyze log; used by `build-green.sh` to compute the delta. |
| `_artifacts/` | Created at runtime — `pub-get.log`, `post-fix-analyze.log`, `build-apk.log`, `di-test.log`, `di-signature-check.log`. |

## How ENG (JEB-233) runs it before opening the PR

```bash
cd <repo-root>
chmod +x jeeb-code/jeeb-mobile/qa/t-mob-fix-003/*.sh
./jeeb-code/jeeb-mobile/qa/t-mob-fix-003/di-signature-check.sh \
  && ./jeeb-code/jeeb-mobile/qa/t-mob-fix-003/build-green.sh
```

Both scripts must exit `0`. Any non-zero exit is a PR blocker — fix the
underlying issue; do **not** relax the assertion.

## Mapping to JEB-3 ACs

| AC | What it says | Where it's checked |
|---|---|---|
| **AC1** | App boots past splash on iOS + Android without crashing during bootstrap. | `build-green.sh` step (c) — APK build green is a necessary precondition; the actual smoke run is owned by QA-POST (JEB-232) and is not in this scaffold. |
| **AC2** | No manual edits drift across runs of code generation. | **N/A under Path B.** No `build_runner` step exists. Document N/A in the QA-POST verdict. |
| **AC3** | `dart analyze` returns 0 errors in `lib/core/di/` and the 2 specific lines `lib/app/bootstrap.dart:47:9` + `:48:9` no longer report `undefined_named_parameter`. | `build-green.sh` step (b) — three in-scope assertions: zero errors under `lib/core/di/`, zero matches for `lib/app/bootstrap.dart:4[78]:9 .*undefined_named_parameter`, and a delta check against the 73-error baseline (target 71). |
| **AC4** | Fresh-clone + `flutter pub get` + `build_runner build` is deterministic. | **N/A under Path B** — no codegen. |
| **AC-FINAL** | Composite gate — verdict=PASS when AC1 + AC3 green and AC2 + AC4 documented N/A. | QA-POST (JEB-232) reads `_artifacts/post-fix-analyze.log` + `_artifacts/di-test.log` + smoke run evidence. |

## What each script's exit code means

### `build-green.sh`

| Exit | Meaning | Likely cause | Fix |
|---|---|---|---|
| 0 | All green | — | — |
| 1 | `flutter pub get` failed | dep mismatch / lockfile drift | Re-resolve; pin transitive in `pubspec.yaml` if needed. |
| 2 | In-scope analyze errors remain | the call site at `bootstrap.dart:47/:48` still reports `undefined_named_parameter`, OR a new error appeared under `lib/core/di/` | Confirm `configureDependencies` declaration accepts `required SharedPreferences sharedPreferences` and `required CrashReporter crashReporter`. Re-run `di-signature-check.sh` to localise. |
| 3 | `flutter build apk` failed | DI registration crashes at compile time, or a chat/router error became fatal | Inspect `_artifacts/build-apk.log`. If chat/router noise is the cause, that's out of scope for this Story — open a separate ticket. |
| 4 | DI unit tests failed | the contract test `test/core/di/injection_container_test.dart` failed | Likely the idempotency contract — second `configureDependencies` call must throw (`StateError` / `ArgumentError`). LEAD pin: "fail loudly". Do NOT introduce a reset-then-re-register path. |

### `di-signature-check.sh`

| Exit | Rule | Meaning | Fix |
|---|---|---|---|
| 0 | — | All rules pass | — |
| 1 | R1 | Zero or multiple declarations of `configureDependencies` | Keep exactly one declaration in `lib/core/di/injection_container.dart`. |
| 2 | R2 | Declaration missing `required SharedPreferences sharedPreferences` or `required CrashReporter crashReporter` | Restore both required named params. Do not loosen `required` to optional — fail-loud at compile is the contract. |
| 3 | R3 | A call site under `lib/` is missing `sharedPreferences:` or `crashReporter:` | Update the call site. The only production caller today is `lib/app/bootstrap.dart`. |
| 4 | R4 | A call site uses positional args | Switch to the named form. The declaration uses named-required for a reason: positional drift is exactly what produced JEB-3. |
| 5 | R5 | `Dio` (or other lazy singleton) registers before `SharedPreferences` / `CrashReporter` singletons | Move the two `registerSingleton` calls above the first `registerLazySingleton`. LEAD pin §2: "Registration order matters — feature constructors will read prefs and report crashes." |

## Contract decisions QA-PRE pinned (re-stated for ENG)

1. **Idempotency: fail loudly.** A second call to `configureDependencies` MUST throw. This is the GetIt 8.x default — do not weaken it.
2. **Mocking strategy in tests:** `mocktail.Mock` for both `SharedPreferences` and `CrashReporter` — DI registration never invokes a method on either, so a bare mock suffices.
3. **GetIt reset discipline:** `setUp` AND `tearDown` reset `GetIt.I` so a failed test cannot leak singletons.

## Out of scope for this scaffold

- iOS / Android smoke run on a real device or emulator — owned by QA-POST (JEB-232) under AC1.
- Codegen / `@InjectableInit` migration — parked under follow-up spike "Standardise Olivium Flutter DI on `@InjectableInit`".
- Resolving the 71 out-of-scope errors (chat schema, router constructor mismatch, test scaffolding). Those belong to separate tickets and MUST NOT be silenced by this Story.
- Maestro / Patrol / `integration_test` flows — this Story has no user-facing behaviour to test end-to-end.

## Cross-references

- LEAD architecture + scope: [JEB-3 comment #14895](https://olivium.atlassian.net/browse/JEB-3?focusedCommentId=14895)
- ENG-1 scope: JEB-233
- QA-POST verifier: JEB-232 — reads `_artifacts/` + runs smoke on iOS sim + Android emu.
- Branch (LEAD-set, canonical): `fix/jeb-3-di-signature`. Update `ac-mapping.md` line 6 in the ENG PR (one-line edit).
