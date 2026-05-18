# JEB-3 / T-MOB-FIX-003 — AC → QA-POST evidence mapping

**Story:** JEB-3 "Mobile DI fix for SharedPreferences + CrashReporter wiring"
**Scope path:** B (no codegen) — pinned by LEAD in [JEB-3 comment #14895](https://olivium.atlassian.net/browse/JEB-3?focusedCommentId=14895)
**Author ticket:** JEB-231 (QA-PRE) · **Verifier ticket:** JEB-232 (QA-POST) · **Implementer:** JEB-233 (ENG)
**Branch under test:** `feature/jeeb-v3-di-fix-jeb3`
**Pre-fix baseline:** `qa/T-MOB-FIX-003/pre-fix-analyze.log` — 148 issues / **73 errors** / **2 in scope**

---

## AC table

| AC | Statement | Path-B applicability | QA-POST evidence to capture |
|----|-----------|----------------------|-----------------------------|
| **AC1** | App boots past splash on iOS and Android without crashing during bootstrap. | **In scope** | Smoke run on one iOS sim (iPhone 15, iOS 17) + one Android emu (Pixel 7, API 34). Capture: video or screenshot of post-splash home, plus log line confirming `Bootstrap.minimal` finished and `CrashReportingInitializer(reporter).install()` ran without throwing. |
| **AC2** | No manual edits drift across runs of code generation. | **N/A under Path B** | LEAD pin confirms no `@InjectableInit` / `.config.dart` / `build_runner` involved. `configureDependencies` is hand-written. Document N/A in the QA-POST verdict — do not block on this AC. Reopen if Path A is ever revisited (see JEB-3 follow-up: "PO-suggested spike: standardise Olivium Flutter DI on @InjectableInit"). |
| **AC3** | `dart analyze` returns 0 errors in `lib/core/di/` and the 2 specific lines `lib/app/bootstrap.dart:47:9` + `lib/app/bootstrap.dart:48:9` no longer report `undefined_named_parameter`. | **In scope** | Post-fix `dart analyze` log shows: (a) zero matches for `^  error - lib/core/di/`; (b) zero matches for `lib/app/bootstrap.dart:47:9` and `lib/app/bootstrap.dart:48:9`; (c) **total error count drops by exactly 2** from baseline (73 → 71). Do **not** assert total = 0; chat + router errors are out-of-scope per LEAD pin and remain. |
| **AC4** | Fresh-clone + `flutter pub get` + `build_runner build` is deterministic and idempotent. | **N/A under Path B** | No codegen invoked. Document N/A. If `flutter pub get` is run as part of QA-POST CI, attach the log for completeness but do not gate on `build_runner`. |
| **AC-FINAL** | Composite gate — JEB-232 may set verdict=PASS only when AC1 + AC3 are green and AC2 + AC4 are documented N/A under Path B. | **In scope** | See evidence table below. |

---

## AC-FINAL evidence table (template for QA-POST verdict comment)

| Item | Status | Evidence path / link |
|------|--------|----------------------|
| Branch under verification | filled by QA-POST | `feature/jeeb-v3-di-fix-jeb3` @ `<commit-sha-after-ENG>` |
| Pre-fix analyze baseline | recorded | `qa/T-MOB-FIX-003/pre-fix-analyze.log` (73 errors, 2 in scope) |
| Post-fix analyze | filled by QA-POST | `qa/T-MOB-FIX-003/post-fix-analyze.log` — must show 71 errors total, 0 in `lib/core/di/`, 0 at `lib/app/bootstrap.dart:47:9` and `:48:9` |
| Unit tests | filled by QA-POST | `flutter test test/core/di/injection_container_test.dart` — must report `+3 -0` (all 3 tests green) |
| iOS splash → home smoke (AC1) | filled by QA-POST | screenshot or video at `qa/T-MOB-FIX-003/ios-smoke.{png,mov}` |
| Android splash → home smoke (AC1) | filled by QA-POST | screenshot or video at `qa/T-MOB-FIX-003/android-smoke.{png,mov}` |
| AC2 codegen-drift | N/A | Path B — no codegen surface in repo (LEAD pin verified: no `@InjectableInit`, no `.config.dart`, no `@injectable` annotations) |
| AC4 fresh-clone determinism | N/A | Path B — no `build_runner` step |
| CI run link | filled by QA-POST | GitHub Actions URL |

---

## Out-of-scope errors that will persist post-fix (do NOT regress on these, do NOT fail QA-POST on these)

Per LEAD pin JEB-3#14895 the following 71 errors are explicitly out of scope and routed to follow-up tickets:

- `lib/core/router/app_router.dart:244-246` — `RequestSummaryScreen` constructor mismatch (3 errors) → **JEB-4** or new ticket
- `lib/features/chat/**` — chat schema mismatch (~20 errors) → new ticket
- `test/**` — chat-driven test errors (~19 errors) → new ticket
- Remaining ~29 misc errors (router/data layers not enumerated by LEAD)

QA-POST asserts on the **delta** (− 2 errors, specific line disappearance), **not** total = 0.

---

## Contract decisions QA-PRE made (open for ENG / LEAD review before JEB-233 lands)

1. **Test 3 — idempotency contract:** Adopted **"fail loudly"** (second `configureDependencies` call throws `StateError` or `ArgumentError`). Rationale: production call site is `Bootstrap.minimal`, runs exactly once on cold start; silent re-registration would swap live singletons mid-app. This mirrors GetIt 8.x default behaviour. If ENG flips to reset-then-re-register, the assertion in `injection_container_test.dart` must flip too.
2. **Mocking strategy:** `SharedPreferences` and `CrashReporter` use `mocktail.Mock` — DI setup never calls methods on either, so a bare mock satisfies the registration path without needing `SharedPreferences.setMockInitialValues`.
3. **GetIt reset discipline:** `setUp` and `tearDown` both reset `GetIt.I` so a failed test cannot leak singletons into the next.

---

## Pre-fix verification (already captured by JEB-231)

- `dart analyze 2>&1 | tee qa/T-MOB-FIX-003/pre-fix-analyze.log` → 148 issues, 73 errors, 6 warnings, 69 info.
- In-scope errors confirmed verbatim:
  - `error - lib/app/bootstrap.dart:47:9 - The named parameter 'sharedPreferences' isn't defined. ... - undefined_named_parameter`
  - `error - lib/app/bootstrap.dart:48:9 - The named parameter 'crashReporter' isn't defined. ... - undefined_named_parameter`
- Test scaffold at `test/core/di/injection_container_test.dart` compiles **only** after JEB-233 ships, which is the intended fail-loud signal.
