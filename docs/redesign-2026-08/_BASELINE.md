# Verification baseline — measured 2026-08-03, AFTER the environment correction

**Every agent on this migration must diff against the numbers in this file.** Any older baseline
(`11 issues / 6 errors`, `-155 failures`) quoted in an agent prompt is **superseded** — it was
measured in a broken local environment and does not describe this codebase.

---

## Current baseline

| Gate | Result | Notes |
|---|---|---|
| `flutter analyze --no-pub` | **5 issues, 0 errors** | All 5 are `containsSemantics` deprecation *infos* in test files. Local Flutter is 3.44.2; CI pins 3.38.9, so CI never sees them. |
| `flutter test` | **+3863 / ~61 skipped / −4** | CI on the same commit is +3864 / ~61 / −3. We now have CI parity. |

**Your bar:** `0 analyze errors`, no new warnings, and **no test failure outside the four named
below**. Introducing a fifth failure is a regression.

---

## The 4 pre-existing failures — NOT yours to fix

Three are **red on `main` in CI** (both the `CI` and `Flutter CI` workflows) at `main@03c6c74`, which
is the exact commit this branch was cut from. They are not migration damage:

| Test | Symptom | Migration scope |
|---|---|---|
| `test/client_offers_screen_test.dart` | sort-chip hit targets | **inside screen 11 (Offers)** |
| `test/mutual_rating_tag_chips_l10n_test.dart` | ar-locale canonical wire value | **inside screen 15 (Mutual rating)** |
| `test/jeeber_feed_card_test.dart` | pill alignment | jeeber feed |
| `test/core/diagnostics/gesture_log_test.dart` | Semantics; local-SDK skew | passes in CI |

Two of them sit **inside migration-scope features**. If you are the agent for screen 11 or 15:
do not fix these, do not count them against yourself — but if your change makes the failure *mode*
change, say so explicitly in your report rather than silently absorbing it.

---

## What was wrong before, and why the old number lied

Both causes were **local-only**. Nothing was wrong in the repository.

1. **Stale OMDS checkout.** `pubspec.yaml` resolves the design system from the sibling
   `../omds-flutter/omds_library`, which was parked on the June branch
   `iter5-flutter-blankscreen` @ `b445bb4` — predating the `identifier:` named parameter that
   **675 call sites** in `lib/` depend on.
   **Fixed:** fast-forwarded to `origin/main` @ `6f9c166`. The branch was clean, had zero unique
   commits, and `b445bb4` was already an ancestor of `main`, so this only moved it forward onto the
   surface CI already uses. The API delta is **27 files, +1309/−231, with zero public parameters
   removed** — strictly additive; 27 components gain `String? identifier`.

2. **Stale gitignored lockfile.** `pubspec.lock` (per-machine, not committed) pinned **dio 5.9.2**,
   which has no `DioExceptionType.transformTimeout`. Four files in the DI / router / bootstrap
   import closure reference it.
   **Fixed:** `flutter pub upgrade dio` → **5.11.0**, permitted by the declared `^5.4.0` and already
   in the pub cache.

### Why 155 failures collapsed to 4

`flutter test` compiles each suite into a single kernel, so **one** compile error anywhere in a
suite's transitive import closure aborts the whole suite — surfacing as one failing
`loading <file>` pseudo-test. ~99% of the 155 were these, not real regressions.

Attribution, measured independently by two agents across all 492 test suites:

| Class | Suites | Cured by |
|---|---|---|
| dio-only | ~80–119 | the dio fix alone |
| **both** (dio + OMDS in one closure) | ~29–35 | **needs both fixes** |
| **OMDS-only** | **0** | — an OMDS-only fix cures **zero** test failures |
| genuine runtime | 1–2 | neither |

The old gate did not merely add noise — it **inverted verdicts**: one genuinely-red test passed
locally, another was invisible behind a load failure, and roughly 780 tests never executed at all.
That is why this was corrected before any screen code was written.

---

## Forward recovery

If local dependency state drifts, fast-forward the OMDS checkout to its audited default
branch, refresh the permitted dependency versions, and re-run the full verification gate.
Do not switch to an older checkout or reinstate a predecessor lockfile.

Neither environment correction is part of this migration's diff: the OMDS checkout is
outside the repo, and `pubspec.lock` is gitignored. `git status` shows no tracked-file
change from either.

---

## Separate findings for the owner — not this migration's business

- **`jeeb-mobile` main is red in CI** on the 3 tests above. Worth knowing independently of this work.
- **`dio: ^5.4.0` is a dishonest floor** — the committed code requires ≥ 5.11.0. One-line follow-up PR.
- **CI's OMDS checkout specifies no `ref:`**, so it silently tracks whatever the default branch is —
  a reproducibility hazard.
- **`deep_link_resolution_router_test` appears to repeat one test thousands of times in CI**,
  inflating the reported pass count (~3864 reported vs ~3083 real tests).
