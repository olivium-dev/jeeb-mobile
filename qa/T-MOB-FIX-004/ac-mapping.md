# JEB-4 / T-MOB-FIX-004 — Acceptance-Criteria → Test Mapping

**Story**: JEB-4 — `/request-summary` route compile errors (Option B per LEAD pin, comment #14902).
**QA ticket**: JEB-237 (this scaffold).
**ENG ticket**: JEB-239 (implements the route fix).
**QA-POST ticket**: JEB-238 (executes post-fix verification, in-app smoke, signs off).

---

## Scope alignment

Per LEAD pin (JEB-236, comment #14902) the original story scope ("14 cascading errors") is materially wrong:
only **3 errors are in scope** for T-MOB-FIX-004. The remaining items the PO requested were split into:

- **T-MOB-DEEPLINK-001** — `app_links` + `jeeb://` Android manifest + iOS Info.plist + `/otp-handover` route + go_router 13 → 14.
- **T-MOB-CHAT-SCHEMA** — ~39 `chat_*` errors (ChatMessage / ChatMessageStatus drift).
- **T-MOB-TEST-FIXTURES** — ~19 fixture/import errors.

This QA pack therefore **only** covers AC1, AC2, and AC4. AC3 is explicitly deferred.

---

## AC → Test mapping

| AC   | Statement                                                                                              | Coverage                                                                                                                  | Where                                                                                                                |
|------|--------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------|
| AC1  | Sami's in-app journey reaches `/request-summary` and the screen renders the aggregated draft with an enabled Submit button. | **Test 1 (happy path)** + in-app smoke (QA-POST).                                                                          | `test/core/router/request_summary_route_test.dart` — `Test 1 — happy path`; QA-POST executes iOS+Android smoke.       |
| AC2  | Cold deep-link / wrong-extra-type into `/request-summary` does not hard-crash — a graceful fallback renders. | **Test 2 (extra == null)** + **Test 3 (extra is a String)**. Together they cover both `_TypeError` cases from the existing `state.extra as RequestDraft` cast. | `test/core/router/request_summary_route_test.dart` — `Test 2 — cold deep-link…` + `Test 3 — wrong extra type…`.       |
| AC3  | Cold `jeeb://request-summary` deep-link from outside the app opens the fallback.                       | **OUT OF SCOPE** for T-MOB-FIX-004 per LEAD pin. Requires `app_links` + Android intent-filter + iOS Universal Link config — those land in T-MOB-DEEPLINK-001. | n/a (split-out ticket).                                                                                              |
| AC4  | `dart analyze` total error count drops by exactly 3 (73 → 70). No new errors introduced.               | Asserted in QA-POST via diff between `qa/T-MOB-FIX-004/pre-fix-analyze.log` (this branch, baseline = 73) and post-fix run. | QA-POST (JEB-238); pre-fix baseline file in this directory.                                                          |
| AC-FINAL | All of the above pass + `RequestSummaryScreen` constructor unchanged (`{super.key}` only, Option B). | Evidence aggregated in JEB-238 verdict.                                                                                    | JEB-238 verdict comment on JEB-4.                                                                                    |

---

## Pre-fix baseline (this branch, `main` HEAD)

- Command: `dart analyze 2>&1 | tee qa/T-MOB-FIX-004/pre-fix-analyze.log`
- Total `error` lines: **73**
- In-scope (the 3 errors T-MOB-FIX-004 fixes):
  - `lib/core/router/app_router.dart:244:13 — The named parameter 'draft' isn't defined.`
  - `lib/core/router/app_router.dart:245:13 — The named parameter 'submissionService' isn't defined.`
  - `lib/core/router/app_router.dart:246:13 — The named parameter 'acknowledgmentRepository' isn't defined.`
- Expected post-fix total: **70** errors (and the three `app_router.dart` lines gone).
- Out-of-scope errors that **must remain** post-fix (so we know we didn't paper over them):
  - `lib/app/bootstrap.dart:47-48` (T-MOB-DI / JEB-3 scope).
  - `lib/features/chat/**` (~39 errors, T-MOB-CHAT-SCHEMA scope).
  - `test/**` fixture errors (~19 errors, T-MOB-TEST-FIXTURES scope).

---

## Test design notes

- The test file **directly imports `app_router.dart`** so the test target inherits the route's
  3 compile errors and the QA-PRE tests cannot run until ENG ships the fix (per hardened DoD).
- Tests construct the real `AppRouter.create(...)` with stub `OnboardingCubit` (already-completed
  via `SharedPreferences.setMockInitialValues({'app.onboarding.completed': true})`) and a default
  `BiometricLockCubit` (phase = `disabled`) so the redirect chain doesn't bounce navigation away
  from `/request-summary`.
- Test 1 asserts the BlocProvider injection by calling `BlocProvider.of<RequestSummaryCubit>(ctx)`
  on the screen subtree — this is the load-bearing Option-B contract.
- Tests 2/3 use `tester.takeException()` to assert *no* exception was thrown into the binding,
  and assert the Submit button is **absent** (i.e. the populated summary screen did not render).
  They do **not** pin specific fallback copy so ENG can choose between an error scaffold and an
  "Open from a request" CTA without breaking the gate.
- `RequestSummaryScreen` constructor remains `{super.key}` only. Tests do not import its ctor
  parameters — if ENG (mistakenly) widens the ctor à la Option A, these tests would not catch it.
  QA-POST guards that with a static check on the screen file.
